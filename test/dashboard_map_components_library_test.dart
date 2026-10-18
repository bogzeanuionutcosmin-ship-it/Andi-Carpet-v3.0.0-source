import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/dashboard_map_components.dart';

void main() {
  testWidgets('stat mini preserves values, icon and dimensions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatMini(
            label: 'Zile',
            value: '4',
            icon: Icons.calendar_view_week,
          ),
        ),
      ),
    );

    expect(find.text('Zile'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_week), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Zile'),
        matching: find.byType(Container),
      ).first,
    );
    expect(container.padding, const EdgeInsets.symmetric(horizontal: 12, vertical: 9));
  });

  testWidgets('map legend keeps status color and label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapStatusLegend(color: Colors.orange, label: 'Urmează / în lucru'),
        ),
      ),
    );

    expect(find.text('Urmează / în lucru'), findsOneWidget);
    final dots = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(MapStatusLegend),
        matching: find.byType(Container),
      ),
    );
    expect(
      dots.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.color == Colors.orange &&
            decoration.shape == BoxShape.circle;
      }),
      isTrue,
    );
  });
}
