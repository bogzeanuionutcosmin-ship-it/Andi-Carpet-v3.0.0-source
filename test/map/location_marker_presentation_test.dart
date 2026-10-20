import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/map/location_marker_presentation.dart';

void main() {
  testWidgets('preserves marker shape, icon, color, and disabled opacity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: LocationMapMarker(
            color: Colors.blue,
            icon: Icons.store,
            opacity: .62,
            workBadgeColor: null,
          ),
        ),
      ),
    );

    final markerFinder = find.byType(LocationMapMarker);
    final stack = tester.widget<Stack>(find.descendant(
      of: markerFinder,
      matching: find.byType(Stack),
    ));
    expect(stack.clipBehavior, Clip.none);
    expect(stack.alignment, Alignment.center);
    expect(stack.children, hasLength(1));

    final opacityFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(Opacity),
    );
    expect(opacityFinder, findsOneWidget);
    final opacity = tester.widget<Opacity>(opacityFinder);
    expect(opacity.opacity, .62);

    final markerBoxFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(DecoratedBox),
    );
    expect(markerBoxFinder, findsOneWidget);
    final markerBox = tester.widget<DecoratedBox>(markerBoxFinder);
    final markerDecoration = markerBox.decoration as BoxDecoration;
    expect(markerDecoration.color, Colors.blue);
    expect(markerDecoration.shape, BoxShape.circle);
    expect((markerDecoration.border as Border).top.width, 3);
    expect(markerDecoration.boxShadow, hasLength(1));
    expect(markerDecoration.boxShadow!.single.blurRadius, 5);
    expect(markerDecoration.boxShadow!.single.color, Colors.black26);

    final markerSizeFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(SizedBox),
    );
    expect(markerSizeFinder, findsOneWidget);
    final markerSize = tester.widget<SizedBox>(markerSizeFinder);
    expect(markerSize.width, 40);
    expect(markerSize.height, 40);

    final iconFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(Icon),
    );
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(iconFinder);
    expect(icon.icon, Icons.store);
    expect(icon.color, Colors.white);
    expect(
      find.descendant(of: markerFinder, matching: find.byType(Positioned)),
      findsNothing,
    );
  });

  testWidgets('renders the work badge at the existing size and offset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: LocationMapMarker(
            color: Colors.teal,
            icon: Icons.location_on,
            opacity: 1,
            workBadgeColor: Colors.orange,
          ),
        ),
      ),
    );

    final markerFinder = find.byType(LocationMapMarker);
    final stackFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(Stack),
    );
    expect(stackFinder, findsOneWidget);
    final stack = tester.widget<Stack>(stackFinder);
    expect(stack.children, hasLength(2));

    final positionedFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(Positioned),
    );
    expect(positionedFinder, findsOneWidget);
    final positioned = tester.widget<Positioned>(positionedFinder);
    expect(positioned.right, -2);
    expect(positioned.bottom, -2);

    final badgeFinder = find.descendant(
      of: markerFinder,
      matching: find.byType(Container),
    );
    expect(badgeFinder, findsOneWidget);
    final badge = tester.widget<Container>(badgeFinder);
    expect(tester.getSize(badgeFinder), const Size(15, 15));
    final decoration = badge.decoration as BoxDecoration;
    expect(decoration.color, Colors.orange);
    expect(decoration.shape, BoxShape.circle);
    expect((decoration.border as Border).top.width, 2);
  });
}
