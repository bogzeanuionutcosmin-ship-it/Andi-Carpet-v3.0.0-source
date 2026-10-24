import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

const productionFirebaseProject = 'andicarpet-e777e';

/// Staging configuration has no fallback to the production defaults.
FirebaseOptions stagingFirebaseOptions(String encoded) {
  final raw = jsonDecode(encoded);
  if (raw is! Map) throw const FormatException('Configurație staging invalidă.');
  String field(String key) {
    final value=raw[key];
    if(value is! String || value.isEmpty) throw FormatException('Staging: lipsește $key.');
    return value;
  }
  final project=field('projectId'), sender=field('messagingSenderId'), appId=field('appId');
  if(!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(project) ||
      !project.contains('staging') || project == productionFirebaseProject ||
      sender == '141489733149' || !RegExp(r'^\d+$').hasMatch(sender) ||
      !appId.startsWith('1:$sender:android:')) {
    throw const FormatException('Staging trebuie să folosească un proiect și o aplicație Android separate.');
  }
  final bucket=field('storageBucket');
  if(!['$project.firebasestorage.app','$project.appspot.com'].contains(bucket)) {
    throw const FormatException('Storage staging nu corespunde proiectului.');
  }
  final apiKey=field('apiKey');
  if ([DefaultFirebaseOptions.android.apiKey, DefaultFirebaseOptions.web.apiKey,
      DefaultFirebaseOptions.ios.apiKey].contains(apiKey)) {
    throw const FormatException('Cheia Firebase de producție nu poate fi folosită în staging.');
  }
  return FirebaseOptions(apiKey:apiKey,appId:appId,
    messagingSenderId:sender,projectId:project,storageBucket:bucket);
}

Uri firebaseFunctionEndpoint(String project, String function, {String emulatorHost=''}) {
  if(!RegExp(r'^[a-z][a-z0-9-]+$').hasMatch(project) ||
      !RegExp(r'^[A-Za-z][A-Za-z0-9]+$').hasMatch(function)) {
    throw const FormatException('Adresă backend invalidă.');
  }
  if(emulatorHost.isNotEmpty) {
    if(!['10.0.2.2','127.0.0.1','localhost'].contains(emulatorHost) || !project.startsWith('demo-')) {
      throw const FormatException('Emulatorul necesită un proiect demo local.');
    }
    return Uri.parse('http://$emulatorHost:5001/$project/europe-central2/$function');
  }
  return Uri.https('europe-central2-$project.cloudfunctions.net','/$function');
}
