part of '../main.dart';

extension LocationStatusX on LocationStatus {
  String get label => switch (this) {
        LocationStatus.open => 'Locație deschisă',
        LocationStatus.temporarilyClosed => 'Închisă temporar',
        LocationStatus.permanentlyClosed => 'Închisă definitiv',
      };
  IconData get icon => switch (this) {
        LocationStatus.open => Icons.check_circle_outline,
        LocationStatus.temporarilyClosed => Icons.pause_circle_outline,
        LocationStatus.permanentlyClosed => Icons.cancel_outlined,
      };
  Color get color => switch (this) {
        LocationStatus.open => Colors.green,
        LocationStatus.temporarilyClosed => Colors.orange,
        LocationStatus.permanentlyClosed => Colors.redAccent,
      };
}

class LocationCategory {
  final String id;
  String name;
  int colorValue;
  bool active;
  LocationCategory({required this.id, required this.name, required this.colorValue, this.active = true});
  Color get color => Color(colorValue);
}

class FunctionDefinition {
  final String id;
  String name;
  String iconKey; // compatibilitate cu versiunea veche; primul ecuson devine iconKey
  List<String> badgeKeys;
  int colorValue;
  Set<String> permissions;
  bool active;
  FunctionDefinition({
    required this.id,
    required this.name,
    required this.iconKey,
    List<String>? badgeKeys,
    required this.colorValue,
    Set<String>? permissions,
    this.active = true,
  })  : badgeKeys = (badgeKeys == null || badgeKeys.isEmpty
            ? <String>[iconKey]
            : badgeKeys.where((e) => e.trim().isNotEmpty).take(3).toList()),
        permissions = permissions ?? <String>{} {
    if (this.badgeKeys.isNotEmpty) {
      iconKey = this.badgeKeys.first;
    }
  }
  Color get color => Color(colorValue);
}

