import 'package:flutter/material.dart';

/// The visual *body* of Vision, deliberately not an AI runtime or chat agent.
///
/// This is a static, theme-aware vector illustration. It makes no network
/// requests, never accesses device-wide diagnostics and has no animation
/// controller, timer, gesture, overlay or hidden background process.
///
/// The host screen must separately enforce authentication and ownership.
/// Appearance and later animations can be reviewed without touching Vision
/// persistence, financial flows or the authenticated Navigator.
class VisionAssistantAvatar extends StatelessWidget {
  const VisionAssistantAvatar({
    super.key,
    this.size = 96,
  }) : assert(size > 0);

  /// Square illustration size in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Semantics(
        label: 'Vision, asistent grafic',
        image: true,
        child: CustomPaint(
          key: const Key('vision-assistant-avatar-artwork'),
          painter: _VisionBodyPainter(
            accent: colors.primary,
            face: colors.surface,
            ink: colors.onSurface,
            outline: colors.outline,
          ),
        ),
      ),
    );
  }
}

class _VisionBodyPainter extends CustomPainter {
  const _VisionBodyPainter({
    required this.accent,
    required this.face,
    required this.ink,
    required this.outline,
  });

  final Color accent;
  final Color face;
  final Color ink;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    // Work in a fixed 100x100 vector coordinate system so small/large avatars
    // share the same geometry without image assets or pixel assumptions.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final halo = Paint()..color = accent.withValues(alpha: 0.10);
    final shell = Paint()..color = accent;
    final facePaint = Paint()..color = face;
    final inkPaint = Paint()..color = ink;
    final line = Paint()
      ..color = outline
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final limbs = Paint()
      ..color = accent
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(const Offset(50, 49), 44, halo);

    // Antenna and a small status orb are decorative only, not a status light
    // asserting connection, device health, or server synchronization.
    canvas.drawLine(const Offset(50, 20), const Offset(50, 12), limbs);
    canvas.drawCircle(const Offset(50, 9), 4, shell);

    // Arms and feet behind the main shell. Pose is intentionally static;
    // waving, falling, dancing and other animations are future decisions.
    final leftArm = Path()
      ..moveTo(33, 65)
      ..lineTo(22, 76)
      ..lineTo(18, 72);
    final rightArm = Path()
      ..moveTo(67, 65)
      ..lineTo(78, 76)
      ..lineTo(82, 72);
    canvas.drawPath(leftArm, limbs);
    canvas.drawPath(rightArm, limbs);
    canvas.drawLine(const Offset(40, 84), const Offset(38, 92), limbs);
    canvas.drawLine(const Offset(60, 84), const Offset(62, 92), limbs);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(31, 56, 38, 29), const Radius.circular(12)),
      shell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 64, 22, 12), const Radius.circular(6)),
      facePaint,
    );
    canvas.drawCircle(const Offset(45, 70), 2.6, inkPaint);
    canvas.drawCircle(const Offset(55, 70), 2.6, inkPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 33, 9, 12), const Radius.circular(4)),
      shell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(74, 33, 9, 12), const Radius.circular(4)),
      shell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 19, 60, 39), const Radius.circular(14)),
      shell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 25, 48, 27), const Radius.circular(10)),
      facePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 25, 48, 27), const Radius.circular(10)),
      line,
    );
    canvas.drawCircle(const Offset(39, 37), 3.3, inkPaint);
    canvas.drawCircle(const Offset(61, 37), 3.3, inkPaint);
    final smile = Path()
      ..moveTo(44, 44)
      ..quadraticBezierTo(50, 49, 56, 44);
    canvas.drawPath(smile, Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VisionBodyPainter oldDelegate) =>
      accent != oldDelegate.accent ||
      face != oldDelegate.face ||
      ink != oldDelegate.ink ||
      outline != oldDelegate.outline;
}
