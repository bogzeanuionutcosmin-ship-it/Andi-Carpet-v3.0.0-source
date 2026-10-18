import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/bootstrap/firebase_initialization.dart';
import 'package:andi_carpeta/vision/vision_bootstrap.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:andi_carpeta/vision/vision_local_persistence.dart';
import 'package:andi_carpeta/vision/vision_persistence_status.dart';
import 'package:andi_carpeta/vision/vision_telemetry_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('slow failed storage preserves absent handlers and does not block Firebase failure', () async {
    final read = Completer<String?>(); var reads = 0, presents = 0, firebaseCalls = 0;
    final writes = <String>[];
    final previousFlutter = FlutterError.onError;
    final previousPresent = FlutterError.presentError;
    final previousAsync = ui.PlatformDispatcher.instance.onError;
    const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(storage, (call) async {
      if (call.method == 'read') { reads++; return read.future; }
      if (call.method == 'write') writes.add((call.arguments as Map)['value'] as String);
      return null;
    });
    try {
      FlutterError.onError = null;
      FlutterError.presentError = (_) { presents++; };
      ui.PlatformDispatcher.instance.onError = null;
      startVisionDiagnostics(); final handler = FlutterError.onError;
      startVisionDiagnostics(); expect(identical(handler, FlutterError.onError), isTrue);
      await Future<void>.delayed(Duration.zero); expect(reads, 1);
      final failure = StateError('PRIVATE Firebase failure');
      await expectLater(initializeFirebaseForPlatform(
        useNativeIosConfiguration: () => false,
        initializeNative: () async => fail('wrong platform'),
        initializeConfigured: () async { firebaseCalls++; throw failure; }), throwsA(same(failure)));
      expect(firebaseCalls, 1); expect(writes, isEmpty);
      handler!(FlutterErrorDetails(exception: StateError('PRIVATE uid token OCR')));
      expect(presents, 1);
      expect(ui.PlatformDispatcher.instance.onError!(failure, StackTrace.current), isFalse);
      final flush = VisionErrorTelemetry.flush();
      read.completeError(StateError('PRIVATE keystore')); await flush;
      expect(reads, 1); expect(writes, hasLength(1));
      expect(writes.single, contains('framework_error'));
      expect(writes.single, contains('uncaught_error'));
      expect(writes.single, isNot(contains('PRIVATE')));
    } finally {
      FlutterError.onError = previousFlutter; FlutterError.presentError = previousPresent;
      ui.PlatformDispatcher.instance.onError = previousAsync;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(storage, null);
    }
  });

  test('lifecycle storm shares blocked drain and kill remains best effort', () async {
    final gate = Completer<void>(); final writes = <String>[];
    final log = VisionErrorLog()..record(area: 'system', code: 'background', platform: 'android');
    final local = VisionLocalPersistence(log: log, read: () async => null,
      write: (s) async { writes.add(s); await gate.future; });
    local.changed();
    final observer = VisionTelemetryLifecycleObserver(hasPending: () => true, flush: local.flush);
    for (var i = 0; i < 100; i++) {
      for (final state in AppLifecycleState.values) { observer.didChangeAppLifecycleState(state); }
    }
    await Future<void>.delayed(Duration.zero);
    expect(writes, hasLength(1)); expect(local.status.state, VisionPersistenceState.pending);
    // A queued platform write is not a durable-save claim at process kill.
    final drain = local.flush(); gate.complete(); await drain;
    expect(local.status.state, VisionPersistenceState.saved);
    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    await local.flush(); expect(writes, hasLength(1));
  });
}
