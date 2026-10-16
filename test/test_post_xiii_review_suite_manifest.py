"""Offline post-XIII threat models, no Firebase, native hardware, or credentials.

Run: python3 -m unittest discover -s test -p 'test_post_xiii_*.py' -v
"""
import unittest


class ReviewSuiteManifestTest(unittest.TestCase):
    def test_required_review_models_present(self):
        from pathlib import Path
        root = Path(__file__).resolve().parent
        expected = (
            "test_post_xiii_capability_replay.py",
            "test_post_xiii_backup_rollback.py",
            "test_post_xiii_rollout_matrix.py",
            "test_post_xiii_authority_rotation.py",
            "test_post_xiii_native_path_policy.py",
            "test_post_xiii_no_implicit_restore.py",
            "test_post_xiii_cost_bounds.py",
            "test_post_xiii_marker_integrity.py",
            "test_post_xiii_retention_policy.py",
            "test_post_xiii_key_custody.py",
        )
        self.assertTrue(all((root / name).is_file() for name in expected))


if __name__ == "__main__":
    unittest.main()
