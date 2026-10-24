# Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
. (Join-Path $projectDirectory 'tools\release_common.ps1')
$script:checks = 0

function Assert-ReleaseTest {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}

function Assert-ReleaseThrows {
    param([scriptblock] $Action, [string] $Message)
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-ReleaseTest $threw $Message
}

function Assert-NextRelease {
    param([string] $Current, [string] $Expected, [long] $Code = 1)
    $state = [pscustomobject]@{ version = $Current; android_version_code = $Code }
    $next = Get-NextReleaseVersion -State $state
    Assert-ReleaseTest ($next.version -ceq $Expected) "Increment $Current -> $Expected"
    Assert-ReleaseTest ($next.android_version_code -eq ($Code + 1)) "Android code increments with $Current"
    Assert-ReleaseTest ($state.version -ceq $Current -and $state.android_version_code -eq $Code) 'Version calculation does not mutate its input'
}

Assert-NextRelease '0.4.1.4' '0.4.1.5' 10
Assert-NextRelease '0.4.1.65535' '0.4.2.0' 65535
Assert-NextRelease '0.4.65535.65535' '0.5.0.0' 65536
Assert-NextRelease '0.65535.65535.65535' '1.0.0.0' 2099999999
Assert-NextRelease '65535.65535.65535.65534' '65535.65535.65535.65535' 123
foreach ($invalidVersion in @('65535.65535.65535.65535','0.4.1.65536','65536.0.0.0','0.4.1','0.4.1.2.3','0.4.-1.2','v0.4.1.2','0.4.1.beta','')) {
    $candidate = [pscustomobject]@{ version = $invalidVersion; android_version_code = 1 }
    Assert-ReleaseThrows { Get-NextReleaseVersion $candidate } "Reject invalid or exhausted Windows version '$invalidVersion'"
}
foreach ($invalidCode in @(-1,0,2100000000,2100000001)) {
    $candidate = [pscustomobject]@{ version = '0.4.1.4'; android_version_code = $invalidCode }
    Assert-ReleaseThrows { Get-NextReleaseVersion $candidate } "Reject invalid or exhausted Android code $invalidCode"
}

$crlf = "`r`n"
$prefix = '; fixture header' + $crlf
$windows = @(
    '[preset.0.options]',
    'application/file_version="0.4.1.4"',
    'application/product_version="0.4.1.4"',
    'version.name="windows literal-dot key"',
    'versionXname="must stay"',
    'keep="windows"',
    ''
) -join $crlf
$android = @(
    '[preset.1.options]',
    'version/name="0.4.1.4"',
    'version/code=10',
    'application/file_version="android same key"',
    'keep="android"',
    ''
) -join $crlf
$decoy = @(
    '[presetX0Xoptions]',
    'application/file_version="decoy section"',
    'keep="decoy"',
    ''
) -join $crlf
$fixture = $prefix + $decoy + $windows + $android
$updated = Set-GodotConfigValue $fixture 'preset.0.options' 'application/file_version' '"0.4.1.5"'
$expectedWindows = $windows.Replace('application/file_version="0.4.1.4"','application/file_version="0.4.1.5"')
Assert-ReleaseTest ($updated -ceq ($prefix + $decoy + $expectedWindows + $android)) 'Windows value changes only in exact section and key'
$updatedAndroid = Set-GodotConfigValue $updated 'preset.1.options' 'version/code' '11'
Assert-ReleaseTest ($updatedAndroid -ceq ($prefix + $decoy + $expectedWindows + $android.Replace('version/code=10','version/code=11'))) 'Android version changes independently from Windows section'
$dotted = Set-GodotConfigValue $fixture 'preset.0.options' 'version.name' '"literal updated"'
Assert-ReleaseTest ($dotted -ceq $fixture.Replace('version.name="windows literal-dot key"','version.name="literal updated"')) 'Literal dots in keys do not match other characters'
$literalValue = '"$1\folder\${unchanged}"'
$literal = Set-GodotConfigValue $fixture 'preset.0.options' 'keep' $literalValue
Assert-ReleaseTest ($literal -ceq $fixture.Replace('keep="windows"',('keep=' + $literalValue))) 'Dollar signs and backslashes in replacement remain literal'
$inserted = Set-GodotConfigValue $fixture 'preset.1.options' 'new/key' '"new value"'
Assert-ReleaseTest ($inserted.StartsWith($prefix + $decoy + $windows, [StringComparison]::Ordinal)) 'Adding a key preserves all preceding sections byte for byte'
Assert-ReleaseTest ([regex]::Matches($inserted,'(?m)^new/key="new value"\r?$').Count -eq 1) 'Missing key is added exactly once'
$insertedAgain = Set-GodotConfigValue $inserted 'preset.1.options' 'new/key' '"second value"'
Assert-ReleaseTest ([regex]::Matches($insertedAgain,'(?m)^new/key=').Count -eq 1) 'Updating an inserted key does not add duplicates'
Assert-ReleaseTest ($insertedAgain.Contains('new/key="second value"')) 'Inserted key receives its new value'
Assert-ReleaseThrows { Set-GodotConfigValue $fixture 'preset.2.options' 'version/code' '99' } 'Missing section fails instead of modifying another section'
$lastLineFixture = "[application]`nconfig/name=`"Game`"`nconfig/version=`"0.4.1.4`""
$lastLineUpdated = Set-GodotConfigValue $lastLineFixture 'application' 'config/version' '"0.4.1.5"'
Assert-ReleaseTest ($lastLineUpdated -ceq "[application]`nconfig/name=`"Game`"`nconfig/version=`"0.4.1.5`"`r`n") 'Last config line can be replaced without an existing final newline'

