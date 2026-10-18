import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';
import 'support/auth_gate_fixture.dart';

void main() {
  testWidgets('transient null auth and profile errors retain an existing profile', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    await mountFixtureGate(tester, h);
    expect(find.text('Se încarcă profilul...'), findsOneWidget);
    expect(h.requestedProfiles, ['a']);
    h.profile('a').add(GateFixtureSnapshot({'name': 'Alice', 'active': false}));
    await flushFixtureGate(tester);
    expect(find.text('Alice\na@example.com'), findsOneWidget);

    h.auth.add(null);
    h.profile('a').addError('synthetic reconnect error');
    await flushFixtureGate(tester);
    expect(find.text('Alice\na@example.com'), findsOneWidget);
    expect(h.requestedProfiles, ['a']);
    expect(find.textContaining('synthetic reconnect error'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
    expect(h.profileCancels['a'], 1);
  });

  testWidgets('UID switch cancels the old profile and renders only the new identity', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    await mountFixtureGate(tester, h);
    h.profile('a').add(GateFixtureSnapshot({'name': 'Alice', 'active': false}));
    await flushFixtureGate(tester);
    h.user = GateFixtureUser('b', 'b@example.com');
    h.auth.add(h.user);
    await flushFixtureGate(tester);
    expect(h.requestedProfiles, ['a', 'b']);
    expect(h.profileCancels['a'], 1);
    h.profile('a').add(GateFixtureSnapshot({'name': 'Stale identity', 'active': false}));
    h.profile('b').add(GateFixtureSnapshot({'name': 'Bob', 'active': false}));
    await flushFixtureGate(tester);
    expect(find.text('Bob\nb@example.com'), findsOneWidget);
    expect(find.textContaining('Stale identity'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(h.profileCancels['b'], 1);
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
  });

  testWidgets('missing profile and UI settings keep their existing behavior and disposal', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    final settings = AppSettings()..brandingBackgroundId = 'none';
    var changed = 0;
    await mountFixtureGate(tester, h, settings: settings, onSettingsChanged: () { changed++; });
    h.profile('a').add(GateFixtureSnapshot(null, exists: false));
    await flushFixtureGate(tester);
    expect(find.text('Contul există în Authentication, dar profilul Firestore lipsește.'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    final update = GateFixtureSnapshot({
      'brandingBackgroundId': 'plain', 'backgroundOpacity': .9,
      'androidDownloadUrl': 'https://example.invalid/synthetic.apk',
    });
    h.settings.add(update);
    await flushFixtureGate(tester);
    expect(changed, 1);
    expect(settings.brandingBackgroundId, 'plain');
    expect(settings.backgroundOpacity, .7);
    expect(settings.androidDownloadUrl, 'https://example.invalid/synthetic.apk');
    h.settings.add(update);
    await flushFixtureGate(tester);
    expect(changed, 1);
    await tester.pumpWidget(const SizedBox());
    h.settings.add(GateFixtureSnapshot({'brandingBackgroundId': 'after-dispose'}));
    await flushFixtureGate(tester);
    expect(changed, 1);
    expect(settings.brandingBackgroundId, 'plain');
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
    expect(h.profileCancels['a'], 1);
  });

  testWidgets('initial profile error is visible and a later snapshot recovers', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    await mountFixtureGate(tester, h);
    h.profile('a').addError('synthetic initial failure');
    await flushFixtureGate(tester);
    expect(find.text('Nu am putut citi profilul: synthetic initial failure'), findsOneWidget);
    h.profile('a').add(GateFixtureSnapshot({'name': 'Recovered', 'active': false}));
    await flushFixtureGate(tester);
    expect(find.text('Recovered\na@example.com'), findsOneWidget);
    expect(find.textContaining('synthetic initial failure'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
