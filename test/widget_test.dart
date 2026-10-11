import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/main.dart';

void main() {
  test('formatarea datei folosește anul și luna corecte', () {
    final value = formatDate(DateTime(2026, 10, 5));
    expect(value, contains('2026'));
    expect(value, contains('octombrie'));
  });

  test('formatarea datei păstrează anul la schimbarea lunii', () {
    final decembrie = formatDate(DateTime(2025, 12, 31));
    final ianuarie = formatDate(DateTime(2026, 1, 1));
    expect(decembrie, contains('2025'));
    expect(ianuarie, contains('2026'));
    expect(decembrie, isNot(equals(ianuarie)));
  });

  test('formatarea lunilor ianuarie și februarie este distinctă', () {
    final ianuarie = formatDate(DateTime(2026, 1, 15));
    final februarie = formatDate(DateTime(2026, 2, 15));
    expect(ianuarie, contains('ianuarie'));
    expect(februarie, contains('februarie'));
    expect(ianuarie, isNot(equals(februarie)));
  });

  test('funcțiile implicite au identificatori unici și drepturi definite', () {
    final defs = defaultFunctionDefinitions();
    expect(defs, isNotEmpty);
    expect(defs.map((e) => e.id).toSet().length, defs.length);
    expect(defs.firstWhere((e) => e.id == 'admin').permissions, isNotEmpty);
    expect(defs.any((e) => e.id == 'worker'), isFalse);
  });
  test('identificatorii de funcții nu sunt goi', () {
    final defs = defaultFunctionDefinitions();
    expect(defs.every((e) => e.id.trim().isNotEmpty), isTrue);
  });

  test('fiecare funcție are o listă de permisiuni', () {
    final defs = defaultFunctionDefinitions();
    expect(defs.every((e) => e.permissions is List), isTrue);
  });

  test('formatarea datei funcționează pentru anul bisect', () {
    final value = formatDate(DateTime(2024, 2, 29));
    expect(value, contains('2024'));
    expect(value, contains('februarie'));
  });

  test('funcțiile implicite au permisiuni fără duplicate', () {
    final defs = defaultFunctionDefinitions();
    for (final definition in defs) {
      final permissions = definition.permissions;
      expect(permissions.toSet().length, permissions.length,
          reason: 'Permisiuni duplicate pentru ${definition.id}');
    }
  });

  test('formatDate diferențiază prima și ultima zi a lunii', () {
    final first = formatDate(DateTime(2026, 10, 1));
    final last = formatDate(DateTime(2026, 10, 31));
    expect(first, isNot(equals(last)));
    expect(first, contains('octombrie'));
    expect(last, contains('octombrie'));
  });

  group('Date calendaristice', () {
    for (final month in <int>[1, 3, 5, 7, 8, 10, 12]) {
      test('luna $month cu 31 de zile', () {
        final first = formatDate(DateTime(2026, month, 1));
        final last = formatDate(DateTime(2026, month, 31));
        expect(first, isNot(equals(last)));
        expect(first, contains('2026'));
        expect(last, contains('2026'));
      });
    }
    for (final month in <int>[4, 6, 9, 11]) {
      test('luna $month cu 30 de zile', () {
        final first = formatDate(DateTime(2026, month, 1));
        final last = formatDate(DateTime(2026, month, 30));
        expect(first, isNot(equals(last)));
        expect(first, contains('2026'));
        expect(last, contains('2026'));
      });
    }
    test('februarie nebisect', () {
      final first = formatDate(DateTime(2026, 2, 1));
      final last = formatDate(DateTime(2026, 2, 28));
      expect(first, isNot(equals(last)));
    });
    test('februarie bisect', () {
      final first = formatDate(DateTime(2024, 2, 1));
      final last = formatDate(DateTime(2024, 2, 29));
      expect(first, isNot(equals(last)));
    });
  });

  group('Integritatea funcțiilor și permisiunilor', () {
    test('nu există permisiuni goale', () {
      for (final definition in defaultFunctionDefinitions()) {
        expect(
          definition.permissions.every((permission) => permission.trim().isNotEmpty),
          isTrue,
          reason: 'Permisiune goală în ${definition.id}',
        );
      }
    });

    test('identificatorii sunt deja normalizați', () {
      for (final definition in defaultFunctionDefinitions()) {
        expect(definition.id, definition.id.trim());
      }
    });

    test('definițiile implicite sunt deterministe', () {
      final first = defaultFunctionDefinitions();
      final second = defaultFunctionDefinitions();
      expect(first.map((e) => e.id).toList(),
          second.map((e) => e.id).toList());
      for (var i = 0; i < first.length; i++) {
        expect(first[i].permissions, orderedEquals(second[i].permissions));
      }
    });

    test('funcția admin este definită exact o dată', () {
      final admins = defaultFunctionDefinitions()
          .where((definition) => definition.id == 'admin');
      expect(admins.length, 1);
    });
  });

}
