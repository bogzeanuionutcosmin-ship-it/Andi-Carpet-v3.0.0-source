import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/bootstrap/firebase_initialization.dart';

void main() {
  test('selects exactly one action after evaluating the predicate once', () async {
    for (final native in [true, false]) {
      final events = <String>[];
      await initializeFirebaseForPlatform(
        useNativeIosConfiguration: () { events.add('predicate'); return native; },
        initializeNative: () async { events.add('native'); },
        initializeConfigured: () async { events.add('configured'); },
      );
      expect(events, ['predicate', native ? 'native' : 'configured']);
    }
  });

  test('awaits the selected action and never evaluates the unselected action', () async {
    final gate = Completer<void>();
    var finished = false;
    final operation = initializeFirebaseForPlatform(
      useNativeIosConfiguration: () => true,
      initializeNative: () => gate.future,
      initializeConfigured: () async => fail('configured action must stay lazy'),
    ).then((_) { finished = true; });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    gate.complete();
    await operation;
    expect(finished, isTrue);
  });

  test('initialization errors propagate without a retry or fallback', () async {
    final error = StateError('synthetic initialization failure');
    for (final native in [true, false]) {
      var nativeCalls = 0;
      var configuredCalls = 0;
      final operation = initializeFirebaseForPlatform(
        useNativeIosConfiguration: () => native,
        initializeNative: () async { nativeCalls++; throw error; },
        initializeConfigured: () async { configuredCalls++; throw error; },
      );
      await expectLater(operation, throwsA(same(error)));
      expect(nativeCalls, native ? 1 : 0);
      expect(configuredCalls, native ? 0 : 1);
    }
  });

  test('predicate errors do not run either initialization action', () async {
    final error = StateError('synthetic predicate failure');
    await expectLater(initializeFirebaseForPlatform(
      useNativeIosConfiguration: () => throw error,
      initializeNative: () async => fail('must not initialize'),
      initializeConfigured: () async => fail('must not initialize'),
    ), throwsA(same(error)));
  });
}
