import 'package:flutter/material.dart';

class FirebaseLoadingView extends StatelessWidget {
  final String text;
  final Widget logo;

  const FirebaseLoadingView({required this.text, required this.logo});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              logo,
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(text),
            ],
          ),
        ),
      );
}

class FirebaseErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onSignOut;

  const FirebaseErrorView({
    required this.message,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onSignOut,
                  child: const Text('Ieși din cont'),
                ),
              ],
            ),
          ),
        ),
      );
}
