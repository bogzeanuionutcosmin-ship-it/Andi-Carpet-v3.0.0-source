"""Receipt, summary and permit must bind the same immutable operation."""
import unittest


def triple_matches(summary, receipt, permit):
    fields = ("uid", "team", "operation", "digest", "epoch")
    if not all(type(doc) is dict for doc in (summary, receipt, permit)):
        return False
    if not all(all(key in doc for key in fields) for doc in (summary, receipt, permit)):
        return False
    return all(summary[k] == receipt[k] == permit[k] for k in fields)


class ReceiptBindingTest(unittest.TestCase):
    def setUp(self):
        self.doc = dict(uid="A", team="T", operation="op", digest="hash", epoch=2)

    def test_exact_triple_matches(self):
        self.assertTrue(triple_matches(self.doc, self.doc.copy(), self.doc.copy()))

    def test_each_field_conflict_denied(self):
        for key in self.doc:
            altered = self.doc.copy()
            altered[key] = "different"
            self.assertFalse(triple_matches(self.doc, altered, self.doc))

    def test_missing_permit_denied(self):
        self.assertFalse(triple_matches(self.doc, self.doc, None))


if __name__ == "__main__":
    unittest.main()
