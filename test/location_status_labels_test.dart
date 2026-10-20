import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/models/location_status_and_functions.dart';

void main() {
  test('location status labels, icons, and colors preserve each existing mapping', () {
    expect(LocationStatus.open.label, 'Locație deschisă');
    expect(LocationStatus.open.icon.codePoint, Icons.check_circle_outline.codePoint);
    expect(LocationStatus.open.color, Colors.green);

    expect(LocationStatus.temporarilyClosed.label, 'Închisă temporar');
    expect(LocationStatus.temporarilyClosed.icon.codePoint,
        Icons.pause_circle_outline.codePoint);
    expect(LocationStatus.temporarilyClosed.color, Colors.orange);

    expect(LocationStatus.permanentlyClosed.label, 'Închisă definitiv');
    expect(LocationStatus.permanentlyClosed.icon.codePoint,
        Icons.cancel_outlined.codePoint);
    expect(LocationStatus.permanentlyClosed.color, Colors.redAccent);
  });
}
