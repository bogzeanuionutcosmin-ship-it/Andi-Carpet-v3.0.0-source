import 'package:flutter/material.dart';

import 'vision_assistant_avatar.dart';

/// An isolated, offline-only visual test harness for the Vision mascot.
///
/// This screen is NOT linked from AndiCarpet's authenticated application.
/// It does not read diagnostics, connect to Firebase, send messages or
/// represent a functioning assistant. The controls affect appearance only.
class VisionAvatarPreviewApp extends StatefulWidget {
  const VisionAvatarPreviewApp({super.key});

  @override
  State<VisionAvatarPreviewApp> createState() =>
      _VisionAvatarPreviewAppState();
}

class _VisionAvatarPreviewAppState extends State<VisionAvatarPreviewApp> {
  bool _dark = false;
  double _size = 112;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    );
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Vision — previzualizare offline',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Vision · corpul asistentului'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Previzualizare locală a mascotei. '
                'Acesta este doar corpul grafic, nu un asistent activ.',
                key: Key('vision-preview-disclaimer'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('vision-preview-theme-toggle'),
                title: const Text('Temă întunecată'),
                value: _dark,
                onChanged: (value) => setState(() => _dark = value),
              ),
              const SizedBox(height: 12),
              Text(
                'Dimensiune',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final choice in const <double>[64, 112, 176])
                    ChoiceChip(
                      key: Key('vision-preview-size-${choice.toInt()}'),
                      label: Text('${choice.toInt()}'),
                      selected: _size == choice,
                      onSelected: (_) => setState(() => _size = choice),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  height: 208,
                  child: Center(
                    child: VisionAssistantAvatar(size: _size),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fără animații, acces la date sau conexiune la server. '
                'Mișcările și poziționarea în aplicație vor fi decise separat.',
                key: Key('vision-preview-offline-note'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
