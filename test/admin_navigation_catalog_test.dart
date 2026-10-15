import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/admin/admin_navigation_catalog.dart';

void main() {
  test('keeps the existing admin section icons and grouping', () {
    const icons = <IconData>[
      Icons.dashboard,
      Icons.groups,
      Icons.people,
      Icons.directions_car,
      Icons.location_on,
      Icons.category_outlined,
      Icons.calendar_month,
      Icons.table_chart,
      Icons.receipt_long,
      Icons.auto_graph,
      Icons.document_scanner,
      Icons.notifications,
      Icons.assessment,
      Icons.history,
      Icons.security,
      Icons.palette_outlined,
      Icons.backup,
    ];
    const groups = <String>[
      'Operațional', 'Operațional', 'Operațional', 'Operațional',
      'Operațional', 'Operațional', 'Operațional', 'Operațional',
      'Financiar', 'Learning', 'Learning', 'Administrare', 'Sistem',
      'Sistem', 'Administrare', 'Sistem', 'Sistem',
    ];

    for (var index = 0; index < icons.length; index++) {
      expect(adminSectionIcon(index), icons[index]);
      expect(adminSectionGroup(index), groups[index]);
    }
    expect(() => adminSectionIcon(icons.length), throwsRangeError);
  });

  test('keeps the current section asset mapping', () {
    const assets = <String?>[
      'assets/ui/tab_dashboard.png',
      'assets/ui/teams.png',
      'assets/ui/members.png',
      null,
      'assets/ui/tab_harta.png',
      null,
      'assets/ui/tab_grafic.png',
      'assets/ui/tab_centralizator.png',
      'assets/ui/tab_decont.png',
      null,
      null,
      null,
      'assets/ui/tab_centralizator.png',
      null,
      'assets/ui/security.png',
      null,
      null,
    ];

    for (var index = 0; index < assets.length; index++) {
      expect(adminSectionAsset(index), assets[index]);
    }
  });
}
