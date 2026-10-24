#Requires -Version 5.1
<#
.SYNOPSIS
Prepara soltanto gli strumenti necessari all'export APK standard di Godot 4.5.1.
.DESCRIPTION
Riutilizza un JDK 17+ e un SDK completo gia presenti. Se manca l'SDK, lo scarica
in tools/android-sdk senza modificare registro, PATH o impostazioni globali.
I pacchetti Android vengono installati soltanto con -AcceptLicenses.
L'oggetto restituito contiene JavaHome, AndroidSdkRoot e i percorsi dei tool.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$SdkRoot = '',
    [switch]$AcceptLicenses,
    [string]$ResultPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_common.ps1')
Set-StrictMode -Version 2.0
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$androidApiLevel = 35
$androidBuildToolsVersion = '35.0.0'
# Pin compatibile con JDK 17: non segue il pacchetto "latest", che puo cambiare.
# SHA-1 del medesimo archivio nel manifesto ufficiale repository2-1.xml:
# 3d2917302740f476999a091bc5558837c7a863c5.
$androidCommandToolsId = '11076708'
$androidCommandToolsVersion = '12.0'
$androidCommandToolsSha256 = '4d6931209eebb1bfb7c7e8b240a6a3cb3ab24479ea294f3539429574b1eec862'
$androidCommandToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-${androidCommandToolsId}_latest.zip"

