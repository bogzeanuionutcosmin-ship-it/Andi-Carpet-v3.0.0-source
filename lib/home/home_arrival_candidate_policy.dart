part of '../main.dart';

/// A Home geofence candidate paired with its distance from the current fix.
class HomeArrivalCandidate<T> {
  final T value;
  final double meters;

  const HomeArrivalCandidate({required this.value, required this.meters});
}

/// Keeps the existing certainty radius and nearest-location ordering for Home.
HomeArrivalCandidate<T>? nearestEligibleHomeArrivalCandidate<T>({
  required Iterable<HomeArrivalCandidate<T>> candidates,
  required double accuracyMeters,
  double radiusMeters = 250,
}) {
  final eligible = candidates
      .where((candidate) => candidate.meters + accuracyMeters <= radiusMeters)
      .toList()
    ..sort((a, b) => a.meters.compareTo(b.meters));
  return eligible.isEmpty ? null : eligible.first;
}
