part of '../main.dart';

const String _webPushVapidKey = String.fromEnvironment(
  'FCM_WEB_VAPID_KEY',
  defaultValue: 'BMJikC3fON4-4uwRuMOzZRXYjQCbp2ftRsSt_PcBOpf9sTCv4VkwEkzxerxSZCMd5dyooMtHhU6hvLDeqWUkFHw',
);

Future<void> _initializeFirebaseForPlatform() async {
  const host = String.fromEnvironment('ANDICARPET_EMULATOR_HOST');
  if (host.isNotEmpty) {
    if (!kDebugMode || !['10.0.2.2', '127.0.0.1', 'localhost'].contains(host)) {
      throw StateError('Emulator Firebase permis doar în debug pe loopback.');
    }
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: 'demo-andi-xix-key', appId: '1:123456789:android:demoandixix',
      messagingSenderId: '123456789', projectId: 'demo-andi-xix',
    ));
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    return;
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && !DefaultFirebaseOptions.hasIosDartConfig) {
    // Pe iOS acceptăm configurația nativă standard GoogleService-Info.plist.
    await Firebase.initializeApp();
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

bool get usesLocalFirebaseEmulators => const String.fromEnvironment('ANDICARPET_EMULATOR_HOST').isNotEmpty;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await _initializeFirebaseForPlatform();
}

