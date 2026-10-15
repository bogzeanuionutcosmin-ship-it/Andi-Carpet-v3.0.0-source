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
  String? _savedSnapshot;

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

  /// One shared drain, even for thousands of simultaneous critical reports.
  /// Encoding waits for restore; dirty events during a write are included in
  /// the final snapshot even if their caller did not request another flush.
  /// Explicit flush retries failures, but no automatic same-revision retry
  /// or unbounded queue of futures is created.
  Future<void> flush() => _draining ??= _drain();

  Future<void> _drain() async {
    try {
      await initialize();
      while (true) {
        final revision = status.revision;
        try {
          // Re-encode on explicit flush: TTL pruning can change the snapshot
          // without a new report/revision. Unchanged successful snapshots
          // need no additional secure-storage write.
          final snapshot = log.encode();
          if (snapshot != _savedSnapshot ||
              status.state != VisionPersistenceState.saved) {
            await _write(snapshot);
            _savedSnapshot = snapshot;
          }
          status.writeSucceeded(revision);
        } catch (_) {
          status.writeFailed(revision);
        }
        if (status.revision <= revision) break;
      }
    } finally {
      _draining = null;
    }
  }
}
