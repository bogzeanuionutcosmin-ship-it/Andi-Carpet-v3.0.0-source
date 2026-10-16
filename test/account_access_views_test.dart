import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/auth/account_access_views.dart';

void main() {
  testWidgets('pending approval view renders injected content and forwards sign-out',
      (tester) async {
    var signOutCalls = 0;
    const backdropKey = ValueKey('account-backdrop');

    await tester.pumpWidget(
      MaterialApp(
        home: PendingApprovalView(
          profileName: 'Ana Pop',
          email: 'ana@example.com',
          logo: const Text('Brand logo'),
          backdropBuilder: (child) => ColoredBox(
            key: backdropKey,
            color: Colors.blue,
            child: child,
          ),
          onSignOut: () => signOutCalls++,
        ),
      ),
    );

    expect(find.byKey(backdropKey), findsOneWidget);
    expect(find.text('Brand logo'), findsOneWidget);
    expect(find.text('Cont în așteptare'), findsOneWidget);
    expect(find.text('Ana Pop\nana@example.com'), findsOneWidget);
    await tester.tap(find.text('Ieși din cont'));
    expect(signOutCalls, 1);
  });

  testWidgets('missing profile view shows email when present and forwards sign-out',
      (tester) async {
    var signOutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MissingProfileView(
          email: 'ana@example.com',
          onSignOut: () => signOutCalls++,
        ),
      ),
    );

    expect(find.text('Contul există în Authentication, dar profilul Firestore lipsește.'),
        findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    await tester.tap(find.text('Ieși din cont'));
    expect(signOutCalls, 1);
  });
}
