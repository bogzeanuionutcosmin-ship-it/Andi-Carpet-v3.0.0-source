import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';

// Former defect probes now require isolation; the RED acceptance suites remain unchanged.
class _ActivePageProbe extends StatefulWidget {
  final FirebaseUserProfile profile;
  final List<String> lifecycle;
  const _ActivePageProbe({required super.key, required this.profile, required this.lifecycle});
  @override
  State<_ActivePageProbe> createState() => _ActivePageProbeState();
}

class _ActivePageProbeState extends State<_ActivePageProbe> {
  int selectedTab = 0;
  @override
  void initState() { super.initState(); widget.lifecycle.add('mount:${widget.profile.uid}'); }
  @override
  void dispose() { widget.lifecycle.add('dispose:${widget.profile.uid}'); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: Column(children: [
    Text('identity:${widget.profile.uid}:tab:$selectedTab'),
    TextButton(onPressed: () => setState(() => selectedTab = 2), child: const Text('Select tab')),
    TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Text('route:${widget.profile.uid}')))),
      child: const Text('Open route')),
  ]));
}

void main() {
  testWidgets('pending identity A disappears before B snapshot and after B error', (tester) async {
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
    expect(find.text('Alice\na@example.com'), findsNothing,
        reason: 'Old identity must disappear during the UID transition');
    h.profile('b').addError('synthetic B permission error');
    h.settings.add(GateFixtureSnapshot({'androidDownloadUrl': 'synthetic-update'}));
    await flushFixtureGate(tester);
    expect(find.text('Alice\na@example.com'), findsNothing);
    expect(find.textContaining('synthetic B permission error'), findsOneWidget);
    h.profile('a').add(GateFixtureSnapshot({'name': 'Late Alice', 'active': false}));
    await flushFixtureGate(tester);
    expect(find.textContaining('Late Alice'), findsNothing);
    h.profile('b').add(GateFixtureSnapshot({'name': 'Bob', 'active': false}));
    await flushFixtureGate(tester);
    expect(find.text('Bob\nb@example.com'), findsOneWidget);
    expect(find.text('Alice\na@example.com'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('active page disposes before the new identity profile', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    final lifecycle = <String>[];
    await mountFixtureGate(tester, h, activePageBuilder: (key, profile) =>
        _ActivePageProbe(key: key, profile: profile, lifecycle: lifecycle));
    h.profile('a').add(GateFixtureSnapshot({'name': 'Alice', 'active': true}));
    await flushFixtureGate(tester);
    await tester.tap(find.text('Select tab'));
    await tester.pump();
    h.user = GateFixtureUser('b', 'b@example.com');
    h.auth.add(h.user);
    await flushFixtureGate(tester);
    expect(find.text('identity:a:tab:2'), findsNothing);
    expect(lifecycle, ['mount:a', 'dispose:a']);
    h.profile('b').addError('synthetic offline');
    h.auth.add(null); // currentUser B fallback must not resubscribe.
    await flushFixtureGate(tester);
    expect(h.requestedProfiles, ['a', 'b']);
    expect(lifecycle, ['mount:a', 'dispose:a']);
    h.profile('b').add(GateFixtureSnapshot({'name': 'Bob', 'active': true}));
    await flushFixtureGate(tester);
    expect(find.text('identity:b:tab:0'), findsOneWidget);
    expect(lifecycle, ['mount:a', 'dispose:a', 'mount:b']);
    await tester.pumpWidget(const SizedBox());
    expect(lifecycle.last, 'dispose:b');
  });

  testWidgets('root removes a route pushed by A before the new B page', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    final lifecycle = <String>[];
    await tester.pumpWidget(AndiCarpetaApp(authSources: h.sources,
      settings: AppSettings()..brandingBackgroundId = 'none',
      homeBuilder: (key, profile, current) =>
        _ActivePageProbe(key: key, profile: profile, lifecycle: lifecycle)));
    await flushFixtureGate(tester);
    h.profile('a').add(GateFixtureSnapshot({'active': true}));
    await flushFixtureGate(tester);
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
    h.user = GateFixtureUser('b', 'b@example.com');
    h.auth.add(h.user);
    h.profile('b');
    await flushFixtureGate(tester);
    h.profile('b').add(GateFixtureSnapshot({'active': true}));
    await flushFixtureGate(tester);
    expect(find.text('route:a'), findsNothing);
    expect(lifecycle, contains('mount:b'));
    expect(find.text('identity:b:tab:0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid A B C switching ignores late old profiles and cancels each subscription', (tester) async {
    final h = GateFixture();
    addTearDown(h.close);
    await mountFixtureGate(tester, h);
    h.profile('a').add(GateFixtureSnapshot({'name': 'Alice', 'active': false}));
    await flushFixtureGate(tester);
    for (final uid in ['b', 'c']) {
      h.user = GateFixtureUser(uid, '$uid@example.com');
      h.auth.add(h.user);
      await flushFixtureGate(tester);
    }
    h.profile('a').add(GateFixtureSnapshot({'name': 'Late A', 'active': false}));
    h.profile('b').add(GateFixtureSnapshot({'name': 'Late B', 'active': false}));
    h.profile('c').add(GateFixtureSnapshot({'name': 'Carol', 'active': false}));
    await flushFixtureGate(tester);
    expect(find.text('Carol\nc@example.com'), findsOneWidget);
    expect(find.textContaining('Late'), findsNothing);
    expect(h.requestedProfiles, ['a', 'b', 'c']);
    expect(h.profileCancels, {'a': 1, 'b': 1});
    await tester.pumpWidget(const SizedBox());
    expect(h.profileCancels['c'], 1);
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
  });
}
