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
