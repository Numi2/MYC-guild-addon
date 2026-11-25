#!/usr/bin/env python3
"""Build the installable archive deterministically from the tracked source."""
import argparse
import io
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def build(root=ROOT):
    addon = root / "MYCRadar"
    toc = addon / "MYCRadar.toc"
    entries = [line.strip() for line in toc.read_text().splitlines()
               if line.strip() and not line.startswith("#")]
    paths = [toc, *(addon / name for name in entries), addon / "README.md"]
    assert len(paths) == len(set(paths)), "Duplicate file in TOC"
    assert all(path.is_file() and path.parent == addon for path in paths), "Missing/invalid source file"
    assert set(addon.glob("*.lua")) == {addon / name for name in entries}, "Unlisted Lua source"
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in paths:
            info = zipfile.ZipInfo("MYCRadar/" + path.name, date_time=(2026, 11, 16, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compresslevel=9)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the tracked ZIP differs from source")
    parser.add_argument("--output", type=Path, default=ROOT / "MYCRadar.zip")
    args = parser.parse_args()
    content = build()
    if args.check:
        assert args.output.read_bytes() == content, "MYCRadar.zip is stale; run python3 scripts/package.py"
        print("PASS: ZIP exactly matches the addon source")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(content)
        print(f"Built {args.output.name}: {len(content):,} bytes")


if __name__ == "__main__":
    main()
