import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'home_platform_sdk_fixture.dart';

// Intercepts FirebaseFirestore.instance at the platform boundary. Only the
// existing liveLocations set is permitted; other operations throw, never I/O.
class VisionLiveFirestore extends FirebaseFirestorePlatform {
  final attempts = <Map<String, dynamic>>[];
  final unexpected = <String>[];
  @override
  FirebaseFirestorePlatform delegateFor({required FirebaseApp app, required String databaseId}) => this;
  @override
  CollectionReferencePlatform collection(String path) {
    if (path != 'liveLocations') {
      unexpected.add(path);
      throw StateError('Unexpected live fixture collection');
    }
    return _LiveCollection(this, path);
  }
}
class _LiveCollection extends CollectionReferencePlatform {
  final VisionLiveFirestore owner;
  _LiveCollection(this.owner, String path) : super(owner, path);
  @override
  DocumentReferencePlatform doc([String? id]) {
    if (id == null) throw StateError('No auto-ID allowed');
    return _LiveDocument(owner, '$path/$id');
  }
}
class _LiveDocument extends DocumentReferencePlatform {
  final VisionLiveFirestore owner;
  _LiveDocument(this.owner, String path) : super(owner, path);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    owner.attempts.add({'path': path, 'data': Map<String, dynamic>.from(data), 'merge': options?.merge});
  }
}

class VisionLiveGps extends HomeGpsSdkFixture {
  final settingsHistory = <LocationSettings?>[];
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settingsHistory.add(locationSettings);
    return super.getPositionStream(locationSettings: locationSettings);
  }
}
Position syntheticPosition(double latitude) => Position(
  latitude: latitude, longitude: 26, timestamp: DateTime.now(),
  accuracy: 100, altitude: 0, altitudeAccuracy: 0,
  heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
);
