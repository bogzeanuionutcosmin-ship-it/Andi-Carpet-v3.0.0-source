/// Builds the existing Maps/Waze destination URI without launching it.
///
/// The caller chooses the external app and remains responsible for opening the
/// returned URI and reporting launch failures.
Uri mapNavigationUri({
  required String app,
  required double? latitude,
  required double? longitude,
  required String address,
}) {
  final useGps = latitude != null && longitude != null;
  final destination = useGps ? '$latitude,$longitude' : address;
  return app == 'maps'
      ? Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}',
        )
      : Uri.parse(
          useGps
              ? 'https://www.waze.com/ul?ll=$latitude,$longitude&navigate=yes'
              : 'https://www.waze.com/ul?q=${Uri.encodeComponent(address)}&navigate=yes',
        );
}
