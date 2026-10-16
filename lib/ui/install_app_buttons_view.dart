import 'package:flutter/material.dart';

class InstallAppButtonsView extends StatelessWidget {
  final VoidCallback onAndroidPressed;
  final VoidCallback onApplePressed;
  final bool compact;

  const InstallAppButtonsView({
    required this.onAndroidPressed,
    required this.onApplePressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: onAndroidPressed,
            icon: const Icon(Icons.android),
            label: Text(
              compact ? 'Android' : 'Instalează aplicația · Android',
            ),
          ),
          OutlinedButton.icon(
            onPressed: onApplePressed,
            icon: const Icon(Icons.apple),
            label: Text(
              compact ? 'Apple' : 'Instalează aplicația · Apple',
            ),
          ),
        ],
      );
}
