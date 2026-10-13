import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/location_status_and_functions.dart';
import 'package:andi_carpeta/ui/interactive_member_badges.dart';

void main() {
  test('effective badge keys preserve active definitions, order, and limit', () {
    final definitions = [
      FunctionDefinition(
        id: 'inactive',
        name: 'Inactivă',
        iconKey: 'custom-ignored',
        badgeKeys: const ['custom-ignored'],
        colorValue: Colors.grey.value,
        active: false,
      ),
      FunctionDefinition(
        id: 'active',
        name: 'Activă',
        iconKey: 'custom-first',
        badgeKeys: const [
          'custom-first',
          'custom-first',
          'custom-second',
          'custom-third',
          'custom-fourth',
        ],
        colorValue: Colors.blue.value,
      ),
    ];

    expect(
      effectiveBadgeKeysForFunctionIds(
        definitions,
        ['missing', 'inactive', 'active'],
      ),
      ['custom-first', 'custom-second', 'custom-third'],
    );
  });

  testWidgets('badge strips filter blanks and render deduplicated member badges',
      (tester) async {
    final definitions = [
      FunctionDefinition(
        id: 'member',
        name: 'Membru',
        iconKey: 'custom-a',
        badgeKeys: const [
          'custom-a',
          'badge_coordinator',
          'custom-a',
          'custom-b',
        ],
        colorValue: Colors.teal.value,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            badgeStripWidget(
              const ['custom-one', ' ', 'custom-two', 'custom-three', 'custom-four'],
              color: Colors.red,
            ),
            memberBadgeStripWidget(definitions, const ['member']),
          ],
        ),
      ),
    ));

    expect(find.byIcon(Icons.badge_outlined), findsNWidgets(5));
    final redFallback = tester.widget<Icon>(
      find.byIcon(Icons.badge_outlined).first,
    );
    expect(redFallback.color, Colors.red);
    expect(find.byType(Wrap), findsNWidgets(2));
  });
}
