#!/usr/bin/env python3
"""Safe, idempotent fixes applied to the original v3.0.1 ZIP at build time.

The source archive is not edited; each expected source fragment is verified
before replacement, so a future incompatible version fails rather than
silently removing unrelated features.
"""
from pathlib import Path

source = Path("lib/main.dart")
data = source.read_text(encoding="utf-8")
changes = [
    ("const String _appVersionLabel = '3.0.0+32';",
     "const String _appVersionLabel = '3.0.2+34';"),
    ("Text('Fereastră standard: ${timeText(workWindowStart(workDate))} → ${timeText(workWindowEnd(workDate))}'),",
     ""),
    ("_StatMini(label:'Km GPS (linie dreaptă)',value:", "_StatMini(label:'Km GPS estimativi (linie dreaptă)',value:"),
    ("_InfoCard(icon:Icons.info_outline,title:'Estimare traseu complet',text:", "_InfoCard(icon:Icons.info_outline,title:'Estimare geometrică (nu rutieră)',text:"),
    ("Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[",
     "Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:14,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.start,children:["),
    ("Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))",
     "SizedBox(width:math.min(MediaQuery.sizeOf(context).width-80,340),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display,softWrap:true,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))"),
    ("isThreeLine: true,\n                            onTap: n.read ? null : () async {",
     "isThreeLine: true,\n                            trailing: n.read ? const Icon(Icons.check_circle_outline) : const Tooltip(message:'Marchează ca citit',child:Icon(Icons.mark_email_read_outlined)),\n                            onTap: n.read ? null : () async {"),
    ("(inWindow ? 'Între locații' : 'Liber'), asset: 'assets/ui/tab_harta.png')",
     "(inWindow ? 'Locația echipei: consultă poziția live' : 'Liber'), asset: 'assets/ui/tab_harta.png')"),
    ("    if (isAdmin) return true;\n    final ids = me.functionIds;",
     "    if (isAdmin) return true;\n    // Membrii pot vedea directorul; permisiunile de editare rămân separate.\n    if (permission == FunctionPermission.viewMembers) return true;\n    final ids = me.functionIds;"),
    ("const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),\n                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),",
     "const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),\n                    TextButton(onPressed: () async {\n                      final unread = mine.where((n) => !n.read).toList();\n                      if (unread.isEmpty) return;\n                      try {\n                        final db = FirebaseFirestore.instance;\n                        for (var offset = 0; offset < unread.length; offset += 400) {\n                          final batch = db.batch();\n                          for (final n in unread.skip(offset).take(400)) {\n                            batch.set(db.collection('notifications').doc(n.id), {'read': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));\n                          }\n                          await batch.commit();\n                        }\n                        for (final n in unread) { n.read = true; }\n                        if (mounted) setState(() {});\n                        if (c.mounted) Navigator.pop(c);\n                      } catch (e) {\n                        if (mounted) showErrorMessage(context, 'Nu s-au putut marca notificările: $e');\n                      }\n                    }, child: const Text('Toate citite')),\n                    IconButton(tooltip: 'Închide', onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),"),
    ("    {'version':'3.0.0+32','title':'Finalizare v3.0.0 · mesaje automate și curățare'", "    {'version':'3.0.2+34','title':'Îmbunătățiri Android și interfață','summary':'Versiune de test: profil adaptat pentru telefon, accesul lucrătorilor la directorul de membri, marcarea notificărilor ca citite, etichete mai clare pentru distanțele geometrice și eliminarea ferestrei standard din Dashboard. Alte funcții sunt în curs de verificare.'},\n    {'version':'3.0.0+32','title':'Finalizare v3.0.0 · mesaje automate și curățare'"),
]
for before, after in changes:
    count = data.count(before)
    if count != 1:
        raise SystemExit(f"Expected exactly one occurrence ({count}): {before[:90]}")
    data = data.replace(before, after, 1)
source.write_text(data, encoding="utf-8")

pubspec = Path("pubspec.yaml")
text = pubspec.read_text(encoding="utf-8")
if "version: 3.0.1+33" not in text:
    raise SystemExit("Unexpected pubspec version; manual review required")
pubspec.write_text(text.replace("version: 3.0.1+33", "version: 3.0.2+34", 1), encoding="utf-8")
print("Applied verified UI and version fixes")
