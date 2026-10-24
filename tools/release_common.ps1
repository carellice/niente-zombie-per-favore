# Shared release functions, compatible with Windows PowerShell 5.1.
Set-StrictMode -Version 2.0

function Get-ReleaseSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    # Avoid the scope-sensitive Get-FileHash script function in Windows PowerShell.
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

function Get-NextReleaseVersion {
    param([Parameter(Mandatory=$true)]$State)
    if ([string]$State.version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'VERSION.json: la versione deve avere quattro numeri, es. 0.4.1.4.' }
    $parts = @(([string]$State.version).Split('.') | ForEach-Object { [long]$_ })
    foreach ($part in $parts) { if ($part -gt 65535) { throw 'Ogni parte della versione Windows deve essere <= 65535.' } }
    for ($index = 3; $index -ge 0; $index--) {
        if ($parts[$index] -lt 65535) { $parts[$index]++; break }
        if ($index -eq 0) { throw 'Versione Windows esaurita.' }
        $parts[$index] = 0
    }
    $code = [long]$State.android_version_code
    if ($code -lt 1 -or $code -ge 2100000000) { throw 'versionCode Android non valido o esaurito.' }
    return [pscustomobject]@{ version = ($parts -join '.'); android_version_code = ($code + 1) }
}

function Write-ReleaseText {
    param([string]$Path, [string]$Text)
    $directory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, $Text, (New-Object Text.UTF8Encoding($false)))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Set-GodotConfigValue {
    param([string]$Text, [string]$Section, [string]$Key, [string]$Value)
    $sectionPattern = '(?ms)(^\[' + [regex]::Escape($Section) + '\]\r?\n)(.*?)(?=^\[|\z)'
    $match = [regex]::Match($Text, $sectionPattern)
    if (-not $match.Success) { throw "Sezione Godot mancante: [$Section]" }
    $body = $match.Groups[2].Value
    $keyPattern = '(?m)^' + [regex]::Escape($Key) + '\s*=.*(?:\r?\n|$)'
    $line = $Key + '=' + $Value + "`r`n"
    if ([regex]::IsMatch($body, $keyPattern)) {
        $replacement = [Text.RegularExpressions.MatchEvaluator]{ param($unusedMatch) $line }
        $body = ([regex]::new($keyPattern)).Replace($body, $replacement, 1)
    } else { $body = $body.TrimEnd() + "`r`n" + $line + "`r`n" }
    return $Text.Substring(0, $match.Index) + $match.Groups[1].Value + $body + $Text.Substring($match.Index + $match.Length)
}

function ConvertTo-GodotQuotedPath {
    param([string]$Path)
    return ConvertTo-Json -InputObject ($Path.Replace('\','/')) -Compress
}

function Invoke-ReleaseTool {
    param([string]$Program, [string[]]$Arguments, [string]$LogPath)
    $previousPreference = $ErrorActionPreference
    try {
        # Windows PowerShell treats stderr from native tools as ErrorRecords.
        # The actual process exit code determines success, not harmless stderr.
        $ErrorActionPreference = 'Continue'
        & $Program @Arguments 2>&1 | Out-File -LiteralPath $LogPath -Encoding utf8
        $nativeExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($nativeExitCode -ne 0) {
        if (Test-Path -LiteralPath $LogPath) { Get-Content -LiteralPath $LogPath -Tail 18 | Write-Host }
        throw "Comando fallito (codice $nativeExitCode): $Program. Log: $LogPath"
    }
}
