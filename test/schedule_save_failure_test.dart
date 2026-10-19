import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/schedule/schedule_save_failure.dart';

void main() {
  test('maps permission and authentication failures to the existing guidance', () {
    expect(
      scheduleSaveFailureMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('apartenența activă la echipă și dreptul editProgram'),
    );
    expect(
      scheduleSaveFailureMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
      ),
      'Sesiunea a expirat. Autentifică-te din nou și reîncearcă salvarea.',
    );
  });

  test('keeps transient, stale-state and unknown Firestore messages distinct', () {
    final unavailable = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    final deadline = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'deadline-exceeded',
    );
    final stale = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
    );
    final unknown = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'internal',
    );

    expect(scheduleSaveFailureMessage(unavailable), contains('nu este disponibil'));
    expect(scheduleSaveFailureMessage(deadline), contains('nu este disponibil'));
    expect(scheduleSaveFailureMessage(stale), contains('s-a schimbat'));
    expect(scheduleSaveFailureMessage(unknown), contains('(internal)'));
  });

  test('preserves StateError text and generic error fallback', () {
    expect(scheduleSaveFailureMessage(StateError('already closed')), 'already closed');
    expect(scheduleSaveFailureMessage(ArgumentError('bad input')), contains('bad input'));
  });
}
