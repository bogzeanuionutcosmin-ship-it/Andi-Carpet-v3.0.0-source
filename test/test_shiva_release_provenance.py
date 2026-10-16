"""Review model: release evidence requires SHA-specific independent provenance."""
import re
import unittest


def valid_ci_provenance(expected_sha, observed_sha, conclusion, independent):
    sha = re.compile(r"^[0-9a-f]{40}$")
    return (type(expected_sha) is str and bool(sha.fullmatch(expected_sha))
            and type(observed_sha) is str and expected_sha == observed_sha
            and conclusion == "success" and independent is True)


class ProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40

    def test_exact_sha_success_required(self):
        self.assertTrue(valid_ci_provenance(self.sha, self.sha, "success", True))

    def test_previous_commit_does_not_prove_current_commit(self):
        self.assertFalse(valid_ci_provenance(self.sha, "b" * 40, "success", True))

    def test_skipped_in_progress_and_failed_not_pass(self):
        for status in ("skipped", "in_progress", "failure", None):
            self.assertFalse(valid_ci_provenance(self.sha, self.sha, status, True))

    def test_self_asserted_or_malformed_sha_is_not_provenance(self):
        self.assertFalse(valid_ci_provenance(self.sha, self.sha, "success", False))
        self.assertFalse(valid_ci_provenance("HEAD", "HEAD", "success", True))
        self.assertFalse(valid_ci_provenance(self.sha, self.sha, "success", 1))


if __name__ == "__main__":
    unittest.main()
