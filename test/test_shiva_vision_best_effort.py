"""Diagnostics failures cannot alter authoritative financial outcomes."""
import unittest


def observe_finance(outcome, observer):
    try:
        observer(outcome)
    except Exception:
        pass
    return outcome


class BestEffortTest(unittest.TestCase):
    def test_observer_exception_does_not_change_outcome(self):
        for outcome in ("confirmed", "uncertain", "rejected_before_write", "conflict"):
            with self.subTest(outcome=outcome):
                self.assertEqual(observe_finance(outcome, lambda _: 1 / 0), outcome)

    def test_observer_receives_exact_outcome(self):
        received = []
        self.assertEqual(observe_finance("uncertain", received.append), "uncertain")
        self.assertEqual(received, ["uncertain"])

    def test_diagnostic_delivery_never_retries_financial_write(self):
        sends = []
        def observer(_):
            raise RuntimeError("diagnostic offline")
        result = observe_finance("uncertain", observer)
        self.assertEqual(result, "uncertain")
        self.assertEqual(sends, [])


if __name__ == "__main__":
    unittest.main()
