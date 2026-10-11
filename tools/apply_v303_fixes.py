#!/usr/bin/env python3
"""Field-test corrections layered after the verified v3.0.2 import patch."""
from pathlib import Path
p = Path("lib/main.dart")
s = p.read_text(encoding="utf-8")
changes = [
    ("(_selectedCategoryIds.isEmpty || _selectedCategoryIds.contains(l.categoryId))",
     "_selectedCategoryIds.contains(l.categoryId)"),
    ("(_selectedStatuses.isEmpty || _selectedStatuses.contains(l.status))",
     "_selectedStatuses.contains(l.status)"),
    ("const Text('Traseu grafic curcubeu')",
     "const Text('Traseu rutier · progres')"),
    ("await authUser.reauthenticateWithCredential(EmailAuthProvider.credential(email:mail,password:pass));final a=await _loadQuickAccounts();",
     "final a=await _loadQuickAccounts();"),
]
for before, after in changes:
    count = s.count(before)
    if count not in (1, 2) if before.startswith("(_selected") else count != 1:
        raise SystemExit(f"Unexpected count {count}: {before[:85]}")
    s = s.replace(before, after)
p.write_text(s, encoding="utf-8")
print("Applied field-test category/status and quick-account fixes")
