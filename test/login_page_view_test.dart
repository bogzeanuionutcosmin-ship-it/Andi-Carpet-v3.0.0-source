import 'package:andi_carpeta/auth/login_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LoginFormControllers controllers;
  setUp(() {
    controllers = LoginFormControllers(email: TextEditingController(),
      password: TextEditingController(), confirmPassword: TextEditingController(),
      name: TextEditingController(), username: TextEditingController(), phone: TextEditingController());
  });
  tearDown(() {
    for (final controller in [controllers.email, controllers.password,
      controllers.confirmPassword, controllers.name, controllers.username, controllers.phone]) {
      controller.dispose();
    }
  });
  Future<void> mount(WidgetTester tester, {bool create = false, bool busy = false,
      Future<void> Function()? submit, Future<void> Function()? reset,
      VoidCallback? toggleMode, VoidCallback? toggleObscure}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: LoginPageView(
      controllers: controllers, backdrop: (child) => child,
      logo: const Text('Injected logo'), installButtons: const Text('Injected install'),
      createMode: create, busy: busy, obscure: true, error: 'Synthetic error',
      onSubmit: submit ?? () async {}, onResetPassword: reset ?? () async {},
      onToggleMode: toggleMode ?? () {}, onToggleObscure: toggleObscure ?? () {},
    )));
  }

  testWidgets('login renders injected content and forwards callbacks without owning controllers', (tester) async {
    var submits = 0, resets = 0, modes = 0, visibility = 0;
    await mount(tester, submit: () async { submits++; }, reset: () async { resets++; },
      toggleMode: () { modes++; }, toggleObscure: () { visibility++; });
    expect(find.text('Injected logo'), findsOneWidget);
    expect(find.text('Injected install'), findsOneWidget);
    expect(find.text('Synthetic error'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'alias');
    expect(controllers.email.text, 'alias');
    await tester.tap(find.text('Intră în cont'));
    await tester.tap(find.text('Am uitat parola'));
    await tester.tap(find.text('Nu am cont · Creează cont'));
    await tester.tap(find.byIcon(Icons.visibility));
    expect([submits, resets, modes, visibility], [1, 1, 1, 1]);
    await tester.pumpWidget(const SizedBox());
    controllers.email.text = 'still owned by caller';
    expect(controllers.email.text, 'still owned by caller');
  });

  testWidgets('create mode keeps six fields, pending text and confirmation submit', (tester) async {
    var submits = 0;
    await mount(tester, create: true, submit: () async { submits++; });
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.text('Contul nou va aștepta aprobarea Administratorului.'), findsOneWidget);
    expect(find.text('Am uitat parola'), findsNothing);
    await tester.showKeyboard(find.byType(TextField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submits, 1);
  });

  testWidgets('busy state preserves disabled buttons and spinner', (tester) async {
    var submits = 0;
    await mount(tester, busy: true, submit: () async { submits++; });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byWidgetPredicate((widget) => widget is FilledButton)).onPressed, isNull);
    for (final button in tester.widgetList<TextButton>(find.byType(TextButton))) {
      expect(button.onPressed, isNull);
    }
    expect(submits, 0);
  });
}
