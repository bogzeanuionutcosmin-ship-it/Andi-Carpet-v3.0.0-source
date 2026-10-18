import 'dart:async';
import 'vision_error_telemetry.dart';

/// Start local observation without delaying Firebase or the host application.
/// Optional effect ports are only for deterministic startup tests.
void startVisionDiagnostics({
  void Function()? installHandlers,
  Future<void> Function()? restore,
}) {
  try {
    (installHandlers ?? VisionErrorTelemetry.installFlutterHandlers)();
  } catch (_) {
    // Local diagnostics are best effort; keep the host's startup path intact.
  }
  try {
    unawaited((restore ?? VisionErrorTelemetry.initialize)().catchError((Object _) {}));
  } catch (_) {
    // Also tolerate synchronous failures in a platform/test adapter.
  }
}
