import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';
import 'support/security_home_fixture.dart' as secured;
import 'support/vision_live_sdk_fixture.dart';

Future<T> trackTimers<T>(Future<T> Function() body, List<Duration> delays) => runZoned(body,
  zoneSpecification: ZoneSpecification(createTimer: (self, parent, zone, duration, callback) {
    if (duration == const Duration(milliseconds: 250)) delays.add(duration);
    return parent.createTimer(zone, duration, callback);
  }));

http.Response locality(String label) => http.Response('{"address":{"city":"$label"}}', 200);
int failures() => VisionErrorTelemetry.log.entries.where((e) => e.area == 'gps' &&
  e.code == 'location_update_failed').fold(0, (n, e) => n + e.count);

// Feed public State model inputs; invoke only the real plugin stream callback.
// Accuracy100 deliberately keeps the unrelated work-automation path closed.
void scheduleNear(dynamic state) {
  state.me.teamId = 'synthetic-team';
  (state.locations as List<Location>)..clear()..add(Location(id: 'synthetic-location',
    name: 'Synthetic', address: '', type: LocationType.magic, latitude: 44, longitude: 26));
  (state.schedules as List<WorkSchedule>).add(WorkSchedule(id: 'synthetic-schedule',
    teamId: 'synthetic-team', date: operationalWorkDate(DateTime.now()), started: true,
    items: [ScheduleItem(locationId: 'synthetic-location', locationNameSnapshot: 'Synthetic',
      addressSnapshot: '', typeSnapshot: LocationType.magic, order: 0)]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sdkDb = VisionLiveFirestore();
  for (final stage in ['http-success', 'http-failure', 'boost250', 'relax250']) {
    testWidgets('real GPS $stage cannot write or restart A1 after A B A2 while B works', (tester) async {
      final oldGps = GeolocatorPlatform.instance;
      setupFirebaseCoreMocks(); await Firebase.initializeApp();
      final oldDb = FirebaseFirestorePlatform.instance;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      sdkDb.attempts.clear(); sdkDb.unexpected.clear();
      FirebaseFirestorePlatform.instance = sdkDb;
      final a = VisionLiveGps(), b = VisionLiveGps(); GeolocatorPlatform.instance = a;
      final auth = SessionAuth(), db = SessionFirestore(); final home = secured.HomeSyncFixture();
      final pending = <Completer<http.Response>>[];
      final requests = <http.Request>[];
      final before = failures(); final delays = <Duration>[];
      final client = MockClient((request) {
        requests.add(request);
        expect(request.method, 'GET'); expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.path, '/reverse');
        if (request.url.queryParameters['lat'] == '45.0000000') return Future.value(locality('Synthetic B'));
        final gate = Completer<http.Response>(); pending.add(gate); return gate.future;
      });
      bool Function()? firstOwner;
      try {
        await trackTimers(() => http.runWithClient(() async {
          await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) {
            final returning = profile.uid == 'a' && firstOwner != null && !firstOwner!();
            if (profile.uid == 'a' && firstOwner == null) firstOwner = current;
            return secured.FixtureHomePage(key: key, profile: profile, fixture: home,
              sessionIsCurrent: current, realLocation: !returning);
          });
          db.profile('a'); await harness.flush(tester); expect(a.starts, 1);
          if (stage.endsWith('250')) scheduleNear(tester.state(find.byType(secured.FixtureHomePage)));
          a.positions.add(syntheticPosition(44)); await harness.flush(tester);
          expect(pending, hasLength(1)); expect(sdkDb.attempts, isEmpty);
          if (stage == 'relax250') {
            a.positions.add(syntheticPosition(46)); await harness.flush(tester);
            expect(pending, hasLength(2));
          }
          expect(delays, hasLength(stage == 'relax250' ? 2 : stage == 'boost250' ? 1 : 0));
          await tester.pump(const Duration(milliseconds: 249)); expect(a.starts, 1);
          GeolocatorPlatform.instance = b;
          auth.switchTo('b'); await harness.flush(tester); db.profile('b'); await harness.flush(tester);
          expect(firstOwner!(), isFalse); expect(a.cancels, 1); expect(b.starts, 1);
          b.positions.add(syntheticPosition(45)); await harness.flush(tester);
          expect(sdkDb.attempts, hasLength(1));
          expect(sdkDb.attempts.single['path'], 'liveLocations/b');
          final data = sdkDb.attempts.single['data'] as Map;
          expect(data['userId'], 'b'); expect(data['localityLabel'], 'Synthetic B');
          expect(sdkDb.attempts.single['merge'], isTrue);
          auth.switchTo('a'); await harness.flush(tester); db.profile('a'); await harness.flush(tester);
          await tester.pump(const Duration(milliseconds: 1));
          for (final gate in pending) {
            if (stage == 'http-failure') { gate.completeError(StateError('PRIVATE A geocoding')); }
            else { gate.complete(locality('PRIVATE A locality')); }
          }
          await harness.flush(tester);
          expect(a.starts, 1); expect(b.starts, 1); expect(b.cancels, 1);
          expect(sdkDb.attempts, hasLength(1)); expect(sdkDb.unexpected, isEmpty);
          expect(requests, hasLength(pending.length + 1));
          expect(failures(), before); expect(home.writes, isEmpty);
          expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
          await tester.pumpWidget(const SizedBox()); expect(home.activeCount, 0);
          // Drain the original 8s HTTP timeout timers, not wall-clock waiting.
          await tester.pump(const Duration(seconds: 9)); expect(tester.takeException(), isNull);
        }, () => client), delays);
      } finally {
        GeolocatorPlatform.instance = oldGps; FirebaseFirestorePlatform.instance = oldDb;
        debugDefaultTargetPlatformOverride = null;
        await auth.events.close(); await db.close(); await home.close();
        await a.positions.close(); await b.positions.close(); client.close();
      }
    });
  }

  testWidgets('real active GPS boost and relaxation each retune at 250ms without new I/O', (tester) async {
    final oldGps = GeolocatorPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final gps = VisionLiveGps(); GeolocatorPlatform.instance = gps;
    final delays = <Duration>[];
    final home = secured.HomeSyncFixture(); final pending = <Completer<http.Response>>[];
    final client = MockClient((request) {
      final gate = Completer<http.Response>(); pending.add(gate); return gate.future;
    });
    try {
      await trackTimers(() => http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: secured.FixtureHomePage(key: const ValueKey('active'),
          profile: secured.fixtureHomeProfile('a'), fixture: home, realLocation: true)));
        await harness.flush(tester); expect(gps.starts, 1);
        scheduleNear(tester.state(find.byType(secured.FixtureHomePage)));
        gps.positions.add(syntheticPosition(44)); await harness.flush(tester);
        expect(pending, hasLength(1)); expect(delays, hasLength(1));
        await tester.pump(const Duration(milliseconds: 249)); expect(gps.starts, 1);
        await tester.pump(const Duration(milliseconds: 1)); await harness.flush(tester);
        expect(gps.starts, 2, reason: 'trace=${gps.trace}, settings=${gps.settingsHistory.length}, timers=$delays'); expect(gps.cancels, 1);
        expect(gps.settingsHistory.last!.accuracy, LocationAccuracy.high);
        expect(gps.settingsHistory.last!.distanceFilter, 10);
        gps.positions.add(syntheticPosition(46)); await harness.flush(tester);
        await tester.pump(const Duration(milliseconds: 249)); expect(gps.starts, 2);
        await tester.pump(const Duration(milliseconds: 1)); await harness.flush(tester);
        expect(gps.starts, 3); expect(gps.cancels, 2);
        expect(gps.settingsHistory.last!.accuracy, LocationAccuracy.medium);
        expect(gps.settingsHistory.last!.distanceFilter, 60);
        expect(pending, hasLength(2)); expect(home.writes, isEmpty);
        await tester.pumpWidget(const SizedBox()); expect(gps.cancels, 3);
        for (final gate in pending) { gate.complete(locality('PRIVATE disposed')); }
        await harness.flush(tester); await tester.pump(const Duration(seconds: 9));
        expect(home.activeCount, 0); expect(tester.takeException(), isNull);
      }, () => client), delays);
    } finally {
      GeolocatorPlatform.instance = oldGps; debugDefaultTargetPlatformOverride = null;
      await gps.positions.close(); await home.close(); client.close();
    }
  });
}
