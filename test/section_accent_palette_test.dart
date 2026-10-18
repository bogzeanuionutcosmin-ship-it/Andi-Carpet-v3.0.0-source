import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/ui/section_accent_palette.dart';

void main() {
  test('all existing section labels keep their exact accent colors', () {
    const cases = <String, int>{
      'Acasă': 0xff2F6BFF,
      'Dashboard': 0xff2F6BFF,
      'Program': 0xff7C4DFF,
      'Grafic': 0xff7C4DFF,
      'Hartă': 0xff00A884,
      'Locații': 0xff00A884,
      'Centralizator': 0xffFF8A00,
      'Decont': 0xff00A86B,
      'Financiar': 0xff00A86B,
      'Documente': 0xff536DFE,
      'Profil': 0xffD14D8B,
      'Membri': 0xffD14D8B,
      'Echipe': 0xff1565C0,
      'Mașini': 0xff546E7A,
      'Categorie': 0xff00897B,
      'Funcții': 0xff8E44AD,
      'Learning': 0xff6D4C41,
      'Raport': 0xffEF6C00,
      'Rapoarte': 0xff315EA8,
      'Audit': 0xff455A64,
      'Backup': 0xff3949AB,
      'Setări': 0xffC47B16,
      'Necunoscut': 0xff315EA8,
    };
    for (final entry in cases.entries) {
      expect(sectionAccent(entry.key), Color(entry.value), reason: entry.key);
      expect(app.sectionAccent(entry.key), Color(entry.value), reason: 'main.dart: ${entry.key}');
    }
  });

  test('matching remains case insensitive with ordered precedence', () {
    expect(sectionAccent('DASHBOARD'), const Color(0xff2F6BFF));
    expect(sectionAccent('program și hartă'), const Color(0xff7C4DFF));
    expect(sectionAccent('financiar și documente'), const Color(0xff00A86B));
    expect(sectionAccent(''), const Color(0xff315EA8));
  });
}
