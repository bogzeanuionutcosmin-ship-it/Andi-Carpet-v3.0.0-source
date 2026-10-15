"""Protect the read-only adapter from global diagnostics or UID-only bypasses."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "lib/vision/vision_scoped_diagnostics_page.dart"
LEASE = ROOT / "lib/vision/vision_session_journal.dart"
EXISTING = ROOT / "lib/vision/vision_diagnostics_page.dart"


class VisionScopedDiagnosticsAdapterContract(unittest.TestCase):
    def setUp(self):
        self.adapter = ADAPTER.read_text(encoding="utf-8")
        self.lease = LEASE.read_text(encoding="utf-8")
        self.executable = "\n".join(
            line for line in self.adapter.splitlines()
            if not line.lstrip().startswith("//")
        )

    def test_adapter_depends_only_on_existing_page_and_lease(self):
        imports = [
            line.strip() for line in self.adapter.splitlines()
            if line.strip().startswith("import ")
        ]
        self.assertEqual(imports, [
            "import 'package:flutter/material.dart';",
            "import 'vision_diagnostics_page.dart';",
            "import 'vision_session_journal.dart';",
        ])
        self.assertIn("final VisionSessionJournalLease lease;", self.adapter)

    def test_adapter_must_pass_owner_check_into_existing_fail_closed_page(self):
        self.assertIn("final snapshot = widget.lease.snapshotForDisplay();", self.executable)
        self.assertIn("log: snapshot,", self.executable)
        self.assertIn("isSessionCurrent: () => widget.lease.isCurrent,", self.executable)
        self.assertIn("identical(widget.log, VisionErrorTelemetry.log)",
                      EXISTING.read_text(encoding="utf-8"))

    def test_no_navigation_backend_or_global_journal_added(self):
        for forbidden in (
            "FirebaseAuth", "FirebaseFirestore", "VisionErrorTelemetry.",
            "Navigator.", "http.get", "http.post", "Clipboard.",
            "Timer(", "Future.delayed(", "SharedPreferences",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.executable)

    def test_detached_projection_rechecks_live_lease(self):
        self.assertIn("VisionErrorLog? snapshotForDisplay()", self.lease)
        self.assertIn("final current = _journal._read(_key, _verify);", self.lease)
        self.assertIn("snapshot.restore(current.encode());", self.lease)
        self.assertIn("if (!isCurrent) return null;", self.lease)
        self.assertIn("final key = Object();", self.lease)
        self.assertIn("if (identical(_currentKey, key)) revoke();", self.lease)

    def test_revocation_rebuilds_and_disposes_subscriptions(self):
        self.assertIn("class VisionScopedDiagnosticsPage extends StatefulWidget",
                      self.adapter)
        for fragment in (
            "_unsubscribe = widget.lease.listenRevocation(_onLeaseRevoked);",
            "if (!identical(oldWidget.lease, widget.lease))",
            "_unsubscribe?.call();",
            "WidgetsBinding.instance.addPostFrameCallback",
            "WidgetsBinding.instance.scheduleFrame();",
            "if (mounted) setState(() {});",
            "void dispose()",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.adapter)

    def test_revocation_is_per_epoch_and_notifies_after_memory_clear(self):
        self.assertIn("final previousKey = _currentKey;", self.lease)
        self.assertIn("_activeLog = null;", self.lease)
        self.assertIn("_revocationListeners.remove(previousKey)", self.lease)
        self.assertIn("for (final listener in listeners.toList(growable: false))",
                      self.lease)
        self.assertIn("if (!_owns(key, verify)) return () {};", self.lease)
        self.assertIn("revoke();\n    final key = Object();", self.lease)


if __name__ == "__main__":
    unittest.main()
