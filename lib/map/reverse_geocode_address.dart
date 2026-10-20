/// Builds the same concise Romanian address label from a Nominatim reverse
/// response, falling back to its display name when address parts are missing.
String? parseNominatimReverseAddress(Map<dynamic, dynamic> decoded) {
  final address = decoded['address'];
  if (address is Map) {
    String first(List<String> keys) {
      for (final key in keys) {
        final value = address[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final road = first(['road', 'pedestrian', 'residential', 'footway', 'path']);
    final number = first(['house_number']);
    final locality = first(['city', 'town', 'municipality', 'village', 'suburb']);
    final county = first(['county']);
    final parts = <String>[];
    final street = [road, number].where((value) => value.isNotEmpty).join(' ');
    if (street.isNotEmpty) parts.add(street);
    if (locality.isNotEmpty && !parts.contains(locality)) parts.add(locality);
    if (county.isNotEmpty && county != locality) parts.add(county);
    if (parts.isNotEmpty) return parts.join(', ');
  }

  final display = decoded['display_name']?.toString().trim() ?? '';
  return display.isEmpty ? null : display;
}
