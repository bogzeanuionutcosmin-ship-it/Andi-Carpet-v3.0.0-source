import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('cancelAll releases every owned subscription and can be reused', () async {
    final registry = app.HomeSubscriptionRegistry();
    final first = StreamController<int>.broadcast();
    final firstSubscription = first.stream.listen((_) {});
    registry.add(firstSubscription);

    await registry.cancelAll();
    expect(first.hasListener, isFalse);

    final second = StreamController<int>.broadcast();
    registry.add(second.stream.listen((_) {}));
    expect(second.hasListener, isTrue);
    await registry.cancelAll();
    expect(second.hasListener, isFalse);

    await first.close();
    await second.close();
  });

  test('dispose cancels owned and late subscriptions', () async {
    final registry = app.HomeSubscriptionRegistry();
    final active = StreamController<int>.broadcast();
    registry.add(active.stream.listen((_) {}));
    expect(active.hasListener, isTrue);

    await registry.dispose();
    expect(active.hasListener, isFalse);

    final late = StreamController<int>.broadcast();
    registry.add(late.stream.listen((_) {}));
    await Future<void>.delayed(Duration.zero);
    expect(late.hasListener, isFalse);

    await active.close();
    await late.close();
  });
}
