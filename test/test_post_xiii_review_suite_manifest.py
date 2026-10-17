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
            "test_post_xiii_epoch_bounds.py",
            "test_post_xiii_batch_atomicity.py",
            "test_post_xiii_crash_phase.py",
            "test_post_xiii_authority_read_gate.py",
            "test_post_xiii_receipt_binding.py",
            "test_post_xiii_power_loss_claims.py",
            "test_post_xiii_sensitive_logging.py",
            "test_post_xiii_native_activation_tripwire.py",
            "test_post_xiii_emulator_transport_tripwire.py",
            "test_post_xiii_production_isolation_tripwire.py",
        )
        self.assertTrue(all((root / name).is_file() for name in expected))


if __name__ == "__main__":
    unittest.main()
