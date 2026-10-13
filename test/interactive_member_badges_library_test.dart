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
        ],
        colorValue: Colors.blue.value,
      ),
      FunctionDefinition(
        id: 'also-active',
        name: 'Tot activă',
        iconKey: 'custom-second',
        badgeKeys: const ['custom-second', 'custom-third'],
        colorValue: Colors.green.value,
      ),
    ];

    expect(
      effectiveBadgeKeysForFunctionIds(
        definitions,
        ['missing', 'inactive', 'active', 'also-active'],
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
          'custom-b',
        ],
        colorValue: Colors.teal.value,
      ),
      FunctionDefinition(
        id: 'duplicate',
        name: 'Duplicată',
        iconKey: 'custom-a',
        badgeKeys: const ['custom-a', 'custom-b'],
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
            memberBadgeStripWidget(definitions, const ['member', 'duplicate']),
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
