"""UI artifact regression tests; no GUI interaction or toolkit download required."""
import importlib.util
import io
from pathlib import Path
import plistlib
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load("ui_spike")
prepare = load("prepare_ui_native")


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.storage = tempfile.TemporaryDirectory()
        self.addCleanup(self.storage.cleanup)
        self.root = Path(self.storage.name)
        (self.root / "zig-out/bin").mkdir(parents=True)
        (self.root / "zig-out/bin/ui-spike").write_bytes(b"fixture executable")
        (self.root / "src/ui/spike").mkdir(parents=True)
        (self.root / "src/ui/spike/web.html").write_text("<html>fixture</html>\n")
        self.out = self.root / "zig-out/ui-spike"

    def make_bundle(self, candidate, small=False):
        with patch.object(runner, "ROOT", self.root), patch.object(runner, "OUT", self.out):
            return runner.bundle(candidate, small)

    def test_bundle_launch_identity_and_small_fixture_are_explicit(self):
        large = self.make_bundle("webview")
        small = self.make_bundle("webview", True)
        with (small / "Contents/Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        self.assertEqual(info["ZigideSpikeCandidate"], "webview")
        self.assertTrue(info["ZigideSpikeInputFixture"])
        self.assertNotEqual(large, small)
        self.assertTrue((small / "Contents/Resources/web.html").is_file())

    def test_native_system_bundle_does_not_include_web_surface(self):
        app = self.make_bundle("appkit")
        self.assertFalse((app / "Contents/Resources/web.html").exists())
        self.assertEqual((app / "Contents/MacOS/ui-spike").read_bytes(), b"fixture executable")

    def test_missing_executable_fails_before_bundle_is_claimed(self):
        with patch.object(runner, "ROOT", self.root), patch.object(runner, "OUT", self.out):
            with self.assertRaises(RuntimeError):
                runner.bundle("dvui")


class ExtractionTests(unittest.TestCase):
    def test_escape_and_link_entries_are_rejected(self):
        for name, kind in (("../escape", tarfile.REGTYPE), ("link", tarfile.SYMTYPE)):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as storage:
                root = Path(storage)
                archive = root / "package.tar.gz"
                with tarfile.open(archive, "w:gz") as stream:
                    entry = tarfile.TarInfo(name)
                    entry.type = kind
                    entry.linkname = "../escape"
                    stream.addfile(entry)
                with self.assertRaises(ValueError):
                    prepare.extract_checked(archive, root / "output")
                self.assertFalse((root / "escape").exists())

    def test_contained_regular_file_is_extracted(self):
        with tempfile.TemporaryDirectory() as storage:
            root = Path(storage)
            archive = root / "package.tar.gz"
            with tarfile.open(archive, "w:gz") as stream:
                entry = tarfile.TarInfo("src/file")
                entry.size = 4
                stream.addfile(entry, io.BytesIO(b"test"))
            prepare.extract_checked(archive, root / "output")
            self.assertEqual((root / "output/src/file").read_bytes(), b"test")


if __name__ == "__main__":
    unittest.main()
