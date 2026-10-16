import 'vision_session_journal.dart';

/// Explicit lifecycle bridge for a future authenticated Vision entry point.
///
/// The *authoritative* AuthGate owner supplies [isSessionCurrent], which must
/// check both UID and session generation. Never bind only to a UID or reuse an
/// always-true predicate outside synthetic tests.
///
/// This coordinator does not listen to Firebase, create routes or read the
/// installation-wide journal. The caller must call [replaceSession] after
/// every authoritative new authentication epoch, and [clear] synchronously
/// before logout/root disposal; an unannounced external state change can
/// only be noticed when the lease is next queried.
class VisionSessionLifecycleCoordinator {
  VisionSessionLifecycleCoordinator({VisionSessionJournal? journal})
      : _journal = journal ?? VisionSessionJournal();

  final VisionSessionJournal _journal;
  VisionSessionJournalLease? _lease;
  bool _disposed = false;

  /// A previously issued lease is never reactivated by a later session.
  VisionSessionJournalLease? get activeLease {
    if (_disposed) return null;
    final current = _lease;
    if (current == null || !current.isCurrent) {
      _lease = null;
      return null;
    }
    return current;
  }

  /// Always invalidates the last epoch first, including for same-UID login.
  ///
  /// The caller is responsible for providing the AuthGate callback bound to
  /// this precise UID+generation. No UID is stored in the journal.
  VisionSessionJournalLease replaceSession({
    required bool Function() isSessionCurrent,
  }) {
    if (_disposed) throw StateError('Vision session coordinator disposed');
    _lease = null;
    final lease = _journal.startSession(
      isSessionCurrent: isSessionCurrent,
    );
    _lease = lease;
    return lease;
  }

  /// Immediate fail-closed logout/identity switch before resetting navigation.
  void clear() {
    _lease = null;
    _journal.revoke();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    clear();
  }
}
