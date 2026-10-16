"""Offline diagnostics privacy contract model: enum-only output.

The sink never receives source exceptions, identities, money, or operation IDs.
"""
import unittest


ALLOWED = frozenset((
    "finance_operation_uncertain",
    "finance_revision_conflict",
    "finance_write_rejected",
    "session_revoked",
    "journal_unavailable",
))


def safe_signal(status):
    if type(status) is not str or status not in ALLOWED:
        return None
    return status


class DiagnosticSink:
    def __init__(self):
        self.events = []

    def emit(self, status, **private_context):
        event = safe_signal(status)
        if event is None:
            return False
        self.events.append(event)
        return True


class VisionPrivacyContractTest(unittest.TestCase):
    def test_all_allowed_signals_are_anonymous(self):
        sink = DiagnosticSink()
        for status in sorted(ALLOWED):
            self.assertTrue(sink.emit(status, uid="private", amount=999,
                                      operation_id="secret", error="raw error"))
        self.assertEqual(sink.events, sorted(ALLOWED))
        self.assertTrue(all(event in ALLOWED for event in sink.events))

    def test_raw_exception_or_free_text_is_dropped(self):
        sink = DiagnosticSink()
        for item in (Exception("secret"), "uid=private", "999.00", None, True, 1,
                     {"status": "session_revoked"}, "permission_denied"):
            self.assertFalse(sink.emit(item))
        self.assertEqual(sink.events, [])

    def test_private_context_does_not_affect_diagnostic(self):
        a, b = DiagnosticSink(), DiagnosticSink()
        a.emit("finance_operation_uncertain", uid="A", amount="100.00")
        b.emit("finance_operation_uncertain", uid="B", amount="200.00")
        self.assertEqual(a.events, b.events)

    def test_no_unknown_status_is_promoted_to_permission_denial(self):
        sink = DiagnosticSink()
        self.assertFalse(sink.emit("rejectedBeforeWrite", reason="unknown"))
        self.assertEqual(sink.events, [])


if __name__ == "__main__":
    unittest.main()
