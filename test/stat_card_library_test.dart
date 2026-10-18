import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/stat_card.dart';

void main() {
  testWidgets('renders supplied leading widget, accent and existing dimensions',
      (tester) async {
    const accent = Color(0xff315ea8);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            title: 'Progres',
            value: '3 finalizate · 2 rămase',
            accent: accent,
            leading: Icon(Icons.history),
          ),
        ),
      ),
    );

    expect(find.text('Progres'), findsOneWidget);
    expect(find.text('3 finalizate · 2 rămase'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(tester.widget<SizedBox>(find.byType(SizedBox).first).width, 230);
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(decoration.gradient!.colors.first, accent.withValues(alpha: .16));
    expect(container.padding, const EdgeInsets.all(18));
  });
}
