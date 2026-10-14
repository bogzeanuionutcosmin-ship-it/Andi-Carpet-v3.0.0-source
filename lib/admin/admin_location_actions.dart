part of '../main.dart';

// Locations, contacts and location categories administration.
mixin _AdminLocationActions on State<AdminPanelPage> {
  List<Location> get locations;
  List<LocationCategory> get categories;
  Future<int?> _pickColorValue(int current);

Future<LocationContact?> _contactDialog([LocationContact? existing]) async {
   final name = TextEditingController(text: existing?.name ?? '');
   final phone = TextEditingController(text: existing?.phone ?? '');
   var role=(existing?.role.trim().isNotEmpty??false)?existing!.role:'Manager';
   if(!const ['Manager','Casierie','Alt contact'].contains(role))role='Alt contact';
   var smsEnabled=existing?.smsEnabled??true;
   final result = await showDialog<LocationContact>(context: context, builder: (c) => StatefulBuilder(builder:(c,setD)=>AlertDialog(
     title: Text(existing == null ? 'Adaugă contact' : 'Editează contact'),
     content: Column(mainAxisSize: MainAxisSize.min, children: [
       DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Tip contact'),items:const[
         DropdownMenuItem(value:'Manager',child:Text('Manager')),
         DropdownMenuItem(value:'Casierie',child:Text('Casierie')),
         DropdownMenuItem(value:'Alt contact',child:Text('Alt contact')),
       ],onChanged:(v){if(v!=null)setD(()=>role=v);}),
       const SizedBox(height: 8),
       TextField(controller: name, decoration: InputDecoration(labelText:role=='Casierie'?'Nume / denumire (opțional)':'Nume contact')),
       const SizedBox(height: 8),
       TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon *')),
       SwitchListTile(contentPadding:EdgeInsets.zero,value:smsEnabled,onChanged:(v)=>setD(()=>smsEnabled=v),title:const Text('Primește SMS automat')),
     ]),
     actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () {
       if (phone.text.trim().isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Completează telefonul.'))); return; }
       Navigator.pop(c, LocationContact(name: name.text.trim().isEmpty?role:name.text.trim(), phone: phone.text.trim(),role:role,smsEnabled:smsEnabled));
     }, child: const Text('Salvează'))],
   )));
   name.dispose(); phone.dispose();
   return result;
 }

 Future<void> _editLocationAdmin([Location? existing]) async {
   final formKey = GlobalKey<FormState>();
   final n = TextEditingController(text: existing?.name ?? '');
   final a = TextEditingController(text: existing?.address ?? '');
   final m = TextEditingController(text: existing == null || existing.surfaceM2 == 0 ? '' : existing.surfaceM2.toString());
   final f = TextEditingController(text: existing == null || existing.facadeM2 == 0 ? '' : existing.facadeM2.toString());
   final note = TextEditingController(text: existing?.notes ?? '');
   final lat = TextEditingController(text: existing?.latitude?.toString() ?? '');
   final lng = TextEditingController(text: existing?.longitude?.toString() ?? '');
   String categoryId = existing?.categoryId ?? (categories.isNotEmpty ? categories.first.id : 'horeca');
   LocationStatus status = existing?.status ?? LocationStatus.open;
   final contacts = existing?.contacts.map((x) => LocationContact(name: x.name, phone: x.phone, role: x.role, smsEnabled: x.smsEnabled)).toList() ?? <LocationContact>[];
   final result = await showDialog<Location>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
     title: Text(existing == null ? 'Adaugă locație' : 'Editează locația'),
     content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 680, child: Form(key: formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       TextFormField(controller: n, decoration: const InputDecoration(labelText: 'Nume *'), validator: (v) => v == null || v.trim().isEmpty ? 'Numele este obligatoriu.' : null),
       const SizedBox(height: 8),
       TextFormField(controller: a, decoration: const InputDecoration(labelText: 'Adresă *'), validator: (v) => v == null || v.trim().isEmpty ? 'Adresa este obligatorie.' : null),
       const SizedBox(height: 8),
       Row(children: [
         Expanded(child: DropdownButtonFormField<String>(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Categorie'), items: categories.where((x) => x.active || x.id == categoryId).map((x) => DropdownMenuItem(value: x.id, child: Row(children: [categoryBrandWidget(x.id, size: 24, fallbackColor: x.color), const SizedBox(width: 8), Text(x.name)]))).toList(), onChanged: (v) { if (v != null) setD(() => categoryId = v); })),
         const SizedBox(width: 8),
         Expanded(child: DropdownButtonFormField<LocationStatus>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: LocationStatus.values.map((x) => DropdownMenuItem(value: x, child: Text(x.label))).toList(), onChanged: (v) { if (v != null) setD(() => status = v); })),
       ]),
       const SizedBox(height: 8),
       Row(children: [
         Expanded(child: TextFormField(controller: m, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Suprafață / mochetă m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; })),
         const SizedBox(width: 8),
         Expanded(child: TextFormField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fațadă m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; })),
       ]),
       const SizedBox(height: 8),
       Row(children: [
         Expanded(child: TextFormField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitudine'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < -90 || x > 90 ? 'Latitudine invalidă' : null; })),
         const SizedBox(width: 8),
         Expanded(child: TextFormField(controller: lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitudine'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < -180 || x > 180 ? 'Longitudine invalidă' : null; })),
       ]),
       const SizedBox(height: 8),
       TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Observații / note')),
       const SizedBox(height: 14),
       Row(children: [const Expanded(child: Text('Manageri / contacte', style: TextStyle(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: () async { final x = await _contactDialog(); if (x != null) setD(() => contacts.add(x)); }, icon: const Icon(Icons.add), label: const Text('Adaugă contact'))]),
       if (contacts.isEmpty) const Text('Nu există contacte salvate.'),
       ...List.generate(contacts.length, (i) => ListTile(
         contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline), title: Text(contacts[i].name), subtitle: Text('${contacts[i].role} · ${contacts[i].phone}${contacts[i].smsEnabled?' · SMS automat':' · doar apel'}'),
         trailing: Wrap(spacing: 2, children: [
           IconButton(tooltip: 'Editează', onPressed: () async { final x = await _contactDialog(contacts[i]); if (x != null) setD(() => contacts[i] = x); }, icon: const Icon(Icons.edit_outlined)),
           IconButton(tooltip: 'Șterge contact', onPressed: () => setD(() => contacts.removeAt(i)), icon: const Icon(Icons.delete_outline)),
         ]),
       )),
     ])))),
     actions: [
       TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
       FilledButton(onPressed: () {
         if (!(formKey.currentState?.validate() ?? false)) return;
         final latText = lat.text.trim(), lngText = lng.text.trim();
         if ((latText.isEmpty) != (lngText.isEmpty)) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Completează ambele coordonate sau lasă-le pe ambele goale.'))); return; }
         Navigator.pop(c, Location(
           id: existing?.id ?? idNow(), name: n.text.trim(), address: a.text.trim(), type: legacyTypeForCategory(categoryId), categoryId: categoryId, status: status,
           latitude: latText.isEmpty ? null : double.parse(latText.replaceAll(',', '.')), longitude: lngText.isEmpty ? null : double.parse(lngText.replaceAll(',', '.')),
           phone: contacts.isEmpty ? null : contacts.first.phone, contacts: contacts,
           surfaceM2: double.tryParse(m.text.replaceAll(',', '.')) ?? 0, facadeM2: double.tryParse(f.text.replaceAll(',', '.')) ?? 0,
           notes: note.text.trim(), active: true,
         ));
       }, child: const Text('Salvează')),
     ],
   )));
   n.dispose(); a.dispose(); m.dispose(); f.dispose(); note.dispose(); lat.dispose(); lng.dispose();
   if (result == null) return;
   try {
     await widget.saveLocation(result);
     widget.log(existing == null ? 'Locație adăugată din Admin' : 'Locație editată din Admin', result.name);
     if (mounted) showSuccessMessage(context, '${result.name} a fost salvată.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Locația nu a putut fi salvată: $e');
   }
 }

 Future<void> _deleteLocationPermanent(Location l) async {
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: const Text('Ștergere definitivă'),
     content: Text('${l.name} va fi ștearsă definitiv din registru și va dispărea automat de pe hartă. Istoricul execuțiilor deja înregistrate rămâne în Centralizator. Continui?'),
     actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, foregroundColor: Theme.of(c).colorScheme.onError), onPressed: () => Navigator.pop(c, true), child: const Text('Șterge definitiv'))],
   )) ?? false;
   if (!ok) return;
   try {
     await widget.deleteLocation(l.id);
     widget.log('Locație ștearsă definitiv', l.name);
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.name} a fost ștearsă definitiv.')));
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ștergerea a eșuat: $e')));
   }
 }

 Future<void> _changeLocationStatus(Location l, LocationStatus status) async {
   try {
     final updated = Location(
       id: l.id, name: l.name, address: l.address, type: l.type, categoryId: l.categoryId, status: status,
       latitude: l.latitude, longitude: l.longitude, phone: l.phone,
       contacts: l.contacts.map((x) => LocationContact(name: x.name, phone: x.phone, role: x.role, smsEnabled: x.smsEnabled)).toList(),
       surfaceM2: l.surfaceM2, facadeM2: l.facadeM2, notes: l.notes, active: true,
     );
     await widget.saveLocation(updated);
     widget.log('Status locație modificat', '${l.name} · ${status.label}');
     if (mounted) showSuccessMessage(context, '${l.name}: ${status.label}.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Statusul locației nu a putut fi salvat: $e');
   }
 }

 Widget _locations() {
   final cats = [...categories]..sort((a,b) => a.name.compareTo(b.name));
   return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
     Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
       const SizedBox(width: 460, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text('Locații', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
         SizedBox(height: 4),
         Text('Aici editezi datele, categoria și statusul. Hartă rămâne doar pentru vizualizare și poziționare GPS.'),
       ])),
       FilledButton.icon(onPressed: () => _editLocationAdmin(), icon: const Icon(Icons.add), label: const Text('Adaugă locație')),
     ]),
     const SizedBox(height: 12),
     ...cats.map((cat) {
       final items = locations.where((l) => l.categoryId == cat.id).toList()..sort((a,b) => a.name.compareTo(b.name));
       return Card(child: ExpansionTile(
         leading: categoryBrandWidget(cat.id, size: 34, fallbackColor: cat.color),
         title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
         subtitle: Text('${items.length} locații'),
         children: items.isEmpty ? [const ListTile(title: Text('Nu există locații în această categorie.'))] : items.map((l) => ListTile(
           leading: Icon(l.status.icon, color: l.status.color),
           title: Text(l.name),
           subtitle: Text('${l.address}\n${l.status.label} · ${l.latitude == null ? 'fără GPS' : 'GPS salvat'}'),
           isThreeLine: true,
           trailing: MediaQuery.sizeOf(context).width < 700
               ? PopupMenuButton<String>(
                   tooltip: 'Acțiuni locație',
                   onSelected: (value) {
                     if (value == 'edit') _editLocationAdmin(l);
                     if (value == 'delete') _deleteLocationPermanent(l);
                     if (value == 'open') _changeLocationStatus(l, LocationStatus.open);
                     if (value == 'temporary') _changeLocationStatus(l, LocationStatus.temporarilyClosed);
                     if (value == 'permanent') _changeLocationStatus(l, LocationStatus.permanentlyClosed);
                   },
                   itemBuilder: (c) => [
                     const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editează'))),
                     const PopupMenuDivider(),
                     const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.check_circle_outline, color: Colors.green), title: Text('Locație deschisă'))),
                     const PopupMenuItem(value: 'temporary', child: ListTile(leading: Icon(Icons.pause_circle_outline, color: Colors.orange), title: Text('Închisă temporar'))),
                     const PopupMenuItem(value: 'permanent', child: ListTile(leading: Icon(Icons.cancel_outlined, color: Colors.redAccent), title: Text('Închisă definitiv'))),
                     const PopupMenuDivider(),
                     PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Theme.of(c).colorScheme.error), title: const Text('Șterge definitiv'))),
                   ],
                 )
               : Wrap(spacing: 2, children: [
                   IconButton(tooltip: 'Editează', onPressed: () => _editLocationAdmin(l), icon: const Icon(Icons.edit_outlined)),
                   PopupMenuButton<LocationStatus>(
                     tooltip: 'Schimbă statusul',
                     onSelected: (status) => _changeLocationStatus(l, status),
                     itemBuilder: (_) => LocationStatus.values.map((x) => PopupMenuItem(value: x, child: Row(children: [Icon(x.icon, color: x.color), const SizedBox(width: 8), Text(x.label)]))).toList(),
                     icon: const Icon(Icons.flag_outlined),
                   ),
                   IconButton(tooltip: 'Șterge definitiv', onPressed: () => _deleteLocationPermanent(l), icon: const Icon(Icons.delete_forever)),
                 ]),
         )).toList(),
       ));
     }),
   ]);
 }

 Future<void> _editCategory([LocationCategory? existing]) async {
   final name = TextEditingController(text: existing?.name ?? '');
   int colorValue = existing?.colorValue ?? Colors.blueGrey.value;
   bool active = existing?.active ?? true;
   final result = await showDialog<LocationCategory>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
     title: Text(existing == null ? 'Adaugă categorie' : 'Editează categoria'),
     content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
       TextField(controller: name, decoration: const InputDecoration(labelText: 'Denumire categorie *')),
       const SizedBox(height: 10),
       ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: existing?.id == 'million' ? Colors.red : existing?.id == 'magic' ? Colors.black87 : Color(colorValue)), title: const Text('Culoare categorie'), subtitle: Text(existing?.id == 'million' ? 'Million are culoare fixă: roșu.' : existing?.id == 'magic' ? 'Magic are culoare fixă: negru.' : 'Se aplică pe hartă, liste, Grafic de lucru și Dashboard.'), trailing: (existing?.id == 'million' || existing?.id == 'magic') ? const Chip(label: Text('FIXĂ')) : OutlinedButton(onPressed: () async { final v = await _pickColorValue(colorValue); if (v != null) setD(() => colorValue = v); }, child: const Text('Alege culoarea'))),
       SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setD(() => active = v), title: const Text('Categorie activă')),
     ])),
     actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () {
       if (name.text.trim().isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Denumirea categoriei este obligatorie.'))); return; }
       Navigator.pop(c, LocationCategory(id: existing?.id ?? 'cat_${idNow()}', name: name.text.trim(), colorValue: colorValue, active: active));
     }, child: const Text('Salvează'))],
   )));
   name.dispose();
   if (result == null) return;
   if (result.id == 'million') result.colorValue = Colors.red.value;
   if (result.id == 'magic') result.colorValue = Colors.black87.value;
   try {
     await FirebaseFirestore.instance.collection('locationCategories').doc(result.id).set({'name':result.name,'colorValue':result.colorValue,'active':result.active,'updatedAt':FieldValue.serverTimestamp()}, SetOptions(merge:true));
     final idx = categories.indexWhere((x) => x.id == result.id);
     setState(() { if (idx >= 0) categories[idx] = result; else categories.add(result); });
     widget.log(existing == null ? 'Categorie locații adăugată' : 'Categorie locații modificată', result.name);
     if (mounted) showSuccessMessage(context, existing == null ? 'Categoria ${result.name} a fost adăugată.' : 'Categoria ${result.name} a fost actualizată.');
   } catch (e) { if (mounted) showErrorMessage(context, 'Categoria nu a putut fi salvată: $e'); }
 }

 Future<void> _deleteCategory(LocationCategory cat) async {
   final used = locations.where((l) => l.categoryId == cat.id).length;
   if (used > 0) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoria ${cat.name} este folosită de $used locații. Mută locațiile înainte de ștergere.'))); return; }
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Șterge categoria?'), content: Text(cat.name), actions: [TextButton(onPressed: () => Navigator.pop(c,false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c,true), child: const Text('Șterge'))])) ?? false;
   if (!ok) return;
   await FirebaseFirestore.instance.collection('locationCategories').doc(cat.id).delete();
   setState(() => categories.removeWhere((x) => x.id == cat.id));
   widget.log('Categorie locații ștearsă', cat.name); if (mounted) showSuccessMessage(context, 'Categoria ${cat.name} a fost ștearsă.');
 }

 Widget _categories() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
     const SizedBox(width: 480, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Categorii locații', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Million, Magic, HoReCa, Cazări și orice categorie nouă. Culoarea este globală și se aplică imediat peste tot.')])),
     FilledButton.icon(onPressed: () => _editCategory(), icon: const Icon(Icons.add), label: const Text('Adaugă categorie')),
   ]),
   const SizedBox(height: 12),
   ...([...categories]..sort((a,b)=>a.name.compareTo(b.name))).map((cat) => Card(child: ListTile(
     leading: categoryBrandWidget(cat.id, size: 38, fallbackColor: cat.color), title: Text(cat.name), subtitle: Text('${locations.where((l)=>l.categoryId==cat.id).length} locații · ${cat.active?'activă':'inactivă'} · #${cat.colorValue.toRadixString(16).padLeft(8,'0').toUpperCase()}'),
     trailing: Wrap(spacing: 2, children: [IconButton(tooltip:'Editează',onPressed:()=>_editCategory(cat),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Șterge',onPressed:()=>_deleteCategory(cat),icon:const Icon(Icons.delete_outline))]),
   ))),
 ]);
 }
