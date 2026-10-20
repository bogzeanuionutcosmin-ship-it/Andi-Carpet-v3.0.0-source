import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/chat/visible_chat_sender_policy.dart';

void main() {
  group('visibleChatSenderName', () {
    test('masks a hidden sender for a non-admin', () {
      expect(
        visibleChatSenderName(
          {'senderId': 'hidden-1', 'senderName': 'Nume privat'},
          isAdmin: false,
          hiddenUserIds: {'hidden-1'},
        ),
        'Sistem',
      );
    });

    test('preserves the hidden sender name for an admin', () {
      expect(
        visibleChatSenderName(
          {'senderId': 'hidden-1', 'senderName': 'Nume privat'},
          isAdmin: true,
          hiddenUserIds: {'hidden-1'},
        ),
        'Nume privat',
      );
    });

    test('returns the supplied name for a visible sender', () {
      expect(
        visibleChatSenderName(
          {'senderId': 'member-1', 'senderName': 'Ana'},
          isAdmin: false,
          hiddenUserIds: {'hidden-1'},
        ),
        'Ana',
      );
    });

    test('uses the original fallback for a missing or null sender name', () {
      expect(
        visibleChatSenderName(
          {'senderId': 'member-1'},
          isAdmin: false,
          hiddenUserIds: const {},
        ),
        'un membru',
      );
      expect(
        visibleChatSenderName(
          {'senderId': 'member-1', 'senderName': null},
          isAdmin: false,
          hiddenUserIds: const {},
        ),
        'un membru',
      );
    });

    test('preserves the existing toString conversion and does not mutate input', () {
      final data = <String, dynamic>{'senderId': 17, 'senderName': 42};
      final before = Map<String, dynamic>.of(data);

      expect(
        visibleChatSenderName(
          data,
          isAdmin: false,
          hiddenUserIds: const {},
        ),
        '42',
      );
      expect(data, before);
    });
  });
}
