[CmdletBinding()]
param(
    [string] $ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_common.ps1')

# Official, immutable Inno Setup release. Never execute an unverified download.
$innoVersion = '6.7.3'
$archiveUrl = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe'
$archiveSha256 = '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
$resolvedRoot = [IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot 'project.godot') -PathType Leaf)) {
    throw "Cartella progetto Godot non valida: $resolvedRoot"
}
$compilerDir = Join-Path $resolvedRoot "tools\inno-$innoVersion"
$compilerExe = Join-Path $compilerDir 'ISCC.exe'
$downloadDir = Join-Path $resolvedRoot 'tools\downloads'
$archivePath = Join-Path $downloadDir "innosetup-$innoVersion.exe"
$compilerHashes = @{
    'ISCC.exe' = '0a8757031b33777e4c9cbffee40f11a5062b36d25cbe144c1db73b6102b80ad7'
    'ISCmplr.dll' = '85a1e3090d3a5b85319f001b7c8f9ecfad45f37eff030a67bbe29ef58b7aa2c3'
    'ISPP.dll' = 'bde04be7f4a55ca56afb6b06600d7cbe8326fac468ac3f2885b80eefb3ed2a7a'
}

function Assert-CompilerFiles {
    foreach ($relativeFile in $compilerHashes.Keys) {
        $compilerFile = Join-Path $compilerDir $relativeFile
        if (-not (Test-Path -LiteralPath $compilerFile -PathType Leaf) -or
            (Get-ReleaseSha256 $compilerFile) -ne $compilerHashes[$relativeFile]) {
            throw "Compilatore Inno Setup non valido o incompleto: $compilerFile. Ripristinare tools\inno-$innoVersion."
        }
    }
}

if (Test-Path -LiteralPath $compilerExe -PathType Leaf) {
    Assert-CompilerFiles
    Write-Output $compilerExe
    return
}

New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    $partialPath = "$archivePath.partial"
    Write-Host "Scaricamento Inno Setup $innoVersion dal sito ufficiale..."
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $archiveUrl -OutFile $partialPath -UseBasicParsing
        $downloadHash = Get-ReleaseSha256 $partialPath
        if ($downloadHash -ne $archiveSha256) {
            throw "SHA-256 del download Inno Setup non valido. Il file non verra eseguito."
        }
        Move-Item -LiteralPath $partialPath -Destination $archivePath -Force
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
    }
}
$actualHash = Get-ReleaseSha256 $archivePath
if ($actualHash -ne $archiveSha256) {
    throw "SHA-256 dell'archivio Inno Setup non valido: $archivePath. Rimuoverlo per scaricarlo nuovamente."
}

# /PORTABLE=1 is supported by Inno Setup's own installer. No elevated rights,
# registry uninstall entry, file associations, desktop or Start Menu shortcuts.
New-Item -ItemType Directory -Path $compilerDir -Force | Out-Null
$setupArguments = @(
    '/PORTABLE=1', '/CURRENTUSER', '/VERYSILENT', '/SUPPRESSMSGBOXES',
    '/NORESTART', '/SP-', '/NOICONS', '/TASKS=',
    "/DIR=`"$compilerDir`""
)
Write-Host "Preparazione compilatore portatile in $compilerDir..."
$setupProcess = Start-Process -FilePath $archivePath -ArgumentList $setupArguments -Wait -PassThru -WindowStyle Hidden
if ($setupProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $compilerExe -PathType Leaf)) {
    throw "Preparazione Inno Setup fallita (codice $($setupProcess.ExitCode))."
}
Assert-CompilerFiles
Write-Output $compilerExe
