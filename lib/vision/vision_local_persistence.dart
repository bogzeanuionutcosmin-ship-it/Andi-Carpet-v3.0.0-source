import 'vision_error_log.dart';
import 'vision_persistence_status.dart';

/// Device-local persistence with injectable I/O for deterministic tests.
///
/// The first write waits for the initial read, so a report recorded while
/// secure storage is still loading cannot overwrite the existing snapshot.
/// Writes are serialized, with each snapshot encoded only after earlier
/// reads/writes have settled. No payloads are sent to the network.
class VisionLocalPersistence {
  VisionLocalPersistence({
    required this.log,
    required Future<String?> Function() read,
    required Future<void> Function(String snapshot) write,
  })  : _read = read,
        _write = write;

  final VisionErrorLog log;
  final Future<String?> Function() _read;
  final Future<void> Function(String snapshot) _write;
  final VisionPersistenceTracker status = VisionPersistenceTracker();

  Future<void>? _loading;
  Future<void>? _draining;
  int _requestedRevision = -1;

  Future<void> initialize() => _loading ??= _restore();

  Future<void> _restore() async {
    try {
      // Only the initial read combines earlier persisted occurrences with
      // same-code incidents collected before secure storage became ready.
      log.restore(await _read(), mergeExisting: true);
      status.readSucceeded();
    } catch (_) {
      // A corrupt/unavailable store must not block the application startup.
      status.readFailed();
    }
  }

  /// Called when a new event enters the bounded log.
  void changed() => status.changed();

  /// Coalesce overlapping flush requests instead of queueing a disk write for
  /// every occurrence in a burst of critical errors. Each call still awaits
  /// the latest revision requested while this drain is active.
  Future<void> flush() {
    final revision = status.revision;
    if (revision > _requestedRevision) _requestedRevision = revision;
    final active = _draining;
    if (active != null) return active;
    return _draining = _drain();
  }

  Future<void> _drain() async {
    try {
      // A pending secure-storage restore always completes before any write.
      await initialize();
      while (true) {
        // Encode only after all earlier platform writes are complete.
        final revision = status.revision;
        try {
          final snapshot = log.encode();
          await _write(snapshot);
          status.writeSucceeded(revision);
        } catch (_) {
          // A failed encode/write never poisons subsequent flush requests.
          status.writeFailed(revision);
        }
        // Newer requested events need one fresh snapshot, not N stale writes.
        if (_requestedRevision <= revision) break;
      }
    } finally {
      _requestedRevision = -1;
      _draining = null;
    }
  }
}
