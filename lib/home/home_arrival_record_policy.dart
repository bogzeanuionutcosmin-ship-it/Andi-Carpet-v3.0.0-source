part of '../main.dart';

/// Preserves the existing Home geofence guard against duplicate arrival writes.
/// Running, waiting, and genuinely completed records are not overwritten.
bool canWriteHomeArrivalChoice(CentralizerRecord? existing) =>
    existing?.status != WorkAttemptStatus.running &&
    existing?.status != WorkAttemptStatus.waitingAccess &&
    existing?.completed != true;
