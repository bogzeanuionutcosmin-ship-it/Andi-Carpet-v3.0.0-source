"""Standalone review acceptance model: restore_version; not production implementation."""
import unittest

def accept_backup(schema_version, checksum_matches):
    return type(schema_version) is int and schema_version == 2 and checksum_matches is True

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertTrue(accept_backup(2,True))
        self.assertFalse(accept_backup(1,True))
        self.assertFalse(accept_backup(2,False))
        self.assertFalse(accept_backup(True,True))

if __name__ == "__main__":
    unittest.main()
