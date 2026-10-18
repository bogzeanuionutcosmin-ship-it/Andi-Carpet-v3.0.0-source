import 'package:andi_carpeta/home/home_message_queries.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_sync_fixture.dart';

void main() {
  test('query port preserves member UID filters, admin scope, ordering and limit without listening', () async {
    final db = HomeSyncFixture();
    final queries = HomeMessageQueries.fromFirestore(db);
    expect(db.trace, isEmpty);
    queries.notifications(isAdmin: false, uid: 'a').snapshots();
    queries.notifications(isAdmin: true, uid: 'a').snapshots();
    queries.privateMessages('a').snapshots();
    queries.groupMessages().snapshots();
    expect(db.trace, [
      'snapshots:notifications[where:userId=a]', 'snapshots:notifications',
      'snapshots:chatMessages[where:recipientId=a]',
      'snapshots:groupChatMessages[order:createdAt:desc][limit:20]',
    ]);
    expect(db.activeCount, 0);
    expect(db.starts, isEmpty);
    await db.close();
  });

  test('each UID constructs its own private query without caching or subscription ownership', () async {
    final db = HomeSyncFixture();
    final queries = HomeMessageQueries.fromFirestore(db);
    queries.privateMessages('a').snapshots();
    queries.privateMessages('b').snapshots();
    queries.notifications(isAdmin: false, uid: 'b').snapshots();
    expect(db.trace, [
      'snapshots:chatMessages[where:recipientId=a]',
      'snapshots:chatMessages[where:recipientId=b]',
      'snapshots:notifications[where:userId=b]',
    ]);
    expect(db.activeCount, 0);
    await db.close();
  });
}
