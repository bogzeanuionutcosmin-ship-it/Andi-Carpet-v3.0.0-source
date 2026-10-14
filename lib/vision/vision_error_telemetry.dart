import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vision_error_log.dart';
import 'vision_local_persistence.dart';
import 'vision_telemetry_lifecycle.dart';

/// Device-only error collection. No Firebase writes, no network AI, no secrets.
///
/// The encrypted platform store is used for a deliberately SMALL snapshot,
/// not as a general-purpose high-volume log database. On platforms where the
/// store is unavailable diagnostics degrade safely to in-memory summaries.
class VisionErrorTelemetry {
  VisionErrorTelemetry._();

  static const _storageKey = 'vision_error_summaries_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final VisionErrorLog log = VisionErrorLog(
    maxEntries: 150,
    maxBytes: 48 * 1024,
    retention: const Duration(days: 7),
  );

  static final VisionLocalPersistence _local = VisionLocalPersistence(
    log: log,
    read: () => _storage.read(key: _storageKey),
    write: (snapshot) => _storage.write(key: _storageKey, value: snapshot),
  );

  /// Only describes locally observed reads and completed writes; not Firebase.
  static String get persistenceMessage => _local.status.displayMessage;

  static Timer? _writeTimer;
  static bool _installed = false;

  // One observer for the app lifetime; only flush already pending snapshots.
  // An abrupt OS process kill can still interrupt an asynchronous write.
  static final VisionTelemetryLifecycleObserver _lifecycleObserver =
      VisionTelemetryLifecycleObserver(
    hasPending: () => _writeTimer != null,
    flush: flush,
  );

  static String get _platform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  static Future<void> initialize() => _local.initialize();

  static void installFlutterHandlers() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      report(
        area: 'flutter_framework',
        code: details.exception.runtimeType.toString(),
        severity: VisionErrorSeverity.error,
      );
      // Preserve Flutter's previous reporting behavior.
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final previousAsyncHandler = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      report(
        area: 'dart_async',
        code: error.runtimeType.toString(),
        severity: VisionErrorSeverity.critical,
      );
      // Returning false when there was no handler preserves uncaught errors;
      // observing them must never silently turn crashes into success.
      return previousAsyncHandler?.call(error, stack) ?? false;
    };
  }

  /// Call with a fixed area/code; never pass exception messages, OCR text,
  /// GPS positions, private chat content or server credentials.
  static void report({
    required String area,
    required String code,
    VisionErrorSeverity severity = VisionErrorSeverity.error,
  }) {
    try {
      log.record(area: area, code: code, platform: _platform, severity: severity);
      _local.changed();
      if (severity == VisionErrorSeverity.critical) {
        unawaited(flush());
      } else {
        _writeTimer?.cancel();
        _writeTimer = Timer(const Duration(seconds: 3), () {
          unawaited(flush());
        });
      }
    } catch (_) {
      // Error reporting must never recursively trigger more error reports.
    }
  }

  /// Serializing writes avoids stale snapshots overwriting newer ones.
  static Future<void> flush() {
    _writeTimer?.cancel();
    _writeTimer = null;
    return _local.flush();
  }
}
