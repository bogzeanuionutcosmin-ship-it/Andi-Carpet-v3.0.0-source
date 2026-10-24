/// Returns the city label previously used by the Dashboard live-location UI.
///
/// Address labels prefer the last non-empty comma-separated segment when it
/// looks like a Romanian locality; otherwise the cleaned location name is used.
String dashboardLocationCityLabel({
  required String name,
  required String address,
}) {
  final fallbackName = name
      .trim()
      .replaceFirst(RegExp(r'^(million|magic)\s+', caseSensitive: false), '')
      .trim();
  final parts = address
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();

  if (parts.length >= 2) {
    final candidate = parts.last
        .replaceFirst(
          RegExp(r'^(jud\.?|județul|municipiul|orașul)\s+', caseSensitive: false),
          '',
        )
        .trim();
    if (candidate.isNotEmpty &&
        !RegExp(r'^(românia|romania|rom|\d{5,6})$', caseSensitive: false)
            .hasMatch(candidate)) {
      return candidate;
    }
  }

  return fallbackName.split(RegExp(r'[-–]')).first.trim();
}
