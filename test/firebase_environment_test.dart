import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/bootstrap/firebase_environment.dart';
import 'package:andi_carpeta/firebase_options.dart';

void main() {
  Map<String,String> options()=>{'projectId':'andi-staging-test','messagingSenderId':'123456',
    'appId':'1:123456:android:test','apiKey':'test-key','storageBucket':'andi-staging-test.firebasestorage.app'};
  test('staging accepts isolated project and rejects production/missing/mixed configuration', () {
    expect(stagingFirebaseOptions(jsonEncode(options())).projectId,'andi-staging-test');
    for(final change in [{'projectId':'andicarpet-e777e'},{'messagingSenderId':'141489733149'},
      {'appId':'1:other:android:test'},{'storageBucket':'andicarpet-e777e.firebasestorage.app'},{'apiKey':''},
      for(final key in [DefaultFirebaseOptions.android.apiKey, DefaultFirebaseOptions.web.apiKey,
        DefaultFirebaseOptions.ios.apiKey]) {'apiKey':key}]) {
      expect(()=>stagingFirebaseOptions(jsonEncode({...options(),...change})),throwsFormatException);
    }
  });
  test('every backend endpoint stays on its selected Firebase project', () {
    for(final name in ['resolveLoginAlias','registerSmsGateway','disableSmsGateway','geocodeRomaniaPlace','closeProgramGraph']) {
      expect(firebaseFunctionEndpoint('andi-staging-test',name).host,'europe-central2-andi-staging-test.cloudfunctions.net');
      expect(firebaseFunctionEndpoint('demo-andi-xix',name,emulatorHost:'10.0.2.2').host,'10.0.2.2');
    }
    expect(()=>firebaseFunctionEndpoint('andicarpet-e777e','closeProgramGraph',emulatorHost:'10.0.2.2'),throwsFormatException);
    expect(()=>firebaseFunctionEndpoint('demo-andi-xix','closeProgramGraph',emulatorHost:'remote.example'),throwsFormatException);
  });
}
