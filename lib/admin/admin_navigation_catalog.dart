part of '../main.dart';

// Navigation metadata shared by the admin drawer and dashboard.
IconData _adminSectionIcon(int i) => const [
  Icons.dashboard, Icons.groups, Icons.people, Icons.directions_car, Icons.location_on, Icons.category_outlined,
  Icons.calendar_month, Icons.table_chart, Icons.receipt_long, Icons.auto_graph, Icons.document_scanner,
  Icons.notifications, Icons.assessment, Icons.history, Icons.security, Icons.palette_outlined, Icons.backup,
][i];

String _adminSectionGroup(int i) {
  if (i <= 7) return 'Operațional';
  if (i == 8) return 'Financiar';
  if (i == 9 || i == 10) return 'Learning';
  if (i == 11 || i == 14) return 'Administrare';
  return 'Sistem';
}

String? _adminSectionAsset(int i) => switch (i) {
  0 => 'assets/ui/tab_dashboard.png',
  1 => 'assets/ui/teams.png',
  2 => 'assets/ui/members.png',
  4 => 'assets/ui/tab_harta.png',
  6 => 'assets/ui/tab_grafic.png',
  7 => 'assets/ui/tab_centralizator.png',
  8 => 'assets/ui/tab_decont.png',
  12 => 'assets/ui/tab_centralizator.png',
  14 => 'assets/ui/security.png',
  _ => null,
};

