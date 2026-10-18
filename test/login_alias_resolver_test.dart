import 'dart:async';
import 'dart:convert';

import 'package:andi_carpeta/auth/login_alias_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('email bypasses HTTP and preserves case', () async {
    final resolver = LoginAliasResolver(post: (uri, {headers, body}) async {
      fail('email must not call alias endpoint');
    });
    expect(await resolver.resolve(' User@Example.test ', 'dummy'),
        'User@Example.test');
  });

  test('alias sends exact URI, headers and unmodified password once', () async {
    var calls = 0;
    final resolver = LoginAliasResolver(post: (uri, {headers, body}) async {
      calls++;
      expect(uri.toString(),
          'https://europe-central2-andicarpet-e777e.cloudfunctions.net/resolveLoginAlias');
      expect(headers, {'Content-Type': 'application/json'});
      expect(jsonDecode(body! as String),
          {'identifier': 'Alias', 'password': ' dummy password '});
      return http.Response('{"email":" User@Example.test "}', 200);
    });
    expect(await resolver.resolve(' Alias ', ' dummy password '),
        'User@Example.test');
    expect(calls, 1);
  });

  test('rejected and empty responses retain invalid-credential contract', () async {
    for (final response in [
      http.Response('not parsed', 403),
      http.Response('{}', 200),
      http.Response('[]', 200),
      http.Response('{"email":" "}', 200),
    ]) {
      final resolver = LoginAliasResolver(
          post: (uri, {headers, body}) async => response);
      await expectLater(resolver.resolve('alias', 'dummy'),
          throwsA(isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'invalid-credential')
              .having((e) => e.message, 'message',
                  'Date de autentificare incorecte.')));
    }
  });

  test('malformed JSON and transport failures propagate without retry', () async {
    final malformed = LoginAliasResolver(
        post: (uri, {headers, body}) async => http.Response('{', 200));
    await expectLater(malformed.resolve('alias', 'dummy'),
        throwsA(isA<FormatException>()));
    var calls = 0;
    final failure = StateError('synthetic network failure');
    final resolver = LoginAliasResolver(post: (uri, {headers, body}) async {
      calls++;
      throw failure;
    });
    await expectLater(resolver.resolve('alias', 'dummy'), throwsA(same(failure)));
    expect(calls, 1);
  });

  testWidgets('timeout is 15 seconds; late completion causes no retry', (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final resolver = LoginAliasResolver(post: (uri, {headers, body}) {
      calls++;
      return pending.future;
    });
    final result = resolver.resolve('alias', 'dummy');
    final assertion = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 15));
    await assertion;
    pending.complete(http.Response('{"email":"late@example.test"}', 200));
    await tester.pump();
    expect(calls, 1);
  });
}
