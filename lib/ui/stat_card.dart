import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title, value;
  final Color accent;
  final Widget leading;

  const StatCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: .16),
                Theme.of(context).colorScheme.surface.withValues(alpha: .96),
              ],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
