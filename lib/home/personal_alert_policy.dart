/// Categorizes a personal alert using the existing title/message substring policy.
String personalAlertCategory(String title, String message) {
  final text = '$title $message'.toLowerCase();
  if (text.contains('diurn') ||
      text.contains('decont') ||
      text.contains('cheltu')) {
    return 'decont';
  }
  if (text.contains('sosir') ||
      text.contains('locați') ||
      text.contains('locati') ||
      text.contains('gps')) {
    return 'arrival';
  }
  if (text.contains('learning') ||
      text.contains('estim') ||
      text.contains('recomand')) {
    return 'learning';
  }
  if (text.contains('grafic') ||
      text.contains('program') ||
      text.contains('traseu') ||
      text.contains('plan')) {
    return 'schedule';
  }
  return 'general';
}

/// Applies personal alert preferences while retaining mandatory system/admin
/// title bypasses and the existing allow-by-default behavior.
bool allowsPersonalAlert({
  required String title,
  required String message,
  required Map<String, bool> preferences,
}) {
  final normalizedTitle = title.trim().toLowerCase();
  if (normalizedTitle == 'sistem' || normalizedTitle.contains('admin')) {
    return true;
  }
  return preferences[personalAlertCategory(title, message)] ?? true;
}
