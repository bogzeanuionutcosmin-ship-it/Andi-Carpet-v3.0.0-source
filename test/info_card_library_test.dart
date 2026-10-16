import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/info_card.dart';

void main() {
  testWidgets('renders the supplied accent, title, icon and text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoCard(
            icon: Icons.info_outline,
            title: 'Regulă documente',
            text: 'Generat la cerere',
            accent: Colors.indigo,
          ),
        ),
      ),
    );

    expect(find.text('Regulă documente'), findsOneWidget);
    expect(find.text('Generat la cerere'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
        Colors.indigo.withValues(alpha: .14));
  });
}
