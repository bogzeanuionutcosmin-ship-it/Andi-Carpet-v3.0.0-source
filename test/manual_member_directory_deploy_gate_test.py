from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ManualProductionGate(unittest.TestCase):
    def test_historical_restore_is_manual_main_and_exact_sha_only(self):
        workflow=(ROOT/'.github/workflows/restore-member-directory.yml').read_text()
        triggers=workflow[workflow.index('on:\n'):workflow.index('permissions:\n')]
        self.assertIn('  workflow_dispatch:',triggers)
        self.assertNotRegex(triggers,r'(?m)^  (push|pull_request|workflow_run|schedule):')
        self.assertEqual(triggers.count('required: true'),2)
        self.assertIn("if: github.ref == 'refs/heads/main' && inputs.confirmation == 'DEPLOY_MEMBER_DIRECTORY' && inputs.approved_sha == github.sha",workflow)
        # Preserve historical operations; only the automatic trigger is removed.
        self.assertIn('firebase deploy --only firestore:rules',workflow)
        self.assertIn('firebase deploy --only functions:syncMemberDirectory',workflow)
        self.assertIn('node functions/backfill_member_directory.js',workflow)
