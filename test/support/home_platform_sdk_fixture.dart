import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'home_sync_fixture.dart';

// These fakes replace the plugin boundary, not Home's GPS/FCM methods.
// No coordinates/tokens reach HTTP or Firestore: initial location is denied,
// and FCM tests stop at permission failure or a null/empty token.
class HomeGpsSdkFixture extends GeolocatorPlatform {
  final trace = <String>[];
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.denied;
  Future<bool>? enabledResult;
  bool enabled = true;
  int checks = 0, starts = 0, cancels = 0;
  LocationSettings? streamSettings;
  late final positions = StreamController<Position>.broadcast(
    onListen: () { starts++; trace.add('listen'); },
    onCancel: () { cancels++; trace.add('cancel'); },
  );
  @override
  Future<LocationPermission> checkPermission() async {
    trace.add('check');
    // _shareLiveLocationIfAllowed starts first; stop before live I/O.
    return ++checks == 1 ? LocationPermission.denied : permission;
  }
  @override
  Future<LocationPermission> requestPermission() async {
    trace.add('request');
    return requestedPermission;
  }
  @override
  Future<bool> isLocationServiceEnabled() {
    trace.add('enabled');
    return enabledResult ?? Future<bool>.value(enabled);
  }
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    trace.add('stream');
    streamSettings = locationSettings;
    return positions.stream;
  }
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    trace.add('UNEXPECTED current position');
    throw StateError('Live location path must remain blocked in this fixture');
  }
}

class _FixtureNotificationSettings extends Fake implements NotificationSettings {
  final AuthorizationStatus status;
  _FixtureNotificationSettings(this.status);
  @override
  AuthorizationStatus get authorizationStatus => status;
}

class HomeFcmSdkFixture extends FirebaseMessagingPlatform {
  final trace = <String>[];
  AuthorizationStatus status = AuthorizationStatus.denied;
  AuthorizationStatus requestStatus = AuthorizationStatus.denied;
  Future<String?>? tokenResult;
  String? token;
  void reset() {
    trace.clear(); status = AuthorizationStatus.denied;
    requestStatus = AuthorizationStatus.denied; tokenResult = null; token = null;
  }
  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  Future<NotificationSettings> getNotificationSettings() async {
    trace.add('permission');
    return _FixtureNotificationSettings(status);
  }
  @override
  Future<NotificationSettings> requestPermission({bool alert = true,
    bool announcement = false, bool badge = true, bool carPlay = false,
    bool criticalAlert = false, bool provisional = false, bool sound = true,
    bool providesAppNotificationSettings = false}) async {
    trace.add('request:$alert:$badge:$sound');
    return _FixtureNotificationSettings(requestStatus);
  }
  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) {
    trace.add('token');
    return tokenResult ?? Future<String?>.value(token);
  }
  @override
  Stream<String> get onTokenRefresh {
    trace.add('UNEXPECTED refresh attachment');
    throw StateError('A usable token would leave this no-write fixture');
  }
  @override
  Future<RemoteMessage?> getInitialMessage() {
    trace.add('UNEXPECTED initial message');
    throw StateError('A usable token would leave this no-write fixture');
  }
}

class PlatformSdkHomePage extends HomePage {
  PlatformSdkHomePage({required HomeSyncFixture sync}) : super(
    key: const ValueKey('platform-sdk-a'), profile: fixtureHomeProfile('a'),
    settings: AppSettings()..autoCloseWhenAllDone = false,
    onSettingsChanged: () {}, syncFirestore: sync,
  );
  @override
  StatefulElement createElement() => _PlatformSdkHomeElement(this);
}

class _PlatformSdkHomeElement extends StatefulElement {
  _PlatformSdkHomeElement(PlatformSdkHomePage widget) : super(widget);
  @override
  Widget build() => const SizedBox();
}