# All file tests stay inside a unique disposable workspace directory. Files are
# deliberately retained for inspection; no recursive removal is performed.
$testDirectory = Join-Path $projectDirectory ('.runtime\release-tool-tests\' + [guid]::NewGuid().ToString('N'))
$specialDirectory = Join-Path $testDirectory "folder with spaces and ' apostrophe [brackets]"
$textPath = Join-Path $specialDirectory 'VERSION fixture.json'
[IO.Directory]::CreateDirectory($specialDirectory) | Out-Null
$hashPath = Join-Path $specialDirectory 'hash fixture.txt'
[IO.File]::WriteAllText($hashPath,'abc',(New-Object Text.UTF8Encoding($false)))
Assert-ReleaseTest ((Get-ReleaseSha256 $hashPath) -ceq 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') 'SHA-256 matches the standard abc vector in a literal path'
[IO.File]::WriteAllBytes($hashPath,(New-Object byte[] 0))
Assert-ReleaseTest ((Get-ReleaseSha256 $hashPath) -ceq 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') 'SHA-256 matches the standard empty-file vector'
Assert-ReleaseThrows { Get-ReleaseSha256 (Join-Path $specialDirectory 'missing.bin') } 'Checksum of a missing file fails instead of accepting a cache'
$unicodeText = '{"title":"Caff' + [char]0x00E8 + ' ' + [char]0x00E8 + ' pronto ' + [char]::ConvertFromUtf32(0x1F9DF) + '","version":"0.4.1.5"}' + $crlf
Write-ReleaseText -Path $textPath -Text $unicodeText
Assert-ReleaseTest ([IO.File]::Exists($textPath)) 'Atomic writer creates a new file in nested paths containing spaces and punctuation'
Assert-ReleaseTest ([IO.File]::ReadAllText($textPath,[Text.Encoding]::UTF8) -ceq $unicodeText) 'New file preserves accented characters, supplementary Unicode and newlines'
$firstBytes = [IO.File]::ReadAllBytes($textPath)
$hasBom = $firstBytes.Length -ge 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF
Assert-ReleaseTest (-not $hasBom) 'New UTF-8 file has no byte-order mark'
# Replacing a legacy BOM-bearing file must normalize it to the same encoding.
[IO.File]::WriteAllText($textPath,$unicodeText,(New-Object Text.UTF8Encoding($true)))
$legacyBytes = [IO.File]::ReadAllBytes($textPath)
Assert-ReleaseTest ($legacyBytes[0] -eq 0xEF -and $legacyBytes[1] -eq 0xBB -and $legacyBytes[2] -eq 0xBF) 'Existing-file fixture starts with a legacy UTF-8 BOM'
$replacementText = '{"version":"0.4.1.6","updated":true}' + $crlf
Write-ReleaseText -Path $textPath -Text $replacementText
Assert-ReleaseTest ([IO.File]::ReadAllText($textPath,[Text.Encoding]::UTF8) -ceq $replacementText) 'Atomic writer replaces an existing file'
$replacementBytes = [IO.File]::ReadAllBytes($textPath)
$replacementHasBom = $replacementBytes.Length -ge 3 -and $replacementBytes[0] -eq 0xEF -and $replacementBytes[1] -eq 0xBB -and $replacementBytes[2] -eq 0xBF
Assert-ReleaseTest (-not $replacementHasBom) 'Replacing an existing UTF-8 file removes its old byte-order mark'
Assert-ReleaseTest (@(Get-ChildItem -LiteralPath $specialDirectory -File -Filter '*.tmp').Count -eq 0) 'Successful writes leave no temporary files'
$exclusiveHandle = [IO.File]::Open($textPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    Assert-ReleaseThrows { Write-ReleaseText -Path $textPath -Text 'should never replace locked content' } 'Atomic writer fails safely while destination is exclusively locked'
}
finally { $exclusiveHandle.Dispose() }
Assert-ReleaseTest ([IO.File]::ReadAllText($textPath,[Text.Encoding]::UTF8) -ceq $replacementText) 'Failed write leaves the existing file intact'
Assert-ReleaseTest (@(Get-ChildItem -LiteralPath $specialDirectory -File -Filter '*.tmp').Count -eq 0) 'Failed writes clean up temporary files'

$lockPath = Join-Path $testDirectory 'release-build.lock'
$firstLock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    Assert-ReleaseThrows {
        $secondLock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $secondLock.Dispose()
    } 'Exclusive build lock rejects a simultaneous second release'
}
finally { $firstLock.Dispose() }
$reopenedLock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$reopenedLock.Dispose()
Assert-ReleaseTest $true 'Build lock can be acquired after its previous owner disposes it'

Write-Output "PASS: $script:checks release tool checks (PowerShell $($PSVersionTable.PSVersion))."
Write-Output "Fixtures retained in $testDirectory"
exit 0
