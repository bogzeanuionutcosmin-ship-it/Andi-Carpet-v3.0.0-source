/// Pure display policy for a chat sender shown in Home notifications.
///
/// Hidden senders are masked from non-admin users. Admin visibility and the
/// existing fallback/string conversion behavior are preserved.
String visibleChatSenderName(
  Map<String, dynamic> data, {
  required bool isAdmin,
  required Set<String> hiddenUserIds,
}) {
  final senderId = (data['senderId'] ?? '').toString();
  if (!isAdmin && hiddenUserIds.contains(senderId)) return 'Sistem';
  return (data['senderName'] ?? 'un membru').toString();
}
