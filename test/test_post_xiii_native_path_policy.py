"""Pure pathname threat model; no real filesystem ACL test."""
from pathlib import PurePosixPath
import unittest


def accept_scope_name(name):
    if type(name) is not str or not name or len(name) > 128:
        return False
    if any(x in name for x in ("/", "\\", "\x00", "..")):
        return False
    return name.isascii() and all(c.isalnum() or c in "-_" for c in name)


class NativePathThreatTest(unittest.TestCase):
    def test_safe_opaque_name(self):
        self.assertTrue(accept_scope_name("journal_abcdef123"))

    def test_traversal_and_separators_denied(self):
        for name in ("../db", "a/b", "a\\b", "..", "a\x00b", ""):
            self.assertFalse(accept_scope_name(name))

    def test_unbounded_and_unicode_names_denied(self):
        self.assertFalse(accept_scope_name("a" * 129))
        self.assertFalse(accept_scope_name("finanțe"))


if __name__ == "__main__":
    unittest.main()
