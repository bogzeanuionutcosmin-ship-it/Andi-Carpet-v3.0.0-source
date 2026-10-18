part of '../main.dart';

const Map<String, IconData> appIconChoices = {
  'car': Icons.directions_car,
  'cleaning': Icons.cleaning_services,
  'computer': Icons.computer,
  'star': Icons.star,
  'hotel': Icons.hotel,
  'restaurant': Icons.restaurant,
  'security': Icons.security,
  'route': Icons.route,
  'payments': Icons.payments_outlined,
  'map': Icons.map_outlined,
  'person': Icons.person_outline,
  'build': Icons.build_outlined,
  'warehouse': Icons.warehouse_outlined,
};
IconData iconForKey(String key) => appIconChoices[key] ?? Icons.badge_outlined;
String iconLabel(String key) => switch (key) {
  'car' => 'Mașină', 'cleaning' => 'Aspirator / curățenie', 'computer' => 'PC', 'star' => 'Stea',
  'hotel' => 'Cazare', 'restaurant' => 'Restaurant', 'security' => 'Securitate', 'route' => 'Traseu',
  'payments' => 'Plăți', 'map' => 'Hartă', 'person' => 'Persoană', 'build' => 'Unelte', 'warehouse' => 'Depozit',
  _ => key,
};

const Map<String, String> categoryBrandAssets = {
  'million': 'assets/ui/cat_million.png',
  'magic': 'assets/ui/cat_magic.png',
  'horeca': 'assets/ui/cat_horeca.png',
  'cazari': 'assets/ui/cat_cazari.png',
};

String? sectionAssetForLabel(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized == 'acasă' || normalized == 'acasa' || normalized.contains('dashboard')) return 'assets/ui/tab_dashboard.png';
  if (normalized.contains('echipe')) return 'assets/ui/teams.png';
  if (normalized.contains('membri')) return 'assets/ui/members.png';
  if (normalized.contains('chat')) return 'assets/ui/chat_live.png';
  if (normalized == 'mesaje' || normalized.contains('contact')) return 'assets/ui/chat_live.png';
  if (normalized.contains('grafic')) return 'assets/ui/tab_grafic.png';
  if (normalized.contains('hart') || normalized.contains('loca')) return 'assets/ui/tab_harta.png';
  if (normalized.contains('centralizator') || normalized.contains('execuții') || normalized.contains('executii')) return 'assets/ui/tab_centralizator.png';
  if (normalized.contains('decont') || normalized.contains('financ')) return 'assets/ui/tab_decont.png';
  if (normalized.contains('document')) return 'assets/ui/tab_documente.png';
  if (normalized.contains('rapoarte')) return 'assets/ui/tab_centralizator.png';
  if (normalized.contains('funcții') || normalized.contains('functii') || normalized.contains('drepturi') || normalized.contains('securit')) return 'assets/ui/security.png';
  return null;
}

Widget appAssetIcon(String asset, {double size = 26, Color? accent, bool selected = false}) => Container(
  width: size + 8,
  height: size + 8,
  padding: const EdgeInsets.all(3),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: (accent ?? Colors.black12).withValues(alpha: selected ? .9 : .28), width: selected ? 1.8 : 1),
  ),
  child: Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
);

Widget sectionAssetWidget(String label, {double size = 24, Color? accent, bool selected = false, IconData? fallbackIcon}) {
  final asset = sectionAssetForLabel(label);
  if (asset != null) return appAssetIcon(asset, size: size, accent: accent, selected: selected);
  return Icon(fallbackIcon ?? Icons.apps_outlined, size: size, color: accent);
}

Widget categoryBrandWidget(String categoryId, {double size = 28, Color? fallbackColor}) {
  final asset = categoryBrandAssets[categoryId];
  if (asset != null) return appAssetIcon(asset, size: size, accent: fallbackColor);
  return CircleAvatar(radius: size / 2, backgroundColor: fallbackColor ?? Colors.blueGrey, child: const Icon(Icons.category_outlined, color: Colors.white, size: 16));
}

Widget _badgeGraphic(String asset, {required double size, Color? color}) {
  final outline = color ?? Colors.white;
  final inner = size * .88;
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: 1.08,
          child: Opacity(
            opacity: .72,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(outline, BlendMode.srcIn),
              child: Image.asset(asset, width: inner, height: inner, fit: BoxFit.contain),
            ),
          ),
        ),
        Image.asset(asset, width: inner, height: inner, fit: BoxFit.contain),
      ],
    ),
  );
}

