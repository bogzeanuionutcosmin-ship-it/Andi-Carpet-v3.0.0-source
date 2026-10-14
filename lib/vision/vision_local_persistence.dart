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
  Future<void> _lastWrite = Future<void>.value();

  Future<void> initialize() => _loading ??= _restore();

  Future<void> _restore() async {
    try {
      log.restore(await _read());
      status.readSucceeded();
    } catch (_) {
      // A corrupt/unavailable store must not block the application startup.
      status.readFailed();
    }
  }

  /// Called when a new event enters the bounded log.
  void changed() => status.changed();

  /// Await all earlier writes and the initial restore before taking a snapshot.
  ///
  /// Errors are recorded in the status; diagnostic failures never prevent
  /// normal app operation or trigger recursive error reports.
  Future<void> flush() {
    _lastWrite = _lastWrite.then((_) async {
      await initialize();
      final snapshot = log.encode();
      final revision = status.revision;
      try {
        await _write(snapshot);
        status.writeSucceeded(revision);
      } catch (_) {
        status.writeFailed(revision);
      }
    });
    return _lastWrite;
  }
}
