part of '../main.dart';

Color sectionAccent(String label) {
  final t = label.toLowerCase();
  if (t.contains('acas') || t.contains('dashboard')) return const Color(0xff2F6BFF);
  if (t.contains('program') || t.contains('grafic')) return const Color(0xff7C4DFF);
  if (t.contains('hart') || t.contains('loca')) return const Color(0xff00A884);
  if (t.contains('centraliz')) return const Color(0xffFF8A00);
  if (t.contains('decont') || t.contains('financ')) return const Color(0xff00A86B);
  if (t.contains('document')) return const Color(0xff536DFE);
  if (t.contains('profil') || t.contains('membri') || t.contains('cont')) return const Color(0xffD14D8B);
  if (t.contains('echip')) return const Color(0xff1565C0);
  if (t.contains('maș') || t.contains('mas')) return const Color(0xff546E7A);
  if (t.contains('categorie')) return const Color(0xff00897B);
  if (t.contains('func') || t.contains('drept')) return const Color(0xff8E44AD);
  if (t.contains('learning')) return const Color(0xff6D4C41);
  if (t.contains('raport')) return const Color(0xffEF6C00);
  if (t.contains('audit') || t.contains('istoric')) return const Color(0xff455A64);
  if (t.contains('backup')) return const Color(0xff3949AB);
  if (t.contains('set') || t.contains('tem')) return const Color(0xffC47B16);
  return const Color(0xff315EA8);
}

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

