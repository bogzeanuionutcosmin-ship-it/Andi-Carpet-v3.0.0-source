import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/auth_status_views.dart';

void main() {
  testWidgets('loading view renders the injected logo and message',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FirebaseLoadingView(
          text: 'Se verifică autentificarea...',
          logo: Text('Brand logo'),
        ),
      ),
    );

    expect(find.text('Brand logo'), findsOneWidget);
    expect(find.text('Se verifică autentificarea...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error view forwards sign-out callback', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FirebaseErrorView(
          message: 'Profilul nu a putut fi încărcat.',
          onSignOut: () => signOutCalls++,
        ),
      ),
    );

    expect(find.text('Profilul nu a putut fi încărcat.'), findsOneWidget);
    expect(find.text('Ieși din cont'), findsOneWidget);
    await tester.tap(find.text('Ieși din cont'));
    expect(signOutCalls, 1);
  });
}
