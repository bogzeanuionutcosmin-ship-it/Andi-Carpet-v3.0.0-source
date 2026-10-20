import 'package:latlong2/latlong.dart';

/// Accepts real geographic coordinates and rejects the uninitialized GPS origin.
bool isValidMapPoint(LatLng point) =>
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude >= -90 &&
    point.latitude <= 90 &&
    point.longitude >= -180 &&
    point.longitude <= 180 &&
    !(point.latitude == 0 && point.longitude == 0);
