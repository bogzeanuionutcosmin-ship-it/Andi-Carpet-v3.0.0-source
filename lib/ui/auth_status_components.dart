part of '../main.dart';

class _FirebaseLoading extends StatelessWidget {
  final String text;
  final AppSettings settings;
  const _FirebaseLoading({required this.text, required this.settings});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    appBrandLogo(settings, width: 520, height: 130),
    const SizedBox(height: 24),
    const CircularProgressIndicator(),
    const SizedBox(height: 12),
    Text(text),
  ])));
}

class _FirebaseError extends StatelessWidget {
  final String message;
  const _FirebaseError({required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    FilledButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Ieși din cont')),
  ]))));
}

