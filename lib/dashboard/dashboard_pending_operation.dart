/// Runs one asynchronous Dashboard action per key until that action settles.
Future<void> runDashboardPendingOperation({
  required Set<String> pending,
  required String key,
  required Future<void> Function() action,
}) async {
  if (!pending.add(key)) return;
  try {
    await action();
  } finally {
    pending.remove(key);
  }
}
