/// Transparent, static inventory of Vision V0 diagnostic instrumentation.
///
/// These entries are NOT a runtime health check or a guarantee of coverage.
/// Keep them in sync with the reviewed instrumentation when integrating PRs.
enum VisionCoverageState { partial, notConnected }

class VisionCoverageArea {
  const VisionCoverageArea({
    required this.name,
    required this.state,
    required this.observes,
    required this.doesNotVerify,
  });

  final String name;
  final VisionCoverageState state;
  final String observes;
  final String doesNotVerify;

  String get statusLabel => state == VisionCoverageState.partial
      ? 'Parțial instrumentat'
      : 'Neconectat la diagnosticul local';
}

class VisionDiagnosticCoverage {
  VisionDiagnosticCoverage._();

  /// Snapshot for the Vision branch based on #21.
  /// Observed errors require installed handlers and actual execution.
  static const areas = <VisionCoverageArea>[
    VisionCoverageArea(
      name: 'Flutter / Dart',
      state: VisionCoverageState.partial,
      observes: 'Excepții UI și asincrone raportate de handlerii instalați.',
      doesNotVerify: 'Fluxurile fără excepții și toate erorile de platformă.',
    ),
    VisionCoverageArea(
      name: 'GPS',
      state: VisionCoverageState.partial,
      observes: 'Eșecuri raportate la pornire, stream și actualizări.',
      doesNotVerify: 'Sosirea reală, precizia, sălile vecine sau fundalul Android.',
    ),
    VisionCoverageArea(
      name: 'Notificări FCM',
      state: VisionCoverageState.partial,
      observes: 'Erori raportate la inițializare și actualizarea tokenului.',
      doesNotVerify: 'Livrarea notificării către destinatar.',
    ),
    VisionCoverageArea(
      name: 'OCR',
      state: VisionCoverageState.partial,
      observes: 'Erori raportate la recunoaștere și salvare document.',
      doesNotVerify: 'Corectitudinea sumei ori potrivirea cu valoarea salvată.',
    ),
    VisionCoverageArea(
      name: 'Diurne / finanțe',
      state: VisionCoverageState.partial,
      observes: 'Unele eșecuri raportate la distribuire și salvare.',
      doesNotVerify: 'Soldurile, regulile server-side și istoricul financiar.',
    ),
    VisionCoverageArea(
      name: 'Firebase Functions / cloud',
      state: VisionCoverageState.notConnected,
      observes: 'Nicio colectare centralizată în acest jurnal local.',
      doesNotVerify: 'Erorile backend și alte dispozitive.',
    ),
    VisionCoverageArea(
      name: 'Izolarea conturilor',
      state: VisionCoverageState.notConnected,
      observes: 'Nicio verificare automată a sesiunii în Vision V0.',
      doesNotVerify: 'Confidențialitatea între conturi; cere teste AuthGate separate.',
    ),
  ];
}
