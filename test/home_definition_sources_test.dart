import 'dart:async';

import 'package:andi_carpeta/home/home_definition_sources.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _DefinitionSnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {}

class _DefinitionCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  int snapshotCalls = 0;
  _DefinitionCollection(this.stream);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      expect(invocation.positionalArguments, isEmpty);
      expect(invocation.namedArguments[#includeMetadataChanges] ?? false, isFalse);
      snapshotCalls++;
      return stream;
    }
    return super.noSuchMethod(invocation);
  }
}

class _DefinitionFirestore extends Fake implements FirebaseFirestore {
  final requests = <String>[];
  final Map<String, _DefinitionCollection> collections;
  _DefinitionFirestore(this.collections);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    requests.add(path);
    return collections[path]!;
  }
}

void main() {
  test('adapter is lazy and preserves exact collections and snapshot defaults', () async {
    final controllers = List.generate(3,
        (_) => StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast());
    final collections = <String, _DefinitionCollection>{
      'locationCategories': _DefinitionCollection(controllers[0].stream),
      'backgrounds': _DefinitionCollection(controllers[1].stream),
      'functions': _DefinitionCollection(controllers[2].stream),
    };
    final db = _DefinitionFirestore(collections);
    final sources = HomeDefinitionSources.fromFirestore(db);
    expect(db.requests, isEmpty);
    expect(identical(sources.categories(), controllers[0].stream), isTrue);
    expect(identical(sources.backgrounds(), controllers[1].stream), isTrue);
    expect(identical(sources.functions(), controllers[2].stream), isTrue);
    expect(db.requests, ['locationCategories', 'backgrounds', 'functions']);
    expect(collections.values.map((c) => c.snapshotCalls), [1, 1, 1]);
    for (final controller in controllers) { await controller.close(); }
  });

  test('stream errors and reconnect events retain ordering without retry/listener duplication', () async {
    var listens = 0;
    var cancels = 0;
    final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
      onListen: () { listens++; }, onCancel: () { cancels++; },
    );
    var requests = 0;
    final sources = HomeDefinitionSources(
      categories: () { requests++; return controller.stream; },
      backgrounds: () => throw StateError('unused source'),
      functions: () => throw StateError('unused source'),
    );
    final received = <Object>[];
    final subscription = sources.categories().listen(received.add,
        onError: (Object error) { received.add(error); });
    final first = _DefinitionSnapshot();
    final recovered = _DefinitionSnapshot();
    final error = StateError('synthetic disconnect');
    controller.add(first);
    controller.addError(error);
    controller.add(recovered);
    await Future<void>.delayed(Duration.zero);
    expect(received, [same(first), same(error), same(recovered)]);
    expect(requests, 1);
    expect(listens, 1);
    await subscription.cancel();
    controller.add(_DefinitionSnapshot());
    await Future<void>.delayed(Duration.zero);
    expect(received.length, 3);
    expect(cancels, 1);
    await controller.close();
  });

  test('separate source instances do not share buffered events or subscriptions', () async {
    final old = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
    final next = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
    HomeDefinitionSources make(StreamController<QuerySnapshot<Map<String, dynamic>>> c) =>
        HomeDefinitionSources(categories: () => c.stream,
          backgrounds: () => c.stream, functions: () => c.stream);
    final received = <QuerySnapshot<Map<String, dynamic>>>[];
    final oldSubscription = make(old).categories().listen(received.add);
    await oldSubscription.cancel();
    final nextSubscription = make(next).categories().listen(received.add);
    old.add(_DefinitionSnapshot());
    final current = _DefinitionSnapshot();
    next.add(current);
    await Future<void>.delayed(Duration.zero);
    expect(received, [same(current)]);
    await nextSubscription.cancel();
    await old.close();
    await next.close();
  });
}
