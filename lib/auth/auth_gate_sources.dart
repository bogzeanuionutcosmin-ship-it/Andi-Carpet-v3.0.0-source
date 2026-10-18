import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Read-only sources used by AuthGate. Each callback is evaluated lazily.
class AuthGateSources {
  final User? Function() currentUser;
  final Stream<User?> Function() authStateChanges;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> Function()
      uiSettingsSnapshots;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String uid)
      profileSnapshots;

  const AuthGateSources({
    required this.currentUser,
    required this.authStateChanges,
    required this.uiSettingsSnapshots,
    required this.profileSnapshots,
  });
}
