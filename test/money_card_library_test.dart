import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/money_card.dart';

void main() {
  testWidgets('formats the existing amount and forwards its tap callback',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoneyCard(
            title: 'Buget rămas',
            value: 1234.5,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Buget rămas'), findsOneWidget);
    expect(find.text('1234.50 lei'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });
}
