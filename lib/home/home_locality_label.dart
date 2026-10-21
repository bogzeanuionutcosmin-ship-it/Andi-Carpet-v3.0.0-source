/// Projects the address fields returned by the existing live Nominatim lookup
/// into the locality label shown by Home.
String liveLocalityLabelFromAddress(Map<dynamic, dynamic> address) {
  String first(List<String> keys) {
    for (final key in keys) {
      final value = address[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  final city = first(['city', 'town', 'municipality', 'village']);
  final county = first(['county', 'state']);
  if (city.isNotEmpty &&
      county.isNotEmpty &&
      city.toLowerCase() != county.toLowerCase()) {
    return '$city · $county';
  }
  return city.isNotEmpty ? city : county;
}
