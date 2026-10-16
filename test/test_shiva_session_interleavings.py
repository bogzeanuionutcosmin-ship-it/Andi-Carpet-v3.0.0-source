"""Exhaustive small-state model of revocation versus financial dispatch.

Standalone pure Python test: not a Firebase, device or real network proof.
Enumerates every permutation of three steps, with and without server fencing.
"""
import itertools
import unittest


def simulate(order, *, server_fence):
    epoch = 1
    captured = None
    sent = False
    committed = False
    refused = False
    for action in order:
        if action == "prepare":
            captured = epoch
        elif action == "revoke":
            epoch += 1
        elif action == "send":
            sent = captured is not None
            if not sent:
                refused = True
            elif server_fence and captured != epoch:
                refused = True
            else:
                committed = True
    return {"captured": captured, "epoch": epoch,
            "sent": sent, "committed": committed, "refused": refused}


class SessionInterleavingTest(unittest.TestCase):
    def test_all_six_interleavings_fenced(self):
        permutations = list(itertools.permutations(("prepare", "revoke", "send")))
        self.assertEqual(len(permutations), 6)
        for order in permutations:
            with self.subTest(order=order):
                result = simulate(order, server_fence=True)
                if order.index("prepare") < order.index("revoke") < order.index("send"):
                    self.assertFalse(result["committed"])
                    self.assertTrue(result["refused"])
                if order.index("send") < order.index("prepare"):
                    self.assertFalse(result["committed"])
                if order.index("prepare") < order.index("send") < order.index("revoke"):
                    # Revocation cannot retroactively undo an earlier commit.
                    self.assertTrue(result["committed"])

    def test_local_only_has_real_stale_send_counterexample(self):
        order = ("prepare", "revoke", "send")
        self.assertTrue(simulate(order, server_fence=False)["committed"])
        self.assertFalse(simulate(order, server_fence=True)["committed"])

    def test_no_revocation_permits_prepared_send(self):
        self.assertTrue(simulate(("prepare", "send"), server_fence=True)["committed"])

    def test_revocation_before_prepare_is_new_epoch_not_old_lease(self):
        result = simulate(("revoke", "prepare", "send"), server_fence=True)
        self.assertTrue(result["committed"])
        self.assertEqual(result["captured"], 2)


if __name__ == "__main__":
    unittest.main()
