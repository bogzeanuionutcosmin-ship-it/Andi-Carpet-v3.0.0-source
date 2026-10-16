"""Guard optional Finance/Vision integration against accidental transport/retry.

Static assertions supplement but do not replace the genuine Dart/SDK tests.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / 'lib/integration/finance_vision_observed_coordinator.dart'
OBSERVER = ROOT / 'lib/integration/finance_vision_outcome_observer.dart'


class FinanceVisionObservedCoordinatorContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bridge = BRIDGE.read_text(encoding='utf-8')
        cls.observer = OBSERVER.read_text(encoding='utf-8')
        cls.active = '\n'.join(
            line for line in cls.bridge.splitlines()
            if not line.lstrip().startswith(('//', '///'))
        )

    def test_no_sdk_or_transport_import(self):
        imports = re.findall(r"^import '([^']+)';$", self.bridge, re.M)
        self.assertEqual(imports, [
            '../finance/intents/finance_coordinator.dart',
            '../finance/intents/finance_intent.dart',
            '../vision/vision_scoped_signal_sink.dart',
            'finance_vision_outcome_observer.dart',
        ])

    def test_financial_outcome_not_mutated_or_retried(self):
        self.assertEqual(self.active.count('coordinator.executeExplicitly(intent)'), 1)
        self.assertEqual(self.active.count('coordinator.reconcileExplicitly(intent)'), 1)
        self.assertNotIn('FinanceIntent.newOperationId(', self.active)
        for forbidden in ('FirebaseFirestore', 'FirebaseAuth',
                          'http.get', 'http.post', 'Timer(',
                          'VisionErrorTelemetry.', 'deleteAll('):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.active)

    def test_journal_checked_before_execute_and_fail_closed(self):
        self.assertIn('pending = await coordinator.journal.pending()', self.active)
        self.assertIn('finance_existing_intent_requires_reconciliation', self.active)
        self.assertIn('finance_pending_journal_unavailable', self.active)
        self.assertIn('finance_unresolved_target', self.active)

    def test_single_flight_covers_execute_and_reconcile(self):
        self.assertIn('final Map<String, _FinanceVisionFlight> _flights', self.active)
        self.assertIn('active.reconciliation == reconciliation', self.active)
        self.assertIn('finance_operation_still_in_flight', self.active)
        self.assertIn('return active.future;', self.active)
        self.assertIn('_flights.remove(path);', self.active)
        self.assertIn('onError: (Object _, StackTrace __) => clear()', self.active)

    def test_isolate_guard_does_not_share_auth_scoped_futures(self):
        self.assertIn('static final Map<(String, String), Object> '
                      '_isolateTargetOwners', self.active)
        self.assertIn('coordinator.repository.ownerUid, path', self.active)
        self.assertIn('finance_operation_in_another_scope', self.active)
        self.assertIn('identical(_isolateTargetOwners[ownerKey], lease)',
                      self.active)
        self.assertIn('_isolateTargetOwners.remove(ownerKey);', self.active)
        self.assertNotIn('SharedPreferences', self.active)
        self.assertNotIn('FlutterSecureStorage', self.active)

    def test_stale_wrapper_is_monotonically_denied(self):
        self.assertIn('bool _open = true;', self.active)
        self.assertIn('void dispose()', self.active)
        self.assertIn('_open = false;', self.active)
        self.assertIn('coordinator.repository.sessionIsCurrent()', self.active)
        self.assertIn('coordinator.journal.sessionIsCurrent()', self.active)
        self.assertIn('if (!_ownsSession())', self.active)
        self.assertIn("FinanceIntentStatus.uncertain, 'finance_session_expired'",
                      self.active)

    def test_unexpected_coordinator_errors_fail_closed_without_raw_logging(self):
        self.assertIn('finance_unclassified_result', self.active)
        self.assertIn('journalPending: true,', self.active)
        self.assertIn('_observe(_unclassified);', self.active)
        self.assertNotIn('catch (error)', self.active)
        self.assertNotIn('catch (exception)', self.active)
        self.assertNotIn('toString()', self.active)

    def test_signals_remain_only_anonymous_status(self):
        self.assertIn('result: result.result,', self.bridge)
        self.assertIn('VisionDiagnosticSignal.financeOperationUncertain', self.observer)
        self.assertIn('VisionDiagnosticSignal.financeRevisionConflict', self.observer)
        for forbidden in ('intent.operationId', 'intent.actorUid',
                          'intent.changes', 'intent.teamId',
                          'error.toString()', 'exception.toString()'):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.observer)


if __name__ == '__main__':
    unittest.main()