function Test-AndroidWorkspacePath([string]$Candidate) {
    $androidFullPath = [System.IO.Path]::GetFullPath($Candidate)
    $androidWorkspacePrefix = $ProjectRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return $androidFullPath.StartsWith($androidWorkspacePrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-AndroidJdk([string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
    $androidJdkPath = [System.IO.Path]::GetFullPath($Candidate.Trim().Trim('"'))
    foreach ($androidJavaTool in @('java.exe', 'javac.exe', 'keytool.exe', 'jarsigner.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $androidJdkPath "bin\$androidJavaTool") -PathType Leaf)) { return $null }
    }
    $androidReleaseFile = Join-Path $androidJdkPath 'release'
    if (-not (Test-Path -LiteralPath $androidReleaseFile -PathType Leaf)) { return $null }
    $androidVersionMatch = [regex]::Match([System.IO.File]::ReadAllText($androidReleaseFile), '(?m)^JAVA_VERSION="(?<major>\d+)(?:\.(?<legacy>\d+))?')
    if (-not $androidVersionMatch.Success) { return $null }
    $androidJavaMajor = [int]$androidVersionMatch.Groups['major'].Value
    if ($androidJavaMajor -eq 1) { $androidJavaMajor = [int]$androidVersionMatch.Groups['legacy'].Value }
    if ($androidJavaMajor -lt 17) { return $null }
    return [pscustomobject]@{ Path = $androidJdkPath.TrimEnd('\', '/'); Major = $androidJavaMajor }
}

function Test-AndroidSdk([string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    foreach ($androidRequiredFile in @(
        'platform-tools\adb.exe',
        "build-tools\$androidBuildToolsVersion\apksigner.bat",
        "build-tools\$androidBuildToolsVersion\lib\apksigner.jar",
        "build-tools\$androidBuildToolsVersion\aapt.exe",
        "build-tools\$androidBuildToolsVersion\zipalign.exe",
        "platforms\android-$androidApiLevel\android.jar"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $Candidate $androidRequiredFile) -PathType Leaf)) { return $false }
    }
    return $true
}

function Get-AndroidDownload([string]$Url, [string]$Destination, [string]$Sha256) {
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
        ((Get-ReleaseSha256 $Destination) -ieq $Sha256)) { return }
    $androidPartialFile = "$Destination.partial"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $androidDownloadError = $null
    for ($androidAttempt = 1; $androidAttempt -le 3; $androidAttempt++) {
        try {
            Write-Host "Download strumenti Android ($androidAttempt/3)..."
            $androidPreviousProgress = $ProgressPreference
            try {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $Url -UseBasicParsing -OutFile $androidPartialFile -TimeoutSec 600
            } finally { $ProgressPreference = $androidPreviousProgress }
            $androidActualHash = Get-ReleaseSha256 $androidPartialFile
            if ($androidActualHash -ine $Sha256) { throw "Archivio Android non valido: controllo SHA-256 fallito ($androidActualHash)." }
            Move-Item -LiteralPath $androidPartialFile -Destination $Destination -Force
            return
        } catch {
            $androidDownloadError = $_
            if ($androidAttempt -lt 3) { Start-Sleep -Seconds 2 }
        }
    }
    throw "Download Android non riuscito da $Url. $androidDownloadError"
}

$androidJdkCandidates = New-Object 'System.Collections.Generic.List[string]'
foreach ($androidJdkCandidate in @($env:JAVA_HOME, (Join-Path $ProjectRoot 'tools\jdk'))) {
    if (-not [string]::IsNullOrWhiteSpace($androidJdkCandidate)) { $androidJdkCandidates.Add($androidJdkCandidate) }
}
$androidJavaCommand = Get-Command javac.exe -ErrorAction SilentlyContinue
if ($null -ne $androidJavaCommand) { $androidJdkCandidates.Add((Split-Path -Parent (Split-Path -Parent $androidJavaCommand.Source))) }
foreach ($androidJdkParent in @(
    (Join-Path $env:ProgramFiles 'Eclipse Adoptium'),
    (Join-Path $env:ProgramFiles 'Java'),
    (Join-Path $env:ProgramFiles 'Microsoft'),
    (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr')
)) {
    if (Test-Path -LiteralPath $androidJdkParent -PathType Container) {
        $androidJdkCandidates.Add($androidJdkParent)
        Get-ChildItem -LiteralPath $androidJdkParent -Directory -ErrorAction SilentlyContinue | ForEach-Object { $androidJdkCandidates.Add($_.FullName) }
    }
}
$androidValidJdks = @()
foreach ($androidJdkCandidate in ($androidJdkCandidates | Select-Object -Unique)) {
    $androidDetectedJdk = Get-AndroidJdk $androidJdkCandidate
    if ($null -ne $androidDetectedJdk) { $androidValidJdks += $androidDetectedJdk }
}
$androidJdk = $androidValidJdks | Sort-Object Major | Select-Object -First 1
if ($null -eq $androidJdk) {
    throw 'JDK 17 o superiore non trovato. Installare OpenJDK 17, oppure estrarre un JDK in tools\jdk, quindi rilanciare. https://adoptium.net/temurin/releases/?version=17'
}
Write-Host "Java $($androidJdk.Major): $($androidJdk.Path)"

if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
    $androidSdkCandidates = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'), (Join-Path $ProjectRoot 'tools\android-sdk'))
    foreach ($androidSdkCandidate in $androidSdkCandidates) {
        if (Test-AndroidSdk $androidSdkCandidate) { $SdkRoot = $androidSdkCandidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($SdkRoot)) { $SdkRoot = Join-Path $ProjectRoot 'tools\android-sdk' }
}
$SdkRoot = [System.IO.Path]::GetFullPath($SdkRoot).TrimEnd('\', '/')

if (-not (Test-AndroidSdk $SdkRoot)) {
    if (-not (Test-AndroidWorkspacePath $SdkRoot)) { throw "SDK incompleto: $SdkRoot. L'installazione automatica e consentita solo dentro il progetto; un SDK esterno viene soltanto riutilizzato se completo." }
    if (-not $AcceptLicenses) {
        throw 'Mancano componenti Android. Rilanciare con -AcceptLicenses dopo aver letto https://developer.android.com/studio/terms . I pacchetti saranno installati solo in tools\android-sdk.'
    }
    $androidDownloadRoot = Join-Path $ProjectRoot '.runtime\android-bootstrap'
    $androidCmdRoot = Join-Path $SdkRoot "cmdline-tools\$androidCommandToolsVersion"
    $androidSdkManager = Join-Path $androidCmdRoot 'bin\sdkmanager.bat'
    New-Item -ItemType Directory -Path $SdkRoot, $androidDownloadRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $androidSdkManager -PathType Leaf)) {
        $androidArchive = Join-Path $androidDownloadRoot "commandlinetools-win-${androidCommandToolsId}_latest.zip"
        Get-AndroidDownload $androidCommandToolsUrl $androidArchive $androidCommandToolsSha256
        $androidExtractRoot = Join-Path $androidDownloadRoot ('extract-' + [guid]::NewGuid().ToString('N'))
        Expand-Archive -LiteralPath $androidArchive -DestinationPath $androidExtractRoot
        $androidExtractedTools = Join-Path $androidExtractRoot 'cmdline-tools'
        if (-not (Test-Path -LiteralPath (Join-Path $androidExtractedTools 'bin\sdkmanager.bat') -PathType Leaf)) { throw 'Layout archivio Android inatteso: sdkmanager.bat assente.' }
        New-Item -ItemType Directory -Path (Split-Path -Parent $androidCmdRoot) -Force | Out-Null
        foreach ($androidMovePath in @($androidExtractedTools, $androidCmdRoot)) {
            if (-not (Test-AndroidWorkspacePath $androidMovePath)) { throw "Percorso estrazione fuori dal progetto: $androidMovePath" }
        }
        if (Test-Path -LiteralPath $androidCmdRoot) {
            $androidOldCmdRoot = "$androidCmdRoot.incomplete-$([guid]::NewGuid().ToString('N'))"
            Move-Item -LiteralPath $androidCmdRoot -Destination $androidOldCmdRoot
        }
        Move-Item -LiteralPath $androidExtractedTools -Destination $androidCmdRoot
    }
    $androidPreviousJavaHome = $env:JAVA_HOME
    $androidPreviousSdkRoot = $env:ANDROID_SDK_ROOT
    $androidPreviousUserHome = $env:ANDROID_USER_HOME
    try {
        $env:JAVA_HOME = $androidJdk.Path
        $env:ANDROID_SDK_ROOT = $SdkRoot
        $env:ANDROID_USER_HOME = Join-Path $androidDownloadRoot 'user'
        New-Item -ItemType Directory -Path $env:ANDROID_USER_HOME -Force | Out-Null
        Write-Host 'Installazione Platform Tools, Build Tools 35.0.0 e Android API 35...'
        $androidSdkLog = Join-Path $androidDownloadRoot 'sdkmanager-install.log'
        $androidPreviousErrorAction = $ErrorActionPreference
        try {
            # Accetta esclusivamente le licenze richieste dai tre pacchetti;
            # non accetta add-on inutilizzati e non scrive hash licenze fittizi.
            # stderr dei tool Java e diagnostica, non un'eccezione PowerShell.
            $ErrorActionPreference = 'Continue'
            1..100 | ForEach-Object { 'y' } | & $androidSdkManager "--sdk_root=$SdkRoot" 'platform-tools' "build-tools;$androidBuildToolsVersion" "platforms;android-$androidApiLevel" 2>&1 | Out-File -LiteralPath $androidSdkLog -Encoding utf8
            $androidSdkExitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $androidPreviousErrorAction }
        if ($androidSdkExitCode -ne 0) {
            Get-Content -LiteralPath $androidSdkLog -Tail 20 | ForEach-Object { Write-Host $_ }
            throw "sdkmanager terminato con codice $androidSdkExitCode. Dettagli: $androidSdkLog"
        }
        Write-Host "Installazione Android completata. Log: $androidSdkLog"
    } finally {
        $env:JAVA_HOME = $androidPreviousJavaHome
        $env:ANDROID_SDK_ROOT = $androidPreviousSdkRoot
        $env:ANDROID_USER_HOME = $androidPreviousUserHome
    }
    if (-not (Test-AndroidSdk $SdkRoot)) { throw "SDK Android ancora incompleto dopo l'installazione: $SdkRoot" }
}

$androidResult = [pscustomobject]@{
    JavaHome = $androidJdk.Path
    JavaMajor = $androidJdk.Major
    AndroidSdkRoot = $SdkRoot
    BuildToolsVersion = $androidBuildToolsVersion
    ApiLevel = $androidApiLevel
    Adb = (Join-Path $SdkRoot 'platform-tools\adb.exe')
    ApkSigner = (Join-Path $SdkRoot "build-tools\$androidBuildToolsVersion\apksigner.bat")
    Aapt = (Join-Path $SdkRoot "build-tools\$androidBuildToolsVersion\aapt.exe")
    ZipAlign = (Join-Path $SdkRoot "build-tools\$androidBuildToolsVersion\zipalign.exe")
    KeyTool = (Join-Path $androidJdk.Path 'bin\keytool.exe')
}
if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    $androidResultFullPath = [System.IO.Path]::GetFullPath($ResultPath)
    if (-not (Test-AndroidWorkspacePath $androidResultFullPath)) { throw 'ResultPath deve trovarsi dentro il progetto.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $androidResultFullPath) -Force | Out-Null
    [System.IO.File]::WriteAllText($androidResultFullPath, ($androidResult | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
}
Write-Host "SDK Android pronto: $SdkRoot"
$androidResult
