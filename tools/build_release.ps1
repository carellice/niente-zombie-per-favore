# Requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
Import-Module Microsoft.PowerShell.Utility -Global
Import-Module Microsoft.PowerShell.Management -Global
$releaseRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'release_common.ps1')
$versionFile = Join-Path $releaseRoot 'VERSION.json'
$projectFile = Join-Path $releaseRoot 'project.godot'
$presetFile = Join-Path $releaseRoot 'export_presets.cfg'
$godot = Join-Path $releaseRoot 'tools/godot/Godot_v4.5.1-stable_win64_console.exe'
$releaseOutputRoot = Join-Path $releaseRoot 'builds/releases'
$lock = $null
$manifest = $null
$manifestPath = $null
$releaseDirectory = $null
$oldEnvironment = @{}
$environmentNames = @('APPDATA','TEMP','TMP','JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','PATH','NZPF_ANDROID_STOREPASS','GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')
foreach ($name in $environmentNames) { $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

function Get-ReleaseSigning {
    param($Android, [string]$LogDirectory)
    $privateDirectory = Join-Path $releaseRoot '.release-private'
    [IO.Directory]::CreateDirectory($privateDirectory) | Out-Null
    $keyPath = Join-Path $privateDirectory 'android-release.keystore'
    $credentialsPath = Join-Path $privateDirectory 'android-signing.json'
    $keyExists = Test-Path -LiteralPath $keyPath
    $credentialsExist = Test-Path -LiteralPath $credentialsPath
    if ($keyExists -xor $credentialsExist) { throw 'Firma Android incompleta: ripristina insieme keystore e android-signing.json da .release-private. Nessuna chiave viene sostituita automaticamente.' }
    if (-not $keyExists) {
        Write-Host 'Creazione della chiave Android stabile (solo al primo avvio)...'
        $bytes = New-Object byte[] 32
        $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
        $password = -join ($bytes | ForEach-Object { $_.ToString('x2') })
        $signing = [pscustomobject]@{ alias = 'nzpf_release'; password = $password; created_utc = [DateTime]::UtcNow.ToString('o') }
        $env:NZPF_ANDROID_STOREPASS = $password
        Invoke-ReleaseTool -Program $Android.KeyTool -Arguments @('-genkeypair','-noprompt','-storetype','PKCS12','-keystore',$keyPath,'-alias',$signing.alias,'-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=Niente Zombie Per Favore, O=Rifugio 07, C=IT','-storepass:env','NZPF_ANDROID_STOREPASS','-keypass:env','NZPF_ANDROID_STOREPASS') -LogPath (Join-Path $LogDirectory 'create-signing.log')
        Write-ReleaseText -Path $credentialsPath -Text ($signing | ConvertTo-Json)
    }
    $credentials = Get-Content -LiteralPath $credentialsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($credentials.alias) -or [string]::IsNullOrWhiteSpace($credentials.password)) { throw 'Credenziali Android non valide in .release-private/android-signing.json.' }
    $env:NZPF_ANDROID_STOREPASS = [string]$credentials.password
    Invoke-ReleaseTool -Program $Android.KeyTool -Arguments @('-list','-keystore',$keyPath,'-alias',[string]$credentials.alias,'-storepass:env','NZPF_ANDROID_STOREPASS') -LogPath (Join-Path $LogDirectory 'check-signing.log')
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keyPath
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = [string]$credentials.alias
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [string]$credentials.password
}

