/// Clasificare locală, fără migrarea documentelor Firestore existente.
/// Categoria explicită are prioritate; fallbackul ajută fișele PV vechi
/// care au fost salvate cu categoria implicită „Alte documente”.
bool isProtocolDocument({
  required String title,
  required String category,
}) {
  final c = category.trim().toLowerCase();
  if (c == 'proces verbal' || c == 'proces-verbal' || c == 'procese verbale') {
    return true;
  }
  if (c != 'alte documente' && c.isNotEmpty) return false;

  final t = title.trim().toLowerCase();
  return RegExp(r'\b(pv|p\.v\.|proces[ -]+verbal)\b').hasMatch(t);
}

/// Fără presupuneri după simplul nume al clientului: un „Contract Million”
/// rămâne contract, nu este mutat automat la procese verbale.
String documentDisplayGroup({required String title, required String category}) =>
    isProtocolDocument(title: title, category: category)
        ? 'Procese verbale'
        : 'Alte documente permanente';
