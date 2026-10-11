part of '../main.dart';

class _VerifiedLocationFix {
  final String id;
  final double? latitude;
  final double? longitude;
  final LocationStatus? status;
  final String verifiedAddress;
  final String source = 'Google Maps / verificare web';
  final String confidence;
  final String note;
  const _VerifiedLocationFix({
    required this.id,
    this.latitude,
    this.longitude,
    this.status,
    required this.verifiedAddress,
    this.confidence = 'ridicată',
    this.note = '',
  });

  bool get hasGps => latitude != null && longitude != null;
}

