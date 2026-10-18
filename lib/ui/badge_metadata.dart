/// Pure badge identifiers, labels and asset mapping. No Flutter dependencies.

const Map<String, String> badgeAssetChoices = {
  'badge_admin': 'assets/badges/badge_admin.png',
  'badge_ceo': 'assets/badges/badge_ceo.png',
  'badge_developer': 'assets/badges/badge_developer.png',
  'badge_driver': 'assets/badges/badge_driver.png',
  'badge_worker': 'assets/badges/badge_worker.png',
  // Alias pentru funcțiile create în pachetul anterior.
  'badge_machine': 'assets/badges/badge_worker.png',
  'badge_finance': 'assets/badges/badge_finance.png',
  'badge_documents': 'assets/badges/badge_documents.png',
  'badge_vip': 'assets/badges/badge_vip.png',
  'badge_heart': 'assets/badges/badge_heart.png',
  'badge_xyz': 'assets/badges/badge_xyz.png',
};

String badgeLabel(String key) => switch (key) {
  'badge_admin' => 'Admin',
  'badge_ceo' => 'CEO',
  'badge_developer' => '<DEV/>',
  'badge_driver' => 'Șofer',
  'badge_worker' => 'Lucrător',
  'badge_machine' => 'Lucrător',
  'badge_finance' => 'Financiar',
  'badge_documents' => 'Documente / Acte',
  'badge_vip' => 'VIP Premium',
  'badge_heart' => 'Inimă verde',
  'badge_xyz' => 'XYZ',
  _ => key,
};

const List<String> availableBadgeKeys = <String>[
  'badge_admin',
  'badge_ceo',
  'badge_developer',
  'badge_driver',
  'badge_worker',
  'badge_finance',
  'badge_documents',
  'badge_vip',
  'badge_heart',
  'badge_xyz',
];

