/// Display ordering only; pending status does not grant administrative rights.
int compareAdminAccountData(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ap = (a['status'] ?? '').toString() == 'pending';
  final bp = (b['status'] ?? '').toString() == 'pending';
  if (ap != bp) return ap ? -1 : 1;
  return (a['name'] ?? a['email'] ?? '').toString().compareTo((b['name'] ?? b['email'] ?? '').toString());
}

/// Retains the existing list/legacy fallback, conversion and empty-ID behavior.
/// The returned set is independent; no role or permission is calculated here.
Set<String> adminAssignedFunctionIds(Map<String, dynamic> data) =>
    data['functionIds'] is List
        ? (data['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toSet()
        : <String>{(data['function'] ?? '').toString()}.where((e) => e.isNotEmpty).toSet();
