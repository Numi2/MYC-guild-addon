#!/usr/bin/env python3
"""Validate release metadata and build versioned GitHub release assets."""
import argparse
from datetime import date
import hashlib
from pathlib import Path
import re

from package import ROOT, build

VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def release_metadata(root=ROOT, tag=None):
    addon = root / "MYCRadar"
    versions = re.findall(r"^## Version: (.+)$", (addon / "MYCRadar.toc").read_text(encoding="utf-8"), re.M)
    if len(versions) != 1 or not re.fullmatch(VERSION, versions[0]):
        raise ValueError("TOC must contain one MAJOR.MINOR.PATCH version")
    version = versions[0]
    if tag is not None and tag != "v" + version:
        raise ValueError(f"Tag must be v{version}, got {tag!r}")
    core = re.findall(r'^R\.version = "([^"\n]+)"$', (addon / "Core.lua").read_text(encoding="utf-8"), re.M)
    if core != [version]:
        raise ValueError("Core.lua version must match the TOC")
    guide = (addon / "README.md").read_text(encoding="utf-8").splitlines()
    if not guide or guide[0] != "# MYC Radar " + version:
        raise ValueError("Addon guide version must match the TOC")
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    headings = list(re.finditer(r"^## (.+)$", changelog, re.M))
    if not headings:
        raise ValueError("Changelog needs a dated release entry")
    first = headings[0]
    heading = re.fullmatch(r"\[" + re.escape(version) + r"\] - (\d{4}-\d{2}-\d{2})", first.group(1))
    if not heading:
        raise ValueError("First changelog entry must match the TOC version and have a release date")
    date.fromisoformat(heading.group(1))
    notes = changelog[first.end():headings[1].start() if len(headings) > 1 else len(changelog)].strip()
    if not notes:
        raise ValueError("Release notes must not be empty")
    return version, notes + "\n"


def build_release(output_dir, tag, root=ROOT):
    version, notes = release_metadata(root, tag)
    content = build(root)
    filename = f"MYCRadar-{version}.zip"
    checksum = hashlib.sha256(content).hexdigest()
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / filename).write_bytes(content)
    (output_dir / "SHA256SUMS.txt").write_text(f"{checksum}  {filename}\n", encoding="utf-8")
    (output_dir / "RELEASE_NOTES.md").write_text(notes, encoding="utf-8")
    return output_dir / filename


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Existing release tag, e.g. v2.3.0")
    parser.add_argument("--check", action="store_true", help="Validate metadata without creating assets")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    if not args.check and not args.tag:
        parser.error("--tag is required to build release assets")
    try:
        version, _ = release_metadata(tag=args.tag)
        if args.check:
            print(f"PASS: v{version} release metadata agrees")
        else:
            archive = build_release(args.output_dir, args.tag)
            print(f"Built {archive.name}, SHA256SUMS.txt and RELEASE_NOTES.md")
    except (ValueError, OSError, AssertionError) as error:
        parser.exit(1, f"Release validation failed: {error}\n")


if __name__ == "__main__":
    main()
