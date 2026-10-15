import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_bootstrap.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnostic startup never waits for local restore or throws storage errors', () async {
    final delayed = Completer<void>();
    final trace = <String>[];
    startVisionDiagnostics(installHandlers: () => trace.add('handlers'), restore: () {
      trace.add('restore'); return delayed.future;
    });
    trace.add('host startup');
    expect(trace, ['handlers', 'restore', 'host startup']);
    delayed.completeError(StateError('private storage error'));
    await Future<void>.delayed(Duration.zero);
    expect(() => startVisionDiagnostics(
      installHandlers: () => throw StateError('install'),
      restore: () => throw StateError('read'),
    ), returnsNormally);
  });

  test('real Flutter and async handlers chain once and serialize only fixed codes', () async {
    final previousFlutter = FlutterError.onError;
    final previousAsync = ui.PlatformDispatcher.instance.onError;
    var flutterCalls = 0, asyncCalls = 0;
    final writes = <String>[];
    const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(storage, (call) async {
      if (call.method == 'write') writes.add((call.arguments as Map)['value'] as String);
      return null;
    });
    try {
      FlutterError.onError = (_) => flutterCalls++;
      ui.PlatformDispatcher.instance.onError = (_, __) { asyncCalls++; return true; };
      startVisionDiagnostics();
      final handler = FlutterError.onError;
      startVisionDiagnostics();
      expect(identical(handler, FlutterError.onError), isTrue);
      handler!(FlutterErrorDetails(exception: StateError('a@example.test SECRET OCR 123.45 GPS 44.4')));
      expect(ui.PlatformDispatcher.instance.onError!(StateError('private token'), StackTrace.current), isTrue);
      await VisionErrorTelemetry.flush();
      expect(flutterCalls, 1); expect(asyncCalls, 1);
      final snapshot = VisionErrorTelemetry.log.encode();
      expect(snapshot, contains('framework_error')); expect(snapshot, contains('uncaught_error'));
      for (final private in ['a@example.test', 'SECRET', '123.45', '44.4', 'private token', 'StateError']) {
        expect(snapshot, isNot(contains(private)));
        for (final write in writes) { expect(write, isNot(contains(private))); }
      }
      expect(writes, isNotEmpty);
    } finally {
      FlutterError.onError = previousFlutter;
      ui.PlatformDispatcher.instance.onError = previousAsync;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(storage, null);
    }
  });
}
