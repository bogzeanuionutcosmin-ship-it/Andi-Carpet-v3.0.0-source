import 'vision_error_log.dart';
import 'vision_session_journal.dart';

/// Platform labels are fixed at compile time. Never forward a user agent,
/// device identifier, GPS coordinate or an arbitrary exception string.
enum VisionSignalPlatform { android, ios, windows, web, macos, linux, unknown }

/// Closed catalogue of anonymous, fixed diagnostic signals.
///
/// These are only technical *observations*, not evidence that a financial
/// operation succeeded, a GPS location was reached or a server write failed.
/// Adding a signal requires review of its privacy and semantics. Never include
/// an amount, UID, address, OCR text, token or exception in these identifiers.
enum VisionDiagnosticSignal {
  authSessionRevoked(
    'auth', 'session_revoked', VisionErrorSeverity.warning,
  ),
  authProfileUnavailable(
    'auth', 'profile_unavailable', VisionErrorSeverity.warning,
  ),
  gpsPermissionDenied(
    'gps', 'permission_denied', VisionErrorSeverity.warning,
  ),
  gpsLocationUnavailable(
    'gps', 'location_unavailable', VisionErrorSeverity.warning,
  ),
  gpsBackgroundRestricted(
    'gps', 'background_restricted', VisionErrorSeverity.warning,
  ),
  ocrRecognitionFailed(
    'ocr', 'recognition_failed', VisionErrorSeverity.error,
  ),
  ocrAmountInvalid(
    'ocr', 'amount_invalid', VisionErrorSeverity.warning,
  ),
  ocrSaveUncertain(
    'ocr', 'save_uncertain', VisionErrorSeverity.error,
  ),
  fcmPermissionDenied(
    'fcm', 'permission_denied', VisionErrorSeverity.warning,
  ),
  fcmTokenUnavailable(
    'fcm', 'token_unavailable', VisionErrorSeverity.warning,
  ),
  mapGeocodeUnavailable(
    'map', 'geocode_unavailable', VisionErrorSeverity.warning,
  ),
  mapRouteUnavailable(
    'map', 'route_unavailable', VisionErrorSeverity.warning,
  ),
  syncOffline(
    'sync', 'offline', VisionErrorSeverity.warning,
  ),
  syncConflict(
    'sync', 'conflict', VisionErrorSeverity.error,
  ),
  financeOperationUncertain(
    'finance', 'operation_uncertain', VisionErrorSeverity.warning,
  ),
  financeRevisionConflict(
    'finance', 'revision_conflict', VisionErrorSeverity.warning,
  ),
  financePermissionRejected(
    'finance', 'permission_rejected', VisionErrorSeverity.error,
  ),
  visionLocalStorageUnavailable(
    'vision', 'local_storage_unavailable', VisionErrorSeverity.warning,
  );

  const VisionDiagnosticSignal(this.area, this.code, this.severity);

  final String area;
  final String code;
  final VisionErrorSeverity severity;
}

/// Opt-in, session-revocable entry point for authorized event producers.
///
/// A producer may submit only a fixed enum signal and enum platform; there is
/// no parameter for raw errors or business data. This object does NOT create
/// a session, validate an account independently, register global handlers,
/// open the installation-wide persisted log or communicate with Firebase.
/// Its lease MUST originate from the current AuthGate UID+generation scope.
///
/// This adapter performs no I/O, timers or retries. In particular,
/// financeOperationUncertain is only a diagnostic label and MUST NOT be used
/// to infer either a server commit or a rejected financial operation.
class VisionScopedSignalSink {
  const VisionScopedSignalSink(this._lease);

  final VisionSessionJournalLease _lease;

  bool emit(
    VisionDiagnosticSignal signal, {
    required VisionSignalPlatform platform,
  }) {
    try {
      if (!_lease.isCurrent) return false;
      return _lease.record(
        area: signal.area,
        code: signal.code,
        platform: platform.name,
        severity: signal.severity,
      );
    } catch (_) {
      // Diagnostic failure may never block the actual app operation.
      // In particular, do not serialize exception.toString() into a log.
      return false;
    }
  }
}
