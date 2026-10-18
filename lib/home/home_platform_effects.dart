/// Explicit startup effects. HomePage retains their ordering and ownership.
class HomePlatformEffects {
  final void Function() startLocation;
  final Future<void> Function() initializePush;
  const HomePlatformEffects({required this.startLocation, required this.initializePush});
}
