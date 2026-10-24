part of '../main.dart';

/// Projects each user's current team ID using the existing first-team match.
///
/// Team order and membership are authoritative here; inactive teams are not
/// filtered because the HomePage's current assignment doesn't filter them.
List<String?> projectHomeTeamMembership({
  required Iterable<String> userIds,
  required Iterable<Team> teams,
}) {
  final teamIdByMember = <String, String>{};
  for (final team in teams) {
    for (final memberId in team.members) {
      teamIdByMember.putIfAbsent(memberId, () => team.id);
    }
  }
  return userIds.map((userId) => teamIdByMember[userId]).toList();
}
