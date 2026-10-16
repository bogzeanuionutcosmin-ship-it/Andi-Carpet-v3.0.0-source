import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/auth/quick_accounts.dart';

void main() {
  test('load keeps trimming, invalid-entry filtering and existing over-limit data', () async {
    final store = QuickAccountStore(
      read: () async => jsonEncode([
        {'email': ' a@example.com ', 'password': ' dummy '},
        {'email': '', 'password': 'invalid'},
        {'email': 'b@example.com', 'password': 7},
        null,
        {'email': 'c@example.com', 'password': 'third'},
      ]),
      write: (_) async => fail('load must not write'),
      delete: () async => fail('load must not delete'),
    );
    final result = await store.load();
    expect(result.map((x) => x.email), ['a@example.com', 'b@example.com', 'c@example.com']);
    expect(result.first.password, ' dummy ');
    expect(result[1].password, '7');
  });

  test('missing, blank, malformed and non-list JSON retain empty fallback', () async {
    for (final raw in [null, '', '  ', '{broken', '{}', '4']) {
      final store = QuickAccountStore(
        read: () async => raw,
        write: (_) async => fail('fallback must not write'),
        delete: () async => fail('fallback must not delete'),
      );
      expect(await store.load(), isEmpty);
    }
  });

  test('save deduplicates by normalized key, retains insertion order and two entries', () async {
    final writes = <String>[];
    var deletes = 0;
    final store = QuickAccountStore(
      read: () async => fail('save must not read'),
      write: (value) async { writes.add(value); },
      delete: () async { deletes++; },
    );
    const accounts = [
      QuickAccount(email: ' A@EXAMPLE.COM ', password: 'first'),
      QuickAccount(email: 'b@example.com', password: 'second'),
      QuickAccount(email: 'a@example.com', password: 'last'),
      QuickAccount(email: 'c@example.com', password: 'third'),
    ];
    await store.save(accounts);
    expect(writes, hasLength(1));
    expect(jsonDecode(writes.single), [
      {'email': 'a@example.com', 'password': 'last'},
      {'email': 'b@example.com', 'password': 'second'},
    ]);
    expect(accounts, hasLength(4));
    expect(deletes, 0);
    await store.save([]);
    expect(deletes, 1);
    expect(writes, hasLength(1));
  });

  test('storage failures propagate without fallback writes', () async {
    final error = StateError('synthetic storage failure');
    final store = QuickAccountStore(
      read: () async => throw error,
      write: (_) async => throw error,
      delete: () async => throw error,
    );
    await expectLater(store.load(), throwsA(same(error)));
    await expectLater(store.save([const QuickAccount(email: 'a', password: 'dummy')]),
        throwsA(same(error)));
    await expectLater(store.save([]), throwsA(same(error)));
  });
}
