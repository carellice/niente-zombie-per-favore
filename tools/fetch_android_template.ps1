# Download only the Android APKs from the official, version-pinned Godot archive.
# PowerShell 5.1+ and .NET are sufficient; no Python or extra ZIP tools are needed.
[CmdletBinding()]
param(
    [string]$DestinationDirectory = '',
    [ValidateSet('All', 'Debug', 'Release')][string]$Kind = 'All',
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_common.ps1')
Set-StrictMode -Version Latest
if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
    $DestinationDirectory = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'templates'
}
$templateVersion = '4.5.1-stable'
$archiveUrl = 'https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz'
$archiveLength = [long]1355592535
# This digest is published by GitHub for the complete official release asset.
# Selective extraction validates each complete APK against its own pinned digest,
# rather than claiming that partial archive bytes can validate the archive hash.
$archiveSha256 = '1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86'
$templates = @(
    @{ Kind = 'Debug'; Name = 'android_debug.apk'; Size = [long]124501622; Crc32 = [Convert]::ToUInt32('db7f8371', 16); Sha256 = 'a94aa329eda7ef265ec5504324f45b2c4a97acf5b5786e32879f6ac3ad8d3e3b' },
    @{ Kind = 'Release'; Name = 'android_release.apk'; Size = [long]102152390; Crc32 = [Convert]::ToUInt32('c9e466ac', 16); Sha256 = '5c65ea869de294d14738371089b38d2ccf6a101e904e79a1df9f9db37b237711' }
)

function Test-Template([string]$Path, [hashtable]$Template) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -ne $Template.Size) { return $false }
    return (Get-ReleaseSha256 $Path) -eq $Template.Sha256
}

