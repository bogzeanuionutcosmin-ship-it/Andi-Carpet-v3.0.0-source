/// Selects the existing native/configured initialization action.
/// SDK calls and the platform predicate are supplied by the application adapter.
Future<void> initializeFirebaseForPlatform({
  required bool Function() useNativeIosConfiguration,
  required Future<void> Function() initializeNative,
  required Future<void> Function() initializeConfigured,
}) async {
  if (useNativeIosConfiguration()) {
    await initializeNative();
    return;
  }
  await initializeConfigured();
}
