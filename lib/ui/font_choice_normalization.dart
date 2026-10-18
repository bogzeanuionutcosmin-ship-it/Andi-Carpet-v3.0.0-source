/// Pure normalization of user-selected font choices.
///
/// Keep legacy spellings, case sensitivity and the System fallback unchanged.
String normalizeFontChoice(String? raw) {
  final value = (raw ?? 'System').trim();
  if (value == 'Georgia' || value == 'Serif') return 'Serif';
  if (value == 'Monospace') return 'Monospace';
  if (value == 'Condensed' || value == 'Cursive') return 'Cursive';
  if (const {'Roboto','Arial','Verdana','Tahoma','Sans'}.contains(value)) return 'Sans';
  return 'System';
}
