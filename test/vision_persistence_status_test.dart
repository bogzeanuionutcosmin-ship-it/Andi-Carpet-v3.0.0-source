import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_persistence_status.dart';

void main() {
  late VisionPersistenceTracker tracker;

  setUp(() => tracker = VisionPersistenceTracker());

  test('no I/O means persistence is explicitly unverified', () {
    expect(tracker.state, VisionPersistenceState.unchecked);
    expect(tracker.displayMessage, contains('nu a fost încă verificată'));
    expect(tracker.revision, 0);
  });

  test('a readable store alone does not prove that writes succeeded', () {
    tracker.readSucceeded();
    expect(tracker.state, VisionPersistenceState.readable);
    expect(tracker.displayMessage, contains('o scriere nouă'));
  });

  test('a pending write cannot be claimed as saved', () {
    tracker.readSucceeded();
    tracker.changed();
    expect(tracker.revision, 1);
    expect(tracker.state, VisionPersistenceState.pending);
    tracker.writeSucceeded(1);
    expect(tracker.state, VisionPersistenceState.saved);
  });

  test('failed local read degrades honestly to memory-only', () {
    tracker.readFailed();
    expect(tracker.state, VisionPersistenceState.memoryOnly);
    expect(tracker.displayMessage, contains('se poate pierde'));
  });

  test('failed write stays memory-only until a successful write', () {
    tracker.changed();
    tracker.writeFailed(1);
    expect(tracker.state, VisionPersistenceState.memoryOnly);
    tracker.changed();
    expect(tracker.state, VisionPersistenceState.memoryOnly);
    tracker.writeSucceeded(2);
    expect(tracker.state, VisionPersistenceState.saved);
  });

  test('an older successful write must not certify newer events', () {
    tracker.changed();
    final firstSnapshot = tracker.revision;
    tracker.changed();
    tracker.writeSucceeded(firstSnapshot);
    expect(tracker.state, VisionPersistenceState.pending);
    tracker.writeSucceeded(tracker.revision);
    expect(tracker.state, VisionPersistenceState.saved);
  });

  test('later failing write does not erase previous persisted revision', () {
    tracker.changed();
    tracker.writeSucceeded(1);
    tracker.changed();
    tracker.writeFailed(2);
    expect(tracker.state, VisionPersistenceState.memoryOnly);
    expect(tracker.revision, 2);
    tracker.writeSucceeded(2);
    expect(tracker.state, VisionPersistenceState.saved);
  });

  test('invalid future/negative callbacks cannot mark journal saved', () {
    tracker.changed();
    tracker.writeSucceeded(3);
    tracker.writeSucceeded(-1);
    expect(tracker.state, VisionPersistenceState.pending);
    tracker.writeFailed(-1);
    tracker.writeFailed(4);
    expect(tracker.state, VisionPersistenceState.pending);
  });

  test('no values, UIDs or raw errors appear in status descriptions', () {
    for (final state in VisionPersistenceState.values) {
      switch (state) {
        case VisionPersistenceState.unchecked:
          break;
        case VisionPersistenceState.readable:
          tracker.readSucceeded();
          break;
        case VisionPersistenceState.pending:
          tracker.changed();
          break;
        case VisionPersistenceState.memoryOnly:
          tracker.writeFailed(tracker.revision);
          break;
        case VisionPersistenceState.saved:
          tracker.writeSucceeded(tracker.revision);
          break;
      }
      final message = tracker.displayMessage;
      expect(message, isNot(contains('UID')));
      expect(message, isNot(contains('@')));
      expect(message, isNot(contains('token=')));
      expect(message, isNot(contains('FirebaseFirestore')));
    }
  });
}
