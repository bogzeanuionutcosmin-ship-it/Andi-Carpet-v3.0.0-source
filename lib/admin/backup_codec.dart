import 'package:cloud_firestore/cloud_firestore.dart';

// Shared serialization helpers for manual backup export and restoration.
dynamic encodeBackupValue(dynamic value) {
  if (value is Timestamp) return {'__type': 'timestamp', 'value': value.toDate().toIso8601String()};
  if (value is GeoPoint) return {'__type': 'geopoint', 'lat': value.latitude, 'lng': value.longitude};
  if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),encodeBackupValue(v)));
  if (value is List) return value.map(encodeBackupValue).toList();
  return value;
}

dynamic decodeBackupValue(dynamic value) {
  if (value is Map && value['__type'] == 'timestamp') return Timestamp.fromDate(DateTime.parse(value['value'].toString()));
  if (value is Map && value['__type'] == 'geopoint') return GeoPoint((value['lat'] as num).toDouble(),(value['lng'] as num).toDouble());
  if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),decodeBackupValue(v)));
  if (value is List) return value.map(decodeBackupValue).toList();
  return value;
}

