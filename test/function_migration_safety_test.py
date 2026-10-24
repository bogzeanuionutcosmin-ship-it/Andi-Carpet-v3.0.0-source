from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
class FunctionMigrationSafetyTest(unittest.TestCase):
    def test_login_migration_cannot_delete_or_reassign_roles(self):
        source=(ROOT/'lib/home/home_permission_maintenance.dart').read_text()
        body=source.split('Future<void> _migrateFunctionBadgeSystemIfNeeded()',1)[1]
        self.assertIn('functionBadgeMigrationReady(',body)
        for mutation in ('batch.', '.set(', '.update(', '.delete(', "collection('users')", "collection('functions')"):
            self.assertNotIn(mutation,body)
    def test_permission_recalculation_waits_for_verified_migration(self):
        source=(ROOT/'lib/home/home_permission_maintenance.dart').read_text()
        body=source.split('Future<void> _syncUserPermissionSnapshots()',1)[1].split('Future<void> _seedLocationsIfNeeded()',1)[0]
        self.assertLess(body.index('functionBadgeMigrationReady(db)'),body.index("collection('users')"))
