"""Key-custody acceptance model; not cryptography or OS key storage."""
import unittest


def key_access(device_bound, unlocked, authorized_session, key_revoked):
    return (device_bound is True and unlocked is True
            and authorized_session is True and key_revoked is False)


class KeyCustodyThreatTest(unittest.TestCase):
    def test_all_guards_required(self):
        self.assertTrue(key_access(True, True, True, False))
        for args in ((False, True, True, False), (True, False, True, False),
                     (True, True, False, False), (True, True, True, True)):
            self.assertFalse(key_access(*args))

    def test_truthy_values_do_not_authorize(self):
        self.assertFalse(key_access(1, True, True, False))
        self.assertFalse(key_access(True, "yes", True, False))

    def test_key_revocation_blocks_access(self):
        self.assertFalse(key_access(True, True, True, True))


if __name__ == "__main__":
    unittest.main()
