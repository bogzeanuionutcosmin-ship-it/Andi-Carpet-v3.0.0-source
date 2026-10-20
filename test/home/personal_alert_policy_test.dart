import 'package:andi_carpeta/home/personal_alert_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('personalAlertCategory', () {
    final cases = <(String, String, String)>[
      ('Diurnă', '', 'decont'),
      ('Decont', '', 'decont'),
      ('Cheltuieli', '', 'decont'),
      ('Sosire', '', 'arrival'),
      ('Locație', '', 'arrival'),
      ('Locatie', '', 'arrival'),
      ('', 'GPS', 'arrival'),
      ('Learning', '', 'learning'),
      ('Estimare', '', 'learning'),
      ('Recomandare', '', 'learning'),
      ('Grafic', '', 'schedule'),
      ('Program', '', 'schedule'),
      ('Traseu', '', 'schedule'),
      ('Plan', '', 'schedule'),
      ('Altă alertă', '', 'general'),
    ];

    for (final (title, message, expected) in cases) {
      test('maps "$title$message" to $expected', () {
        expect(personalAlertCategory(title, message), expected);
      });
    }

    test('uses the existing category precedence across title and message', () {
      expect(
        personalAlertCategory('Program și learning', 'GPS decont'),
        'decont',
      );
      expect(
        personalAlertCategory('Program learning', 'Locație'),
        'arrival',
      );
      expect(
        personalAlertCategory('Plan recomandare', ''),
        'learning',
      );
    });
  });

  group('allowsPersonalAlert', () {
    test('uses the selected category preference and defaults missing keys true',
        () {
      expect(
        allowsPersonalAlert(
          title: 'Cheltuieli',
          message: '',
          preferences: const {'decont': false},
        ),
        isFalse,
      );
      expect(
        allowsPersonalAlert(
          title: 'Unknown title',
          message: '',
          preferences: const {'general': false},
        ),
        isFalse,
      );
      expect(
        allowsPersonalAlert(
          title: 'Unknown title',
          message: '',
          preferences: const {},
        ),
        isTrue,
      );
    });

    test('system and admin title bypasses remain trimmed, case-insensitive', () {
      const disabled = {'general': false};
      expect(
        allowsPersonalAlert(
          title: '  SISTEM ',
          message: 'not used for bypass',
          preferences: disabled,
        ),
        isTrue,
      );
      expect(
        allowsPersonalAlert(
          title: '  Admin action required ',
          message: '',
          preferences: disabled,
        ),
        isTrue,
      );
    });

    test('admin in the message alone does not bypass the preference', () {
      expect(
        allowsPersonalAlert(
          title: 'Program update',
          message: 'admin requested this',
          preferences: const {'schedule': false},
        ),
        isFalse,
      );
    });
  });
}
