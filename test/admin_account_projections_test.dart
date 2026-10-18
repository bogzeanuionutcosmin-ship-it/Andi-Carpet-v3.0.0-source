import 'package:andi_carpeta/admin/admin_account_projections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending display ordering retains exact legacy comparator across missing and mixed values', () {
    final rows = <Map<String, dynamic>>[
      {}, {'name': ''}, {'email': 'beta'}, {'name': 'Alpha'},
      {'name': 'alpha'}, {'name': ' Alpha'}, {'name': 7},
      {'status': 'pending', 'active': true, 'name': 'Zulu'},
      {'status': 'approved', 'active': false, 'name': 'Alpha'},
      {'status': 'PENDING', 'name': 'Beta'},
    ];
    for (final a in rows) {
      for (final b in rows) {
        final ap = (a['status'] ?? '').toString() == 'pending';
        final bp = (b['status'] ?? '').toString() == 'pending';
        final original = ap != bp ? (ap ? -1 : 1)
            : (a['name'] ?? a['email'] ?? '').toString()
                .compareTo((b['name'] ?? b['email'] ?? '').toString());
        expect(compareAdminAccountData(a, b), original);
      }
    }
    expect(compareAdminAccountData({'status': 'pending'}, {'name': ''}), -1);
    expect(compareAdminAccountData({'name': 'Same'}, {'name': 'Same'}), 0);
    expect(rows[7]['active'], isTrue);
  });

  test('assignment projection keeps list precedence, legacy fallback and unnormalized IDs without aliasing', () {
    final cases = <Map<String, dynamic>>[
      {}, {'function': 'developer'}, {'function': 'admin', 'functionIds': []},
      {'function': 'admin', 'functionIds': ['', 'driver', 'driver', ' ', null, 12]},
      {'function': 'director', 'functionIds': 'invalid'},
    ];
    final expected = <Set<String>>[{}, {'developer'}, {}, {'driver', ' ', 'null', '12'}, {'director'}];
    for (var i = 0; i < cases.length; i++) {
      final result = adminAssignedFunctionIds(cases[i]);
      expect(result, expected[i]);
      result.clear();
      expect(adminAssignedFunctionIds(cases[i]), expected[i]);
    }
    expect(cases[3]['functionIds'], ['', 'driver', 'driver', ' ', null, 12]);
  });
}
