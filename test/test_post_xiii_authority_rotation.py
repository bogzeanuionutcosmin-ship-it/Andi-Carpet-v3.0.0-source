"""Trusted issuer rotation model; not a deployed token service."""
import unittest


class Authority:
    def __init__(self):
        self.epochs = {}

    def rotate(self, uid):
        previous = self.epochs.get(uid, 0)
        if previous >= 9007199254740991:
            return None
        self.epochs[uid] = previous + 1
        return self.epochs[uid]

    def current(self, uid, epoch):
        return type(epoch) is int and epoch > 0 and self.epochs.get(uid) == epoch


class AuthorityRotationTest(unittest.TestCase):
    def test_a_b_a_cannot_resurrect_old_epoch(self):
        authority = Authority()
        a1 = authority.rotate("A")
        authority.rotate("B")
        a2 = authority.rotate("A")
        self.assertFalse(authority.current("A", a1))
        self.assertTrue(authority.current("A", a2))

    def test_epoch_saturation_fails_closed(self):
        authority = Authority()
        authority.epochs["A"] = 9007199254740991
        self.assertIsNone(authority.rotate("A"))
        self.assertEqual(authority.epochs["A"], 9007199254740991)

    def test_missing_and_boolean_epoch_rejected(self):
        authority = Authority()
        authority.rotate("A")
        self.assertFalse(authority.current("A", True))
        self.assertFalse(authority.current("B", 1))


if __name__ == "__main__":
    unittest.main()