if (-not ('GodotAndroidTemplate.RangeSource' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Threading;

namespace GodotAndroidTemplate {
    public static class RangeSource {
        public static byte[] Read(string url, long start, long end, long archiveLength) {
            Exception last = null;
            for (int attempt = 0; attempt < 4; attempt++) {
                try {
                    ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
                    var request = (HttpWebRequest)WebRequest.Create(url);
                    request.UserAgent = "NienteZombie-Android-Template/1.0";
                    request.AllowAutoRedirect = true;
                    request.Timeout = 120000;
                    request.ReadWriteTimeout = 120000;
                    request.AutomaticDecompression = DecompressionMethods.None;
                    request.Headers[HttpRequestHeader.AcceptEncoding] = "identity";
                    request.AddRange(start, end);
                    using (var response = (HttpWebResponse)request.GetResponse()) {
                        string wanted = "bytes " + start + "-" + end + "/" + archiveLength;
                        if (response.StatusCode != HttpStatusCode.PartialContent ||
                            response.Headers[HttpResponseHeader.ContentRange] != wanted) {
                            throw new InvalidDataException("Server ignored or changed HTTP Range; refusing full archive download.");
                        }
                        int length = checked((int)(end - start + 1));
                        var data = new byte[length];
                        int offset = 0;
                        using (var stream = response.GetResponseStream()) {
                            while (offset < length) {
                                int read = stream.Read(data, offset, length - offset);
                                if (read == 0) throw new EndOfStreamException("Incomplete template download.");
                                offset += read;
                            }
                            if (stream.ReadByte() != -1) throw new InvalidDataException("Unexpected range payload length.");
                        }
                        return data;
                    }
                } catch (Exception error) {
                    last = error;
                    if (attempt < 3) Thread.Sleep((attempt + 1) * 1000);
                }
            }
            throw new IOException("Could not read official Godot template archive.", last);
        }
        public static void Extract(byte[] compressed, int method, string output) {
            using (var target = new FileStream(output, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var source = new MemoryStream(compressed, false)) {
                if (method == 0) {
                    source.CopyTo(target);
                } else if (method == 8) {
                    using (var deflate = new System.IO.Compression.DeflateStream(source, System.IO.Compression.CompressionMode.Decompress)) {
                        deflate.CopyTo(target);
                    }
                } else {
                    throw new InvalidDataException("Unsupported ZIP compression method: " + method);
                }
            }
        }
    }
}
'@
}

function Read-ArchiveIndex {
    # The complete archive is < 4 GiB. Reject unexpected ZIP64/multidisk changes.
    $tailStart = $archiveLength - 65557
    $tail = [GodotAndroidTemplate.RangeSource]::Read($archiveUrl, $tailStart, $archiveLength - 1, $archiveLength)
    $endOffset = -1
    for ($offset = $tail.Length - 22; $offset -ge 0; $offset--) {
        if ([BitConverter]::ToUInt32($tail, $offset) -eq 0x06054b50 -and
            $offset + 22 + [BitConverter]::ToUInt16($tail, $offset + 20) -eq $tail.Length) {
            $endOffset = $offset
            break
        }
    }
    if ($endOffset -lt 0) { throw 'Official template archive has no valid ZIP end record.' }
    if ([BitConverter]::ToUInt16($tail, $endOffset + 4) -ne 0 -or
        [BitConverter]::ToUInt16($tail, $endOffset + 6) -ne 0) { throw 'Multidisk ZIP is unsupported.' }
    $count = [BitConverter]::ToUInt16($tail, $endOffset + 10)
    $directorySize = [long][BitConverter]::ToUInt32($tail, $endOffset + 12)
    $directoryStart = [long][BitConverter]::ToUInt32($tail, $endOffset + 16)
    if ($count -eq 65535 -or $directorySize -gt 1048576 -or $directoryStart + $directorySize -gt $archiveLength) {
        throw 'Unexpected official archive index; refusing an unbounded download.'
    }
    $bytes = [GodotAndroidTemplate.RangeSource]::Read($archiveUrl, $directoryStart, $directoryStart + $directorySize - 1, $archiveLength)
    $index = @{}
    $offset = 0
    for ($i = 0; $i -lt $count; $i++) {
        if ($offset + 46 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, $offset) -ne 0x02014b50) {
            throw 'Invalid ZIP central directory.'
        }
        $nameLength = [int][BitConverter]::ToUInt16($bytes, $offset + 28)
        $extraLength = [int][BitConverter]::ToUInt16($bytes, $offset + 30)
        $commentLength = [int][BitConverter]::ToUInt16($bytes, $offset + 32)
        $next = $offset + 46 + $nameLength + $extraLength + $commentLength
        if ($next -gt $bytes.Length) { throw 'ZIP directory entry exceeds archive index.' }
        $name = [Text.Encoding]::UTF8.GetString($bytes, $offset + 46, $nameLength)
        $index[$name] = @{
            Flags = [BitConverter]::ToUInt16($bytes, $offset + 8)
            Method = [BitConverter]::ToUInt16($bytes, $offset + 10)
            Crc32 = [BitConverter]::ToUInt32($bytes, $offset + 16)
            CompressedSize = [long][BitConverter]::ToUInt32($bytes, $offset + 20)
            Size = [long][BitConverter]::ToUInt32($bytes, $offset + 24)
            Offset = [long][BitConverter]::ToUInt32($bytes, $offset + 42)
        }
        $offset = $next
    }
    return $index
}

$destination = [IO.Path]::GetFullPath($DestinationDirectory)
$selected = @($templates | Where-Object { $Kind -eq 'All' -or $_.Kind -eq $Kind })
$missing = @($selected | Where-Object { -not (Test-Template (Join-Path $destination $_.Name) $_) })
if ($missing.Count -gt 0 -and $VerifyOnly) {
    throw ('Android templates missing or invalid: ' + (($missing | ForEach-Object { $_.Name }) -join ', '))
}
if ($missing.Count -gt 0) {
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    Write-Host "Reading official Godot $templateVersion template archive index..."
    $archiveIndex = Read-ArchiveIndex
    foreach ($template in $missing) {
        $member = 'templates/' + $template.Name
        if (-not $archiveIndex.ContainsKey($member)) { throw "Missing official archive member: $member" }
        $entry = $archiveIndex[$member]
        if ($entry.Size -ne $template.Size -or $entry.Crc32 -ne $template.Crc32 -or
            ($entry.Flags -band 1) -ne 0 -or $entry.CompressedSize -gt 150000000) {
            throw "Unexpected official template metadata: $member"
        }
        $header = [GodotAndroidTemplate.RangeSource]::Read($archiveUrl, $entry.Offset, $entry.Offset + 29, $archiveLength)
        if ([BitConverter]::ToUInt32($header, 0) -ne 0x04034b50) { throw "Invalid ZIP file header: $member" }
        $dataStart = $entry.Offset + 30 + [BitConverter]::ToUInt16($header, 26) + [BitConverter]::ToUInt16($header, 28)
        if ($dataStart + $entry.CompressedSize -gt $archiveLength) { throw 'Template exceeds archive bounds.' }
        Write-Host ("Downloading {0} ({1:N1} MB)..." -f $template.Name, ($entry.CompressedSize / 1MB))
        $compressed = [GodotAndroidTemplate.RangeSource]::Read($archiveUrl, $dataStart, $dataStart + $entry.CompressedSize - 1, $archiveLength)
        $target = Join-Path $destination $template.Name
        $temporary = $target + '.part-' + [Guid]::NewGuid().ToString('N')
        try {
            [GodotAndroidTemplate.RangeSource]::Extract($compressed, $entry.Method, $temporary)
            if (-not (Test-Template $temporary $template)) { throw "SHA256 mismatch: $($template.Name)" }
            Move-Item -LiteralPath $temporary -Destination $target -Force
        } finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
            $compressed = $null
        }
    }
}
foreach ($template in $selected) {
    Write-Host ("Verified {0}: SHA256 {1}" -f $template.Name, $template.Sha256)
}
if (-not $VerifyOnly) {
    $verifiedTemplates = @($templates | Where-Object { Test-Template (Join-Path $destination $_.Name) $_ } | ForEach-Object {
        [ordered]@{ name = $_.Name; bytes = $_.Size; sha256 = $_.Sha256; archive_crc32 = $_.Crc32.ToString('x8') }
    })
    $provenance = [ordered]@{
        godot_version = $templateVersion
        source_url = $archiveUrl
        source_release_metadata = 'https://api.github.com/repos/godotengine/godot/releases/tags/4.5.1-stable'
        official_archive_sha256 = $archiveSha256
        archive_bytes = $archiveLength
        validation = 'Complete APK SHA256 pinned to selective extraction from the official release; archive SHA256 is provenance only because the full archive is not downloaded.'
        templates = $verifiedTemplates
    }
    [IO.File]::WriteAllText((Join-Path $destination 'android_templates_manifest.json'), ($provenance | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
}
Write-Host "Godot $templateVersion Android templates are ready in $destination"
