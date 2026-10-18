import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/app_capabilities_view.dart';

void main() {
  testWidgets('capabilities view keeps the daily and platform sections',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppCapabilitiesView()),
    );

    expect(find.text('Operațiuni zilnice și Dashboard'), findsOneWidget);
    expect(find.text('Dashboard-ul arată ziua de lucru, echipele active, progresul pe locații, intervenția curentă, stările de așteptare/refuz/nerealizat și estimarea de final când există suficiente date. Poți porni și opri programul, urmări progresul și vedea rapid ce a rămas de făcut.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Web, Android și iPhone/iPad'),
      400,
    );
    expect(find.text('Web, Android și iPhone/iPad'), findsOneWidget);
  });
}
