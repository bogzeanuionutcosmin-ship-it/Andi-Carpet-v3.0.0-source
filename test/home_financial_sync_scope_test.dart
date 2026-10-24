import 'package:flutter_test/flutter_test.dart';

import '../lib/home/home_financial_sync_scope.dart';

void main() {
  test('administrators keep the existing global finance scope', () {
    expect(
      homeFinancialSyncScope(
        isAdmin: true,
        canViewOtherDeconts: false,
        teamId: 'team-a',
      ),
      '*',
    );
  });

  test('the existing permission grants the global finance scope', () {
    expect(
      homeFinancialSyncScope(
        isAdmin: false,
        canViewOtherDeconts: true,
        teamId: 'team-a',
      ),
      '*',
    );
  });

  test('members retain their exact team scope, including missing scope', () {
    expect(
      homeFinancialSyncScope(
        isAdmin: false,
        canViewOtherDeconts: false,
        teamId: 'team-a',
      ),
      'team-a',
    );
    expect(
      homeFinancialSyncScope(
        isAdmin: false,
        canViewOtherDeconts: false,
        teamId: null,
      ),
      isNull,
    );
    expect(
      homeFinancialSyncScope(
        isAdmin: false,
        canViewOtherDeconts: false,
        teamId: '',
      ),
      '',
    );
  });

  test('scope restart decision remains exact equality', () {
    expect(shouldRestartHomeFinancialSync('team-a', 'team-a'), isFalse);
    expect(shouldRestartHomeFinancialSync(null, null), isFalse);
    expect(shouldRestartHomeFinancialSync('team-a', 'team-b'), isTrue);
    expect(shouldRestartHomeFinancialSync('team-a', '*'), isTrue);
    expect(shouldRestartHomeFinancialSync(null, ''), isTrue);
  });
}
