"""Fetch one Godot export-template ZIP member using HTTP Range requests only.

No third-party packages are required. The archive index is read remotely and the
requested member is streamed, decompressed and CRC-checked by Python's zipfile.
Servers that ignore byte ranges are rejected before their payload is downloaded.
"""

from __future__ import annotations

import argparse
import io
import re
import struct
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

DEFAULT_URL = (
    "https://github.com/godotengine/godot/releases/download/4.5.1-stable/"
    "Godot_v4.5.1-stable_export_templates.tpz"
)
DEFAULT_MEMBER = "templates/windows_release_x86_64.exe"


class RemoteZip(io.RawIOBase):
    def __init__(self, url: str):
        self.url = url
        self.position = 0
        self.transferred = 0
        self.requests = 0
        self._cache_start = -1
        self._cache = b""
        # An actual one-byte request both resolves redirects and proves that the
        # final asset endpoint honors ranges. A HEAD-only check cannot prove it.
        probe = self._request(0, 0)
        self.length = probe[1]

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_CUR:
            offset += self.position
        elif whence == io.SEEK_END:
            offset += self.length
        elif whence != io.SEEK_SET:
            raise ValueError("Unsupported seek mode")
        if offset < 0:
            raise ValueError("Cannot seek before archive start")
        self.position = offset
        return self.position

    def _request(self, start: int, end: int):
        error = None
        for attempt in range(4):
            request = urllib.request.Request(
                self.url,
                headers={
                    "User-Agent": "Godot-Selective-Template-Fetch/1.0",
                    "Range": f"bytes={start}-{end}",
                    "Accept-Encoding": "identity",
                },
            )
            try:
                with urllib.request.urlopen(request, timeout=90) as response:
                    if response.status != 206:
                        raise RuntimeError(
                            f"Server ignored byte Range ({response.status}); "
                            "refusing to download the complete archive."
                        )
                    content_range = response.headers.get("Content-Range", "")
                    match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", content_range)
                    if not match:
                        raise RuntimeError(f"Invalid Content-Range: {content_range!r}")
                    actual_start, actual_end, length = map(int, match.groups())
                    if (actual_start, actual_end) != (start, end):
                        raise RuntimeError(
                            f"Incorrect range: requested {start}-{end}, got {content_range}"
                        )
                    size = end - start + 1
                    data = response.read(size + 1)
                    if len(data) != size:
                        raise RuntimeError(f"Incomplete range: {len(data)} != {size}")
                    self.url = response.geturl()
                    self.transferred += len(data)
                    self.requests += 1
                    return data, length
            except (urllib.error.URLError, TimeoutError, OSError) as exc:
                error = exc
                if attempt < 3:
                    time.sleep(1 + attempt)
        raise RuntimeError(f"Range request failed: {error}") from error

    def read(self, size=-1):
        if size is None or size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)
        if size <= 0:
            return b""
        if self._cache_start <= self.position and (
            self.position + size <= self._cache_start + len(self._cache)
        ):
            begin = self.position - self._cache_start
            data = self._cache[begin : begin + size]
        else:
            # Cache small index/header reads to avoid a separate HTTP round trip
            # for each 30-byte local file header and its member name.
            fetch_size = max(size, 65536)
            end = min(self.length - 1, self.position + fetch_size - 1)
            payload, _ = self._request(self.position, end)
            self._cache_start = self.position
            self._cache = payload
            data = payload[:size]
        self.position += len(data)
        return data


def fetch(url: str, member: str, destination: Path):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".part")
    with RemoteZip(url) as remote:
        print(f"Remote archive: {remote.length:,} bytes", flush=True)
        with zipfile.ZipFile(remote) as archive:
            info = archive.getinfo(member)
            print(
                f"Selected {member}: {info.compress_size:,} compressed / "
                f"{info.file_size:,} uncompressed bytes; CRC32 {info.CRC:08x}",
                flush=True,
            )
            total = 0
            with archive.open(info) as source, temporary.open("wb") as target:
                while chunk := source.read(4 * 1024 * 1024):
                    target.write(chunk)
                    total += len(chunk)
                    print(f"Extracted {total:,} / {info.file_size:,} bytes", flush=True)
            if total != info.file_size:
                raise RuntimeError("Extracted template size differs from ZIP index")
            # A release template must be a valid PE file, not an HTML error page.
            with temporary.open("rb") as check:
                if check.read(2) != b"MZ":
                    raise RuntimeError("Template is not a Windows executable")
                check.seek(0x3C)
                pe_offset = struct.unpack("<I", check.read(4))[0]
                check.seek(pe_offset)
                if check.read(4) != b"PE\0\0":
                    raise RuntimeError("Template has an invalid PE header")
                if check.read(2) != b"\x64\x86":
                    raise RuntimeError("Template is not an x86-64 executable")
        temporary.replace(destination)
        print(
            f"Saved {destination.resolve()}\n"
            f"Transferred {remote.transferred:,} bytes in {remote.requests} Range requests "
            f"({remote.transferred / remote.length:.1%} of full archive).",
            flush=True,
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--member", default=DEFAULT_MEMBER)
    parser.add_argument(
        "--output", type=Path,
        default=Path(__file__).resolve().parent / "templates/windows_release_x86_64.exe",
    )
    args = parser.parse_args()
    try:
        fetch(args.url, args.member, args.output)
    except Exception as error:
        print(f"Template fetch failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
