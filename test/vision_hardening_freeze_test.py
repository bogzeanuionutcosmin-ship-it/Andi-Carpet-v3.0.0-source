"""MISIUNEA VI boundaries: executable freeze and no new transport dependencies."""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Approved source #38 7a87d1d except precisely THREE Home log-only\n# redactions for Issue #47 on the isolated fix branch (old/new SHA documented).\n# This is a security/business freeze, not a
# substitute for widget/emulator tests or for the existing 116 protected hashes.
FROZEN = {'lib/auth/auth_gate.dart': '4a2ed634017507d050f1f7d6b9b2a8a6fb93ab76e1385c15c22afc0174c8d720', 'lib/ui/app_root_theme.dart': 'ae74d21b2efc76ad891ca7995d0264dceeb67bd62a6b10e6721344b25da5a50d', 'lib/home/home_page.dart': '6188a3b7ef72e4ca3cf9d903d9a33173fd2d0f37b33c7e28abae3ff6eaea00a6', 'lib/home/home_live_location.dart': '5c19d853c71cf6eb07c2d3e02e279faa631d728c0a8fcc9ae7e983fc6a9c9695', 'lib/home/home_push_notifications.dart': '1b76637e9e11110eaeb1f5b7d64dc8bec53fa0799c4d1bc3db08d08586d91566', 'lib/home/home_financial_sync.dart': '2499d5b686babbee788c6c0fc6d9d0a89283e447ff35d645ad8b985f37285378', 'lib/expenses/expense_page.dart': '6c948fe71f19246a3c71bd2d2a20ac963bdf0b783f694a14ef81ed73f1ff71d3', 'lib/expenses/expense_document_actions.dart': 'c34eb78c9d164f8cd65f0cd08be253e8de173aba6760c67fd45a64cf6c4eb6d1', 'lib/expenses/expense_per_diem_actions.dart': '92c1b9f74e43f1afe46ee16319fbde25ec324cd9282bacf709d81c30e4c6dbf2', 'lib/expenses/expense_settlement_actions.dart': '13a2dd2aaa9b50ef8172ca1ebc5468bb4cf286b9a454385936ca67f0c017ba33', 'lib/ocr_parser.dart': 'a8b4be8722a6df6cb6f4f0c7cea5ea83d24dce8dd3b2decb3f043514c8c9c9af', 'lib/vision/vision_error_telemetry.dart': 'e813a726842b486bcb2f7e150d2d518a3614073cfa1e564d6149fc3703198245', 'lib/vision/vision_persistence_status.dart': '51fb5dee4121b2f0c00ae3577b2c851c39a1cffb88a3af3c91eb350455ca02d4', 'lib/vision/vision_expense_save_verifier.dart': '7e02c1557a3811276553bd7723e2545d4c86c10533d2ec9730a34c7d57a8029e', 'test/auth_session_acceptance_test.dart': '80fcafaf6715db86d05c26cde64d7fa4893af3f7defb845197041d9e009c2c9f', 'test/auth_session_regression_test.dart': '9f9cb117b513e80317b99128931594054cbd197d3df8f6e1bfbe2559e558953b', 'test/support/security_gate_fixture.dart': '2c47c2d958fef54fe5ec9e27c6f40ca38ce6c2d0e4a894eb46cc43e9949e6390', 'test/support/security_home_fixture.dart': 'f207d5b4763407bb3962baf8d50809fb3fa78a174113bd5eb45a2405781b7e57', 'pubspec.yaml': 'a792bec431260e7ceb1ef3a1fa954c6f3e4d0039b04b5a7a3bf0745c08b2a441', 'android/app/build.gradle.kts': 'd4a84c1ecdda00c84c8bfea61e62b425664d55a30e405c7f3d29ce5c7ba8813c', 'android/app/src/main/AndroidManifest.xml': 'b385dc05c1dcb122b7e982006d10cb61c16698e8578fdf175ccfc739dfe15021'}

class VisionHardeningFreeze(unittest.TestCase):
    def test_business_identity_security_and_platform_freeze(self):
        for path, digest in FROZEN.items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)

    def test_vision_has_no_transport_or_backend_dependencies(self):
        allowed = {'dart:async', 'dart:convert', 'dart:ui',
            'package:flutter/foundation.dart', 'package:flutter/material.dart',
            'package:flutter/services.dart', 'package:flutter/widgets.dart',
            'package:flutter_secure_storage/flutter_secure_storage.dart'}
        for path in (ROOT / 'lib/vision').glob('*.dart'):
            source = path.read_text()
            for uri in re.findall(r"import\s+'([^']+)'", source):
                with self.subTest(path=path.name, uri=uri):
                    self.assertTrue(uri in allowed or re.fullmatch(r'vision_[a-z_]+\.dart', uri))
            for api in ('FirebaseFirestore', 'FirebaseFunctions', 'HttpClient', 'Dio(', 'http.get(', 'http.post('):
                self.assertNotIn(api, source)

    def test_persistence_drain_has_no_timer_or_future_list_queue(self):
        source = (ROOT / 'lib/vision/vision_local_persistence.dart').read_text()
        self.assertNotRegex(source, r'List<Future|Queue<|Timer[.(]|Future\.delayed')
        self.assertNotIn('_lastWrite.then', source)
        self.assertIn('await initialize();', source)
        self.assertIn('_savedSnapshot', source)

    def test_known_red_assertions_and_ci_characterization_are_preserved(self):
        source = (ROOT / 'test/vision_settlement_controller.red.dart').read_text()
        start = source.index("  testWidgets('settlement receipt failure")
        case = source[start:source.rindex('}\n')]
        self.assertEqual(hashlib.sha256(case.encode()).hexdigest(), '8c82ee6e21b75ffe6404716983a702b191a8c3265be30c421aa6070e046d7644')
        workflow = (ROOT / '.github/workflows/verify-vision-modular-android.yml').read_text()
        self.assertIn('flutter test test/vision_settlement_controller.red.dart --reporter expanded', workflow)
        self.assertIn('test "$test_result" -eq 1', workflow)
        self.assertIn('A TextEditingController was used after being disposed.', workflow)
        self.assertNotIn('|| true', workflow)

if __name__ == '__main__':
    unittest.main()
