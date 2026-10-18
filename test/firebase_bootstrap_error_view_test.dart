import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/bootstrap/firebase_bootstrap_error_app.dart';

void main() {
  testWidgets('preserves platform guidance and displays the bootstrap error',
      (tester) async {
    await tester.pumpWidget(
      const FirebaseBootstrapErrorView(
        message: 'FirebaseOptions is missing.',
      ),
    );

    expect(
      find.text('Firebase nu este configurat pentru această platformă'),
      findsOneWidget,
    );
    expect(find.textContaining('GoogleService-Info.plist'), findsOneWidget);
    expect(find.textContaining('FIREBASE_IOS_API_KEY'), findsOneWidget);
    expect(find.text('FirebaseOptions is missing.'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
