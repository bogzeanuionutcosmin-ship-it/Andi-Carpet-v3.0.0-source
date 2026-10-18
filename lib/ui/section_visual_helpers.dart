part of '../main.dart';

void showSuccessMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: const Color(0xff087F5B),
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
      duration: const Duration(seconds: 3),
    ));
}

void showErrorMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: const Color(0xffB42318),
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
      duration: const Duration(seconds: 4),
    ));
}

Color _plainBackgroundColor(AppSettings settings, Brightness brightness) {
  if (brightness == Brightness.dark) return const Color(0xff111318);
  return switch (settings.background) {
    'Alb simplu' => Colors.white,
    'Gri deschis' => const Color(0xffeef0f3),
    'Albastru discret' => const Color(0xffeef5fb),
    'Imagine / logo' => const Color(0xfffffbf3),
    _ => const Color(0xfff5f6f8),
  };
}

