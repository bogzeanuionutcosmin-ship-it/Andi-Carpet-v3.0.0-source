"""Canonical operation identity review model; no production serialization."""
import hashlib
import json
import unittest


def digest(uid, team, operation_id, kind, amount_minor):
    if not all(type(v) is str and v for v in (uid, team, operation_id, kind)):
        return None
    if type(amount_minor) is not int:
        return None
    data = [2, uid, team, operation_id, kind, amount_minor]
    return hashlib.sha256(json.dumps(data, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()


class IdentityTest(unittest.TestCase):
    def test_identical_operation_has_stable_digest(self):
        a = digest("A", "T1", "op1", "advance", 101)
        self.assertEqual(a, digest("A", "T1", "op1", "advance", 101))
        self.assertEqual(len(a), 64)

    def test_each_authority_field_changes_identity(self):
        base = digest("A", "T1", "op1", "advance", 101)
        for args in (("B", "T1", "op1", "advance", 101),
                     ("A", "T2", "op1", "advance", 101),
                     ("A", "T1", "op2", "advance", 101),
                     ("A", "T1", "op1", "settlement", 101),
                     ("A", "T1", "op1", "advance", 102)):
            self.assertNotEqual(base, digest(*args))

    def test_malformed_fields_are_rejected(self):
        self.assertIsNone(digest("", "T1", "op1", "advance", 1))
        self.assertIsNone(digest("A", "T1", "op1", "advance", 1.0))
        self.assertIsNone(digest("A", "T1", "op1", "advance", True))


if __name__ == "__main__":
    unittest.main()
