part of '../main.dart';

class _AppBackdrop extends StatelessWidget {
  final AppSettings settings;
  final Widget child;
  const _AppBackdrop({required this.settings, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final selected = settings.brandingBackgroundId;
    final bundledAsset = _bundledBackgroundAssets[selected];
    final customId = selected.startsWith('custom:') ? selected.substring('custom:'.length) : '';
    final customData = customId.isEmpty ? null : settings.customBackgrounds[customId];
    Uint8List? customBytes;
    if (customData != null) {
      try { customBytes = base64Decode(customData['imageBase64'] ?? ''); } catch (_) {}
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _plainBackgroundColor(settings, brightness)),
        if (bundledAsset != null)
          Positioned.fill(
            child: Opacity(
              opacity: settings.backgroundOpacity.clamp(0.0, 0.70).toDouble(),
              child: Image.asset(bundledAsset, fit: BoxFit.cover, alignment: Alignment.center),
            ),
          ),
        if (customBytes != null)
          Positioned.fill(
            child: Opacity(
              opacity: settings.backgroundOpacity.clamp(0.0, 0.70).toDouble(),
              child: Image.memory(customBytes, fit: BoxFit.cover, alignment: Alignment.center),
            ),
          ),
        // Strat subtil de contrast. Ajută textele/cardurile pe fundaluri foarte luminoase.
        if (brightness == Brightness.light)
          Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: .10))),
        Positioned.fill(child: child),
      ],
    );
  }
}