try {
    if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw 'Godot 4.5.1 portatile mancante in tools/godot.' }
    if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) { throw 'VERSION.json mancante.' }
    [IO.Directory]::CreateDirectory((Join-Path $releaseRoot '.runtime')) | Out-Null
    try { $lock = [IO.File]::Open((Join-Path $releaseRoot '.runtime/release-build.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { throw 'Un altro processo sta gia creando un rilascio. Attendi che finisca.' }
    $current = Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $next = Get-NextReleaseVersion $current
    if ($CheckOnly) {
        Write-Host ("Configurazione valida. Versione attuale {0}; prossimo rilascio {1}, Android code {2}." -f $current.version,$next.version,$next.android_version_code)
        Write-Host 'Modalita controllo: nessun incremento, download o build.'
        exit 0
    }
    $releaseDirectory = Join-Path $releaseOutputRoot $next.version
    if (Test-Path -LiteralPath $releaseDirectory) { throw "Cartella rilascio gia presente: $releaseDirectory. Non verra sovrascritta." }
    # Reserve before creating output folders: an interrupted attempt is not reused.
    Write-ReleaseText $versionFile ($next | ConvertTo-Json)
    [IO.Directory]::CreateDirectory($releaseDirectory) | Out-Null
    $logDirectory = Join-Path $releaseDirectory 'logs'
    $windowsDirectory = Join-Path $releaseDirectory 'windows'
    [IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    [IO.Directory]::CreateDirectory($windowsDirectory) | Out-Null
    $manifestPath = Join-Path $releaseDirectory 'release.json'
    $manifest = [ordered]@{ version = $next.version; android_version_code = $next.android_version_code; status = 'building'; started_utc = [DateTime]::UtcNow.ToString('o'); android_package = 'org.rifugio07.nientezombieperfavore' }
    Write-ReleaseText $manifestPath ($manifest | ConvertTo-Json -Depth 8)

    Write-Host ("[1/8] Nuova versione comune: {0} (Android {1})" -f $next.version,$next.android_version_code)
    $projectText = Get-Content -LiteralPath $projectFile -Raw -Encoding UTF8
    $projectText = Set-GodotConfigValue $projectText 'application' 'config/version' ('"' + $next.version + '"')
    Write-ReleaseText $projectFile $projectText
    $presets = Get-Content -LiteralPath $presetFile -Raw -Encoding UTF8
    $presets = Set-GodotConfigValue $presets 'preset.0.options' 'application/file_version' ('"' + $next.version + '"')
    $presets = Set-GodotConfigValue $presets 'preset.0.options' 'application/product_version' ('"' + $next.version + '"')
    $presets = Set-GodotConfigValue $presets 'preset.1.options' 'version/name' ('"' + $next.version + '"')
    $presets = Set-GodotConfigValue $presets 'preset.1.options' 'version/code' ([string]$next.android_version_code)
    Write-ReleaseText $presetFile $presets

    Write-Host '[2/8] Preparazione compilatore setup e strumenti Android...'
    $buildTemp = Join-Path $releaseRoot '.runtime/release-temp'
    [IO.Directory]::CreateDirectory($buildTemp) | Out-Null
    $env:TEMP = $buildTemp
    $env:TMP = $buildTemp
    $compiler = & (Join-Path $PSScriptRoot 'bootstrap_installer.ps1') -ProjectRoot $releaseRoot
    & (Join-Path $PSScriptRoot 'fetch_android_template.ps1') -DestinationDirectory (Join-Path $releaseRoot 'tools/templates') | Out-Host
    $android = & (Join-Path $PSScriptRoot 'bootstrap_android.ps1') -ProjectRoot $releaseRoot -AcceptLicenses
    $env:JAVA_HOME = $android.JavaHome
    $env:ANDROID_HOME = $android.AndroidSdkRoot
    $env:ANDROID_SDK_ROOT = $android.AndroidSdkRoot
    $env:PATH = (Join-Path $android.JavaHome 'bin') + ';' + $oldEnvironment['PATH']
    Get-ReleaseSigning -Android $android -LogDirectory $logDirectory

    # The bundled editor has _sc_ enabled and ignores APPDATA for its settings.
    # Use a private portable copy, leaving the interactive editor profile alone.
    $buildEngineDirectory = Join-Path $releaseRoot '.runtime/release-godot'
    [IO.Directory]::CreateDirectory($buildEngineDirectory) | Out-Null
    foreach ($binaryName in @('Godot_v4.5.1-stable_win64.exe','Godot_v4.5.1-stable_win64_console.exe')) {
        $binarySource = Join-Path $releaseRoot ('tools/godot/' + $binaryName)
        $binaryTarget = Join-Path $buildEngineDirectory $binaryName
        if (-not (Test-Path -LiteralPath $binaryTarget) -or (Get-ReleaseSha256 $binarySource) -ne (Get-ReleaseSha256 $binaryTarget)) {
            Copy-Item -LiteralPath $binarySource -Destination $binaryTarget -Force
        }
    }
    Write-ReleaseText (Join-Path $buildEngineDirectory '_sc_') ''
    $godot = Join-Path $buildEngineDirectory 'Godot_v4.5.1-stable_win64_console.exe'
    $profile = Join-Path $releaseRoot '.runtime/release-build-profile'
    $env:APPDATA = $profile
    # Android repeatedly opens the same temporary APK while adding project files.
    # Write directly in this isolated build profile; completed artifacts are verified below.
    $editorSettings = "[gd_resource type=`"EditorSettings`" format=3]`r`n`r`n[resource]`r`nfilesystem/on_save/safe_save_on_backup_then_rename = false`r`nexport/android/java_sdk_path = " + (ConvertTo-GodotQuotedPath $android.JavaHome) + "`r`nexport/android/android_sdk_path = " + (ConvertTo-GodotQuotedPath $android.AndroidSdkRoot) + "`r`n"
    Write-ReleaseText (Join-Path $buildEngineDirectory 'editor_data/editor_settings-4.5.tres') $editorSettings
    Write-Host '[3/8] Importazione risorse Godot...'
    Invoke-ReleaseTool $godot @('--headless','--path',$releaseRoot,'--editor','--import','--quit','--log-file',(Join-Path $logDirectory 'godot-import.log')) (Join-Path $logDirectory 'import-console.log')
    $gameExeName = 'Niente Zombie Per Favore.exe'
    $windowsExe = Join-Path $windowsDirectory $gameExeName
    $apkPath = Join-Path $releaseDirectory ('Niente-Zombie-Per-Favore-' + $next.version + '.apk')
    Write-Host '[4/8] Esportazione Windows...'
    Invoke-ReleaseTool $godot @('--headless','--path',$releaseRoot,'--export-release','Windows',$windowsExe,'--log-file',(Join-Path $logDirectory 'godot-windows.log')) (Join-Path $logDirectory 'windows-console.log')
    if (-not (Test-Path -LiteralPath $windowsExe) -or (Get-Item -LiteralPath $windowsExe).VersionInfo.FileVersion.Trim() -ne $next.version) { throw 'Eseguibile Windows assente o versione diversa dal rilascio.' }
    foreach ($doc in @('GODOT_LICENSE.txt','AUDIO_LICENSES.md','CHARACTER_VOICES.md','USER_AUDIO_SOURCES.md','REVISIONE-0.4.1.md')) {
        Copy-Item -LiteralPath (Join-Path $releaseRoot ('docs/' + $doc)) -Destination $windowsDirectory
    }
    foreach ($licenseDirectory in @('assets/fonts','assets/audio','assets/audio/voices')) {
        Get-ChildItem -LiteralPath (Join-Path $releaseRoot $licenseDirectory) -File | Where-Object { $_.Name -like 'OFL-*.txt' -or $_.Name -like 'LICENSE*.txt' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $windowsDirectory }
    }
    $readme = Get-Content -LiteralPath (Join-Path $releaseRoot 'builds/LEGGIMI.txt') -Raw -Encoding UTF8
    $readme = [regex]::Replace($readme, '(?m)^(NIENTE ZOMBIE PER FAVORE! - versione )\d+\.\d+\.\d+\.\d+', ('${1}' + $next.version))
    Write-ReleaseText (Join-Path $windowsDirectory 'LEGGIMI.txt') $readme

    Write-Host '[5/8] Esportazione APK Android firmato...'
    Invoke-ReleaseTool $godot @('--headless','--path',$releaseRoot,'--export-release','Android',$apkPath,'--log-file',(Join-Path $logDirectory 'godot-android.log')) (Join-Path $logDirectory 'android-console.log')
    if (-not (Test-Path -LiteralPath $apkPath)) { throw 'APK non generato.' }
    Write-Host '[6/8] Verifica firma, allineamento e versione APK...'
    Invoke-ReleaseTool $android.ApkSigner @('verify','--verbose','--print-certs',$apkPath) (Join-Path $logDirectory 'apk-signature.log')
    Invoke-ReleaseTool $android.ZipAlign @('-c','-P','16','-v','4',$apkPath) (Join-Path $logDirectory 'apk-alignment.log')
    Invoke-ReleaseTool $android.Aapt @('dump','badging',$apkPath) (Join-Path $logDirectory 'apk-metadata.log')
    $metadata = Get-Content -LiteralPath (Join-Path $logDirectory 'apk-metadata.log') -Raw -Encoding UTF8
    if ($metadata -notmatch ("versionCode='" + $next.android_version_code + "'") -or $metadata -notmatch ("versionName='" + [regex]::Escape($next.version) + "'") -or $metadata -notmatch "package: name='org.rifugio07.nientezombieperfavore'") { throw 'Nome pacchetto o versione APK non corrispondono al rilascio.' }

    Write-Host '[7/8] Creazione del setup Windows...'
    Invoke-ReleaseTool ([string]$compiler) @('/Qp',('/DGameVersion=' + $next.version),('/DBuildDir=' + $windowsDirectory),('/DOutputDir=' + $releaseDirectory),('/DGameExe=' + $gameExeName),(Join-Path $PSScriptRoot 'installer/windows.iss')) (Join-Path $logDirectory 'windows-setup.log')
    $setupPath = Join-Path $releaseDirectory ('Niente-Zombie-Per-Favore-Setup-' + $next.version + '.exe')
    if (-not (Test-Path -LiteralPath $setupPath) -or (Get-Item -LiteralPath $setupPath).VersionInfo.FileVersion.Trim() -ne $next.version) { throw 'Setup Windows assente o versione non corrispondente.' }
    Write-Host '[8/8] Riepilogo e checksum del rilascio...'
    $artifacts = @()
    $checksumLines = @()
    foreach ($artifact in @($setupPath,$apkPath,$windowsExe)) {
        $hash = Get-ReleaseSha256 $artifact
        $relative = $artifact.Substring($releaseDirectory.Length + 1).Replace('\','/')
        $artifacts += [ordered]@{ file = $relative; size = (Get-Item -LiteralPath $artifact).Length; sha256 = $hash }
        $checksumLines += $hash + '  ' + $relative
    }
    Write-ReleaseText (Join-Path $releaseDirectory 'SHA256SUMS.txt') ($checksumLines -join "`r`n")
    $manifest['status'] = 'complete'
    $manifest['completed_utc'] = [DateTime]::UtcNow.ToString('o')
    $manifest['artifacts'] = $artifacts
    Write-ReleaseText $manifestPath ($manifest | ConvertTo-Json -Depth 8)
    Write-ReleaseText (Join-Path $releaseOutputRoot 'latest.json') ($manifest | ConvertTo-Json -Depth 8)
    Write-Host ''
    Write-Host ('BUILD COMPLETATA: ' + $next.version) -ForegroundColor Green
    Write-Host ('Setup: ' + $setupPath)
    Write-Host ('APK:   ' + $apkPath)
    Write-Host 'Conserva .release-private: contiene la chiave necessaria agli aggiornamenti Android.'
    exit 0
} catch {
    if ($releaseDirectory -and (Test-Path -LiteralPath (Join-Path $releaseDirectory 'logs'))) {
        try { Write-ReleaseText (Join-Path $releaseDirectory 'logs/build-error.log') ($_.ToString() + "`r`n" + $_.InvocationInfo.PositionMessage + "`r`n" + $_.ScriptStackTrace) } catch { }
    }
    if ($null -ne $manifest) {
        $manifest['status'] = 'failed'
        $manifest['error'] = $_.Exception.Message
        try { Write-ReleaseText $manifestPath ($manifest | ConvertTo-Json -Depth 8) } catch { }
    }
    Write-Host ('ERRORE: ' + $_.Exception.Message) -ForegroundColor Red
    if ($releaseDirectory) { Write-Host ('Log e dettagli: ' + $releaseDirectory) }
    exit 1
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process') }
    if ($null -ne $lock) { $lock.Dispose() }
}
