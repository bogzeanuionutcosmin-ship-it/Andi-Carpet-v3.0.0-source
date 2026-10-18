/// Pure bundled category assets and ordered section-label routing.

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

