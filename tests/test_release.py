"""Release failures must be caught before publishing an installable asset."""
import hashlib
import io
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from package import ROOT, build
from release import build_release, release_metadata


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copytree(ROOT / "MYCRadar", self.root / "MYCRadar")
        shutil.copyfile(ROOT / "CHANGELOG.md", self.root / "CHANGELOG.md")
        self.version, _ = release_metadata(self.root)
        self.tag = "v" + self.version

    def test_wrong_or_nonstandard_tag_is_rejected(self):
        for tag in (self.version, self.tag + "-beta", "v99.0.0"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release_metadata(self.root, tag)

    def test_inconsistent_core_and_guide_are_rejected(self):
        for name in ("Core.lua", "README.md"):
            path = self.root / "MYCRadar" / name
            original = path.read_text(encoding="utf-8")
            path.write_text(original.replace(self.version, "99.0.0"), encoding="utf-8")
            with self.subTest(file=name), self.assertRaises(ValueError):
                release_metadata(self.root, self.tag)
            path.write_text(original, encoding="utf-8")

    def test_invalid_toc_version_is_rejected(self):
        toc = self.root / "MYCRadar" / "MYCRadar.toc"
        toc.write_text(toc.read_text().replace(self.version, "02.3.0"))
        with self.assertRaises(ValueError):
            release_metadata(self.root)

    def test_missing_or_empty_current_notes_are_rejected(self):
        changelog = self.root / "CHANGELOG.md"
        for content in ("# Changelog\n", "## [99.0.0] - 2026-11-25\n- Old\n",
                        f"## [{self.version}] - 2026-11-25\n\n## [1.0.0] - 2026-11-16\n- Old\n"):
            changelog.write_text(content, encoding="utf-8")
            with self.subTest(content=content), self.assertRaises(ValueError):
                release_metadata(self.root)

    def test_bad_tag_leaves_no_release_assets(self):
        output = self.root / "dist"
        with self.assertRaises(ValueError):
            build_release(output, "v99.0.0", self.root)
        self.assertFalse(output.exists())

    def test_assets_match_installable_source_and_checksum(self):
        output = self.root / "dist"
        archive = build_release(output, self.tag, self.root)
        content = archive.read_bytes()
        self.assertEqual(content, build(self.root))
        self.assertEqual((output / "SHA256SUMS.txt").read_text(),
                         f"{hashlib.sha256(content).hexdigest()}  {archive.name}\n")
        _, notes = release_metadata(self.root, self.tag)
        self.assertEqual((output / "RELEASE_NOTES.md").read_text(), notes)
        with zipfile.ZipFile(io.BytesIO(content)) as package:
            self.assertIsNone(package.testzip())
            self.assertEqual(len(package.namelist()), len(set(package.namelist())))
            for filename in package.namelist():
                self.assertEqual(package.read(filename), (self.root / filename).read_bytes())
        self.assertEqual(build_release(output, self.tag, self.root).read_bytes(), content)


if __name__ == "__main__":
    unittest.main()
