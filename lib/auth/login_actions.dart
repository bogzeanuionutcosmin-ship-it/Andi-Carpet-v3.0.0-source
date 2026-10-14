import 'package:firebase_auth/firebase_auth.dart';

/// Explicit operations; LoginPage retains validation, ordering and UI lifecycle.
class LoginActions {
  final Future<String> Function(String identifier, String password) resolveIdentifier;
  final Future<UserCredential> Function({required String email, required String password}) createUser;
  final Future<UserCredential> Function({required String email, required String password}) signIn;
  final Future<void> Function({required String email}) resetPassword;
  final Future<void> Function(String uid, Map<String, dynamic> data) writeProfile;

  const LoginActions({
    required this.resolveIdentifier,
    required this.createUser,
    required this.signIn,
    required this.resetPassword,
    required this.writeProfile,
  });
}
