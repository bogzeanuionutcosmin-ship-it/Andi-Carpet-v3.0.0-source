import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_enums.dart';

class FirebaseUserProfile {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool active;
  final String status;
  final UserFunction function;
  final List<String> functionIds;

  const FirebaseUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.status,
    required this.function,
    required this.functionIds,
  });

  bool get isAdmin => role == 'admin';

  static UserFunction functionFrom(String? value, String role) {
    if (role == 'admin') return UserFunction.director;
    return switch (value) {
      'driver' => UserFunction.driver,
      'developer' => UserFunction.developer,
      'director' => UserFunction.director,
      _ => UserFunction.worker,
    };
  }

  factory FirebaseUserProfile.fromSnapshot(User authUser, DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    final role = (data['role'] ?? 'member').toString();
    final email = (data['email'] ?? authUser.email ?? '').toString();
    var name = (data['name'] ?? '').toString().trim();
    final nickname = (data['nickname'] ?? '').toString().trim();
    final useNickname = data['useNickname'] == true;
    if (useNickname && nickname.isNotEmpty) name = nickname;
    if (name.isEmpty) name = role == 'admin' ? 'Administrator' : (email.isEmpty ? 'Utilizator' : email.split('@').first);
    return FirebaseUserProfile(
      uid: authUser.uid,
      name: name,
      email: email,
      role: role,
      active: data['active'] == true,
      status: (data['status'] ?? (data['active'] == true ? 'approved' : 'pending')).toString(),
      function: functionFrom(data['function']?.toString(), role),
      functionIds: data['functionIds'] is List
          ? (data['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : <String>[(role == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList(),
    );
  }
}

