part of '../main.dart';

// Shared serialization helpers for manual backup export and restoration.
dynamic _backupEncode(dynamic value) {
  if (value is Timestamp) return {'__type': 'timestamp', 'value': value.toDate().toIso8601String()};
  if (value is GeoPoint) return {'__type': 'geopoint', 'lat': value.latitude, 'lng': value.longitude};
  if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),_backupEncode(v)));
  if (value is List) return value.map(_backupEncode).toList();
  return value;
}

dynamic _backupDecode(dynamic value) {
  if (value is Map && value['__type'] == 'timestamp') return Timestamp.fromDate(DateTime.parse(value['value'].toString()));
  if (value is Map && value['__type'] == 'geopoint') return GeoPoint((value['lat'] as num).toDouble(),(value['lng'] as num).toDouble());
  if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),_backupDecode(v)));
  if (value is List) return value.map(_backupDecode).toList();
  return value;
}

