import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/empty_state.dart';

void main() {
  testWidgets('renders the existing empty card content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.inbox_outlined, text: 'No results'),
        ),
      ),
    );

    expect(find.byType(Card), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('No results'), findsOneWidget);
    expect(find.byType(Padding), findsWidgets);
  });
}
