"""Three-document commit acceptance model; not a Firestore emulator test."""
import unittest

REQUIRED = frozenset(("summary", "receipt", "permit"))


def valid_batch(documents, current_epoch, claimed_epoch):
    return (type(documents) is dict and frozenset(documents) == REQUIRED
            and all(documents[k] is True for k in REQUIRED)
            and type(current_epoch) is int and current_epoch > 0
            and type(claimed_epoch) is int and claimed_epoch == current_epoch)


class BatchAtomicityTest(unittest.TestCase):
    def test_complete_batch(self):
        self.assertTrue(valid_batch(dict.fromkeys(REQUIRED, True), 4, 4))

    def test_all_incomplete_subsets_denied(self):
        from itertools import combinations
        for size in range(3):
            for subset in combinations(REQUIRED, size):
                self.assertFalse(valid_batch(dict.fromkeys(subset, True), 4, 4))

    def test_stale_claim_denied(self):
        self.assertFalse(valid_batch(dict.fromkeys(REQUIRED, True), 4, 3))

    def test_extra_unexpected_document_denied(self):
        docs = dict.fromkeys(REQUIRED, True)
        docs["legacy"] = True
        self.assertFalse(valid_batch(docs, 4, 4))


if __name__ == "__main__":
    unittest.main()
