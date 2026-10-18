import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/auth/firebase_user_profile.dart';
import 'package:andi_carpeta/models/app_enums.dart';

class _AuthUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  _AuthUser(this.uid, this.email);
}

class _ProfileSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  _ProfileSnapshot(this.value);
  @override
  Map<String, dynamic>? data() => value;
}

FirebaseUserProfile profile(Map<String, dynamic>? data,
        {String? email = 'auth@example.com'}) =>
    FirebaseUserProfile.fromSnapshot(
      _AuthUser('uid-1', email),
      _ProfileSnapshot(data),
    );

void main() {
  test('missing data preserves member, name and pending defaults', () {
    final result = profile(null);
    expect(result.uid, 'uid-1');
    expect(result.name, 'auth');
    expect(result.email, 'auth@example.com');
    expect(result.role, 'member');
    expect(result.active, isFalse);
    expect(result.status, 'pending');
    expect(result.function, UserFunction.worker);
    expect(result.functionIds, isEmpty);
    expect(profile(null, email: null).name, 'Utilizator');
  });

  test('admin mapping and explicit empty function IDs keep their precedence', () {
    final result = profile({'role': 'admin', 'function': 'driver', 'active': true});
    expect(result.isAdmin, isTrue);
    expect(result.name, 'Administrator');
    expect(result.function, UserFunction.director);
    expect(result.status, 'approved');
    expect(result.functionIds, ['admin']);
    expect(profile({'role': 'admin', 'functionIds': []}).functionIds, isEmpty);
  });

  test('nickname, stored email and permissive list conversion stay unchanged', () {
    final result = profile({
      'name': ' Real name ', 'nickname': ' Nick ', 'useNickname': true,
      'email': 'stored@example.com', 'function': 'developer',
      'status': 'custom', 'active': 'true',
      'functionIds': ['', 7, null, 'driver', 'driver'],
    });
    expect(result.name, 'Nick');
    expect(result.email, 'stored@example.com');
    expect(result.active, isFalse);
    expect(result.status, 'custom');
    expect(result.functionIds, ['7', 'null', 'driver', 'driver']);
    result.functionIds.add('worker');
    expect(result.functionIds.last, 'worker');
    expect(profile({'name': ' Real ', 'nickname': 'Nick'}).name, 'Real');
    expect(profile({'email': '', 'name': ''}).name, 'Utilizator');
  });

  test('function lookup remains shared with the directory adapter', () {
    expect(FirebaseUserProfile.functionFrom('driver', 'member'), UserFunction.driver);
    expect(FirebaseUserProfile.functionFrom('developer', 'member'), UserFunction.developer);
    expect(FirebaseUserProfile.functionFrom('director', 'member'), UserFunction.director);
    expect(FirebaseUserProfile.functionFrom(null, 'member'), UserFunction.worker);
    expect(FirebaseUserProfile.functionFrom('unknown', 'admin'), UserFunction.director);
  });
}
