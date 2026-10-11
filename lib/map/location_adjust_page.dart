part of '../main.dart';

class LocationAdjustPage extends StatefulWidget {
  final Location location;
  final Color color;
  const LocationAdjustPage({super.key, required this.location, required this.color});

  @override
  State<LocationAdjustPage> createState() => _LocationAdjustPageState();
}

class _LocationAdjustPageState extends State<LocationAdjustPage> {
  late final MapController _controller;
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _center = LatLng(widget.location.latitude ?? 45.9432, widget.location.longitude ?? 24.9668);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajustează · ${widget.location.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mută harta cu degetul până când pinul fix din centru ajunge exact pe locația corectă, apoi apasă Salvează.', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Coordonate curente: ${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}'),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 17,
                    onPositionChanged: (position, _) {
                      if (mounted) setState(() => _center = position.center);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kMapTileUrl,
                      userAgentPackageName: 'com.example.andi_carpeta',
                    ),
                    RichAttributionWidget(attributions: [TextSourceAttribution(kMapboxEnabled ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap contributors')]),
                  ],
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 50, color: widget.color),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(context, _center), icon: const Icon(Icons.save_outlined), label: const Text('Salvează poziția'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

