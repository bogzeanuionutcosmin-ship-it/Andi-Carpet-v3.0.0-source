part of '../main.dart';

const String _webPushVapidKey = String.fromEnvironment(
  'FCM_WEB_VAPID_KEY',
  defaultValue: 'BMJikC3fON4-4uwRuMOzZRXYjQCbp2ftRsSt_PcBOpf9sTCv4VkwEkzxerxSZCMd5dyooMtHhU6hvLDeqWUkFHw',
);

Future<void> _initializeFirebaseForPlatform() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && !DefaultFirebaseOptions.hasIosDartConfig) {
    // Pe iOS acceptăm configurația nativă standard GoogleService-Info.plist.
    await Firebase.initializeApp();
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await _initializeFirebaseForPlatform();
}

