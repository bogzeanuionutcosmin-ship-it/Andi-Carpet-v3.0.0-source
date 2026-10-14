import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppBackdrop extends StatelessWidget {
  final Color plainBackground;
  final String? bundledAsset;
  final String? customBackgroundBase64;
  final double backgroundOpacity;
  final Widget child;

  const AppBackdrop({
    required this.plainBackground,
    required this.bundledAsset,
    required this.customBackgroundBase64,
    required this.backgroundOpacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? customBytes;
    if (customBackgroundBase64 != null) {
      try {
        customBytes = base64Decode(customBackgroundBase64!);
      } catch (_) {}
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: plainBackground),
        if (bundledAsset != null)
          Positioned.fill(
            child: Opacity(
              opacity: backgroundOpacity.clamp(0.0, 0.70).toDouble(),
              child: Image.asset(
                bundledAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        if (customBytes != null)
          Positioned.fill(
            child: Opacity(
              opacity: backgroundOpacity.clamp(0.0, 0.70).toDouble(),
              child: Image.memory(
                customBytes,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        // Strat subtil de contrast. Ajută textele/cardurile pe fundaluri foarte luminoase.
        if (Theme.of(context).brightness == Brightness.light)
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: .10)),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}
