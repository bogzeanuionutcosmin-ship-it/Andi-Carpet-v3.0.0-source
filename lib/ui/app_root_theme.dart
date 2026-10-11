part of '../main.dart';

class AndiCarpetaApp extends StatefulWidget {
  const AndiCarpetaApp({super.key});
  @override State<AndiCarpetaApp> createState() => _AndiCarpetaAppState();
}

class _AndiCarpetaAppState extends State<AndiCarpetaApp> {
  final settings = AppSettings();
  @override
  Widget build(BuildContext context) {
    _activeAppSettingsForBranding = settings;
    final mode = switch (settings.theme) { AppThemeChoice.light => ThemeMode.light, AppThemeChoice.dark => ThemeMode.dark, AppThemeChoice.system => ThemeMode.system };
    return MaterialApp(
      title: 'Andi Carpetă',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: AuthGate(settings: settings, onSettingsChanged: () => setState(() {})),
    );
  }
  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff315EA8), brightness: b);
    final dark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: _resolvedFontFamily(settings.fontFamily),
      scaffoldBackgroundColor: Colors.transparent,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: BorderSide(color: scheme.outline.withValues(alpha: .55)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surfaceContainerHighest.withValues(alpha: .92) : Colors.white.withValues(alpha: .99),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .75))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.error, width: 1.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface.withValues(alpha: .97),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface.withValues(alpha: .985),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outlineVariant),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outline),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface.withValues(alpha: .95),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: .55)),
    );
  }
}


