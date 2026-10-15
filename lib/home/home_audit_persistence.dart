part of '../main.dart';

// Auditul la distanță și persistarea batch, mutate fără schimbări de logică.
// Dispose, permisiunile și contextul HomePage rămân în clasa State.
extension _HomeAuditPersistence on _HomePageState {
  Future<void> _writeAuditRemote(String action, String target) async {
    final entry = AuditEntry(id: idNow(), actor: me.name, action: action, target: target, at: DateTime.now());
    if (isAdmin && mounted) {
      setState(() => audit.insert(0, entry));
    }
    try {
      await FirebaseFirestore.instance.collection('audit').doc(entry.id).set({
        'actorUid': currentUserId,
        'actor': me.name,
        'action': action,
        'target': target,
        'at': Timestamp.fromDate(entry.at),
      });
      unawaited(_writeLearningEvent(category: 'operations', event: 'audit_action', data: {'action': action, 'target': target}));
    } catch (_) {
      // Auditul nu trebuie să blocheze operația principală; eroarea poate fi urmărită separat.
    }
  }

  Future<void> _persistCoreData() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final pendingLocations = <String, String>{};
    final pendingTeams = <String, String>{};
    final pendingCars = <String, String>{};
    final pendingUsers = <String, String?>{};
    var writes = 0;

    for (final l in locations) {
      final data = _locationMap(l);
      final encoded = _encoded(data);
      if (_locationCache[l.id] != encoded) {
        batch.set(db.collection('locations').doc(l.id), data, SetOptions(merge: true));
        pendingLocations[l.id] = encoded;
        writes++;
      }
    }

    for (final t in teams) {
      final data = _teamMap(t);
      final encoded = _encoded(data);
      if (_teamCache[t.id] != encoded) {
        batch.set(db.collection('teams').doc(t.id), data, SetOptions(merge: true));
        pendingTeams[t.id] = encoded;
        writes++;
      }
    }

    for (final c in cars) {
      final data = _carMap(c);
      final encoded = _encoded(data);
      if (_carCache[c.id] != encoded) {
        batch.set(db.collection('cars').doc(c.id), data, SetOptions(merge: true));
        pendingCars[c.id] = encoded;
        writes++;
      }
    }

    for (final u in users) {
      if (_userTeamCache[u.id] != u.teamId) {
        batch.set(db.collection('users').doc(u.id), {'teamId': u.teamId}, SetOptions(merge: true));
        pendingUsers[u.id] = u.teamId;
        writes++;
      }
    }

    if (writes == 0) return;
    await batch.commit();
    _locationCache.addAll(pendingLocations);
    _teamCache.addAll(pendingTeams);
    _carCache.addAll(pendingCars);
    _userTeamCache.addAll(pendingUsers);
  }

}
