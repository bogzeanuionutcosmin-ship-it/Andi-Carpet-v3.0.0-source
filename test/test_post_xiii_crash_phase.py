"""Crash outcome uncertainty matrix, independent of SQLite durability claims."""
import unittest


def crash_outcome(phase):
    if phase in ("before_begin", "after_begin", "after_write_before_commit"):
        return "no_send_preserve"
    if phase in ("during_commit", "after_commit_before_ack",
                 "after_commit_before_readback", "during_cleanup"):
        return "uncertain_reconcile_read_only"
    return "quarantine"


class CrashPhaseTest(unittest.TestCase):
    def test_precommit_never_sends(self):
        for phase in ("before_begin", "after_begin", "after_write_before_commit"):
            self.assertEqual(crash_outcome(phase), "no_send_preserve")

    def test_commit_boundary_never_guesses_rollback(self):
        for phase in ("during_commit", "after_commit_before_ack",
                      "after_commit_before_readback", "during_cleanup"):
            self.assertEqual(crash_outcome(phase), "uncertain_reconcile_read_only")

    def test_unrecognized_phase_fails_closed(self):
        self.assertEqual(crash_outcome("unknown"), "quarantine")


if __name__ == "__main__":
    unittest.main()
