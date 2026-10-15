"""MISIUNEA VI boundaries: executable freeze and no new transport dependencies."""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Approved source #38 7a87d1d. This is a security/business freeze, not a
# substitute for widget/emulator tests or for the existing 116 protected hashes.
FROZEN = {'lib/auth/auth_gate.dart': '4a2ed634017507d050f1f7d6b9b2a8a6fb93ab76e1385c15c22afc0174c8d720', 'lib/ui/app_root_theme.dart': 'ae74d21b2efc76ad891ca7995d0264dceeb67bd62a6b10e6721344b25da5a50d', 'lib/home/home_page.dart': '377c30d302bf1d8352f8d14edff1fb424808603859ff1853ba1385bfd3f4adcf', 'lib/home/home_live_location.dart': '47124a8f8b03ffd9cd05063bc7c7807d0f0365f17a70151052efc50ccc474595', 'lib/home/home_push_notifications.dart': '7468d0dd5b5e2ae15a18a79f4d41f74829095a31636261a95a2fd6ddefa3851f', 'lib/home/home_financial_sync.dart': '2499d5b686babbee788c6c0fc6d9d0a89283e447ff35d645ad8b985f37285378', 'lib/expenses/expense_page.dart': 'f6a3976dbe52fa81c1599d78207803c35362c2cba5ece9c68182cb68a8af511d', 'lib/expenses/expense_document_actions.dart': 'c34eb78c9d164f8cd65f0cd08be253e8de173aba6760c67fd45a64cf6c4eb6d1', 'lib/expenses/expense_per_diem_actions.dart': '92c1b9f74e43f1afe46ee16319fbde25ec324cd9282bacf709d81c30e4c6dbf2', 'lib/expenses/expense_settlement_actions.dart': '0348242c2def81ac693ded3e3a64c96b9df701fff2b0895f4e6e2b1b09bc92b8', 'lib/ocr_parser.dart': 'a8b4be8722a6df6cb6f4f0c7cea5ea83d24dce8dd3b2decb3f043514c8c9c9af', 'lib/vision/vision_error_telemetry.dart': 'e813a726842b486bcb2f7e150d2d518a3614073cfa1e564d6149fc3703198245', 'lib/vision/vision_persistence_status.dart': '51fb5dee4121b2f0c00ae3577b2c851c39a1cffb88a3af3c91eb350455ca02d4', 'lib/vision/vision_expense_save_verifier.dart': '7e02c1557a3811276553bd7723e2545d4c86c10533d2ec9730a34c7d57a8029e', 'test/auth_session_acceptance_test.dart': '80fcafaf6715db86d05c26cde64d7fa4893af3f7defb845197041d9e009c2c9f', 'test/auth_session_regression_test.dart': '9f9cb117b513e80317b99128931594054cbd197d3df8f6e1bfbe2559e558953b', 'test/support/security_gate_fixture.dart': '2c47c2d958fef54fe5ec9e27c6f40ca38ce6c2d0e4a894eb46cc43e9949e6390', 'test/support/security_home_fixture.dart': 'f207d5b4763407bb3962baf8d50809fb3fa78a174113bd5eb45a2405781b7e57', 'pubspec.yaml': 'a792bec431260e7ceb1ef3a1fa954c6f3e4d0039b04b5a7a3bf0745c08b2a441', 'android/app/build.gradle.kts': 'd4a84c1ecdda00c84c8bfea61e62b425664d55a30e405c7f3d29ce5c7ba8813c', 'android/app/src/main/AndroidManifest.xml': 'b385dc05c1dcb122b7e982006d10cb61c16698e8578fdf175ccfc739dfe15021'}

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
