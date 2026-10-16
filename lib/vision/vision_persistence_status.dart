/// Honest, device-only status of the Vision diagnostic journal.
///
/// This is *not* a health probe of Android, encrypted storage or Firestore.
/// Only a completed local write may be described as saved. It holds no events,
/// file paths, user identifiers, exception details or payloads.
enum VisionPersistenceState {
  unchecked,
  readable,
  pending,
  memoryOnly,
  saved,
}

class VisionPersistenceTracker {
  int _currentRevision = 0;
  int _savedRevision = -1;
  int _lastFailedRevision = -1;
  bool _readCompleted = false;
  bool _storageUnavailable = false;

  /// Version of the snapshot captured by the caller BEFORE its write.
  int get revision => _currentRevision;

  VisionPersistenceState get state {
    // A later failed read/write cannot be certified by an earlier successful
    // write, even if that write already covered the current revision.
    if (_storageUnavailable) return VisionPersistenceState.memoryOnly;
    if (_savedRevision == _currentRevision && _savedRevision >= 0) {
      return VisionPersistenceState.saved;
    }
    if (_currentRevision > _savedRevision && _currentRevision > 0) {
      return VisionPersistenceState.pending;
    }
    return _readCompleted
        ? VisionPersistenceState.readable
        : VisionPersistenceState.unchecked;
  }

  String get displayMessage => switch (state) {
        VisionPersistenceState.unchecked =>
          'Salvarea locală nu a fost încă verificată în această sesiune.',
        VisionPersistenceState.readable =>
          'Stocarea locală este accesibilă la citire; '
          'o scriere nouă nu a fost încă verificată.',
        VisionPersistenceState.pending =>
          'Evenimentele recente așteaptă confirmarea salvării locale.',
        VisionPersistenceState.memoryOnly =>
          'Salvarea locală nu este disponibilă. '
          'Jurnalul poate exista doar în memorie și se poate pierde la închidere.',
        VisionPersistenceState.saved =>
          'Ultima versiune a jurnalului a fost salvată local.',
      };

  void readSucceeded() {
    _readCompleted = true;
    // An earlier failure can be transient, but a readable storage backend
    // alone does not establish that writes are working.
  }

  void readFailed() {
    _readCompleted = true;
    _storageUnavailable = true;
  }

  /// Must be called only AFTER accepting an event into the bounded log.
  void changed() {
    _currentRevision++;
  }

  /// Accept a completed write only for the matching snapshot revision.
  /// Success on an older queued write must not certify newer events.
  void writeSucceeded(int snapshotRevision) {
    if (snapshotRevision < 0 || snapshotRevision > _currentRevision) return;
    if (snapshotRevision > _savedRevision) {
      _savedRevision = snapshotRevision;
    }
    // A stale successful callback must not mask a later failed snapshot.
    if (snapshotRevision >= _lastFailedRevision) {
      _storageUnavailable = false;
    }
  }

  void writeFailed(int snapshotRevision) {
    if (snapshotRevision < 0 || snapshotRevision > _currentRevision) return;
    if (snapshotRevision >= _savedRevision) {
      if (snapshotRevision > _lastFailedRevision) {
        _lastFailedRevision = snapshotRevision;
      }
      _storageUnavailable = true;
    }
  }
}
