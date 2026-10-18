import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final Color accent;

  const InfoCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: .14),
          child: Icon(icon, color: accent),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, color: accent),
        ),
        subtitle: Text(text),
      ),
    );
  }
}
