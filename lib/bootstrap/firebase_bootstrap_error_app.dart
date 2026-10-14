import 'package:flutter/material.dart';

class FirebaseBootstrapErrorView extends StatelessWidget {
  final String message;
  const FirebaseBootstrapErrorView({required this.message});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_outlined, size: 58),
                const SizedBox(height: 16),
                const Text('Firebase nu este configurat pentru această platformă', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Pe iOS adaugă GoogleService-Info.plist sau construiește aplicația cu valorile FIREBASE_IOS_API_KEY și FIREBASE_IOS_APP_ID. Web și Android folosesc configurația inclusă în proiect.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                SelectableText(message, textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

