part of '../main.dart';

extension _MapLocationActions on _MapPageState {
  Location _copyLocation(Location l, {double? latitude, double? longitude}) => Location(
    id: l.id, name: l.name, address: l.address, type: l.type, categoryId: l.categoryId, status: l.status,
    latitude: latitude ?? l.latitude, longitude: longitude ?? l.longitude, phone: l.phone,
    contacts: l.contacts.map((c) => LocationContact(name: c.name, phone: c.phone, role: c.role, smsEnabled: c.smsEnabled)).toList(),
    surfaceM2: l.surfaceM2, facadeM2: l.facadeM2, notes: l.notes, active: l.active,
  );

  // Validare înainte de orice modificare a markerelor persistate.
  bool _validMapPoint(LatLng point) =>
      point.latitude.isFinite && point.longitude.isFinite &&
      point.latitude >= -90 && point.latitude <= 90 &&
      point.longitude >= -180 && point.longitude <= 180 &&
      !(point.latitude == 0 && point.longitude == 0);

  void _invalidMapPointNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Punct GPS invalid. Alege o poziție reală pe hartă.'),
    ));
  }

  Future<void> _chooseLocationAt(LatLng point) async {
    if (!_validMapPoint(point)) { _invalidMapPointNotice(); return; }
    if (selectedLocationId != null) {
      final selected = widget.locations.where((x) => x.id == selectedLocationId).toList();
      selectedLocationId = null;
      if (selected.isNotEmpty) { await _confirmAndPlace(selected.first, point); return; }
    }
    final search = TextEditingController();
    String query = '';
    String? chosenId;
    final choice = await showDialog<Object>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialog) {
      final available = widget.locations.where((l) {
        final q = query.trim().toLowerCase();
        return q.isEmpty || l.name.toLowerCase().contains(q) || l.address.toLowerCase().contains(q) || _categoryName(l).toLowerCase().contains(q);
      }).toList()..sort((a,b) {
        final cat = _categoryName(a).compareTo(_categoryName(b));
        return cat != 0 ? cat : a.name.compareTo(b.name);
      });
      return AlertDialog(
        title: const Text('Ce locație se află aici?'),
        content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 620, height: MediaQuery.sizeOf(context).height * .62, child: Column(children: [
          Text('Punct: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
          const SizedBox(height: 10),
          TextField(controller: search, autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Caută locația'), onChanged: (v) => setDialog(() => query = v)),
          const SizedBox(height: 10),
          Expanded(child: available.isEmpty ? const Center(child: Text('Nu am găsit locația.')) : ListView.builder(itemCount: available.length, itemBuilder: (_, i) {
            final l = available[i];
            return RadioListTile<String>(
              value: l.id, groupValue: chosenId, onChanged: (v) => setDialog(() => chosenId = v),
              secondary: CircleAvatar(backgroundColor: _color(l), child: const Icon(Icons.location_on, color: Colors.white)),
              title: Text('${_categoryName(l)} · ${l.name}'),
              subtitle: Text('${l.address}${l.latitude != null ? ' · are GPS' : ''} · ${l.status.label}'),
            );
          })),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anulează')),
          OutlinedButton.icon(onPressed: () => Navigator.pop(dialogContext, 'new'), icon: const Icon(Icons.add_location_alt), label: const Text('Adaugă locație nouă aici')),
          FilledButton(onPressed: chosenId == null ? null : () => Navigator.pop(dialogContext, widget.locations.firstWhere((x) => x.id == chosenId)), child: const Text('Salvează aici')),
        ],
      );
    }));
    search.dispose();
    if (choice == null) return;
    if (choice == 'new') { await _add(initialPoint: point); return; }
    await _confirmAndPlace(choice as Location, point);
  }

  Future<void> _confirmAndPlace(Location chosen, LatLng point) async {
    if (!_validMapPoint(point)) { _invalidMapPointNotice(); return; }
    if (chosen.latitude != null && chosen.longitude != null && mounted) {
      final replace = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Locația are deja coordonate'),
        content: Text('${chosen.name} este deja poziționată la ${chosen.latitude!.toStringAsFixed(6)}, ${chosen.longitude!.toStringAsFixed(6)}.\nNoua poziție: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}.\nMuți markerul?'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nu')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Da, mută'))],
      ));
      if (replace != true) return;
    }
    await _placeLocation(chosen, point);
  }

  Future<void> _placeLocation(Location source, LatLng point) async {
    if (!widget.isAdmin || saving || !_validMapPoint(point)) {
      _invalidMapPointNotice();
      return;
    }
    final updated = _copyLocation(source, latitude: point.latitude, longitude: point.longitude);
    setState(() => saving = true);
    try {
      await widget.saveLocation(updated);
      widget.log('Coordonate salvate din hartă', '${updated.name}: ${point.latitude}, ${point.longitude}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.name} a fost poziționată pe hartă.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Locația NU a fost salvată: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> _details(Location l) async {
    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: Row(children: [CircleAvatar(backgroundColor: _color(l), child: const Icon(Icons.location_on, color: Colors.white)), const SizedBox(width: 10), Expanded(child: Text(l.name))]),
      content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text(_categoryName(l)), avatar: categoryBrandWidget(l.categoryId, size: 22, fallbackColor: _color(l))), Chip(label: Text(l.status.label), avatar: Icon(l.status.icon, size: 17, color: l.status.color))]),
        const SizedBox(height: 8),
        Text(l.address, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (l.surfaceM2 > 0) Text('Mochetă / suprafață de lucru: ${l.surfaceM2.toStringAsFixed(0)} m²'),
        if (l.facadeM2 > 0) Text('Fațadă: ${l.facadeM2.toStringAsFixed(0)} m²'),
        if (l.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Notă: ${l.notes}')),
        const SizedBox(height: 14),
        const Text('Contacte', style: TextStyle(fontWeight: FontWeight.bold)),
        if (l.contacts.isEmpty) const Text('Nu există contact salvat.'),
        ...l.contacts.map((x) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline), title: Text(x.name), subtitle: Text(x.phone), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Trimite mesaj', onPressed: () async { final uri = Uri(scheme: 'sms', path: x.phone); if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) { await Clipboard.setData(ClipboardData(text: x.phone)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numărul a fost copiat: ${x.phone}'))); } }, icon: const Icon(Icons.message_outlined)),
          IconButton(tooltip: 'Copiază telefonul', onPressed: () async { await Clipboard.setData(ClipboardData(text: x.phone)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Telefon copiat: ${x.phone}'))); }, icon: const Icon(Icons.copy)),
        ]))),
        if (l.latitude != null && l.longitude != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('GPS: ${l.latitude!.toStringAsFixed(6)}, ${l.longitude!.toStringAsFixed(6)}')),
      ]))),
      actions: [
        if (widget.isAdmin && l.latitude != null && l.longitude != null)
          OutlinedButton.icon(
            onPressed: () { Navigator.pop(c); unawaited(_adjustLocation(l)); },
            icon: const Icon(Icons.open_with_rounded),
            label: const Text('Ajustează locația'),
          ),
        OutlinedButton.icon(onPressed: () { Navigator.pop(c); unawaited(_openNavigationForLocation(l, 'maps')); }, icon: const Icon(Icons.map_outlined), label: const Text('Maps')),
        OutlinedButton.icon(onPressed: () { Navigator.pop(c); unawaited(_openNavigationForLocation(l, 'waze')); }, icon: const Icon(Icons.navigation_outlined), label: const Text('Waze')),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),
      ],
    ));
  }

  Future<void> _adjustLocation(Location l) async {
    final result = await Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => LocationAdjustPage(location: l, color: _color(l))));
    if (result == null) return;
    final updated = _copyLocation(l, latitude: result.latitude, longitude: result.longitude);
    setState(() => saving = true);
    try {
      await widget.saveLocation(updated);
      widget.log('Locație ajustată pe hartă', updated.name);
      if (mounted) showSuccessMessage(context, 'Locația ${updated.name} a fost repoziționată pe hartă.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu am putut salva noua poziție: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openNavigationForLocation(Location l, String app) async {
    final useGps = l.latitude != null && l.longitude != null;
    final destination = useGps ? '${l.latitude},${l.longitude}' : l.address;
    final uri = app == 'maps'
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}')
        : Uri.parse(useGps ? 'https://www.waze.com/ul?ll=${l.latitude},${l.longitude}&navigate=yes' : 'https://www.waze.com/ul?q=${Uri.encodeComponent(l.address)}&navigate=yes');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) showErrorMessage(context, 'Nu am putut deschide navigația.');
  }

  Future<void> _add({LatLng? initialPoint}) async {
    String? initialAddress;
    if (initialPoint != null) {
      if (mounted) setState(() => findingAddress = true);
      initialAddress = await _reverseGeocodePoint(initialPoint);
      if (mounted) setState(() => findingAddress = false);
    }
    final r = await _newLocationForm(initialPoint: initialPoint, initialAddress: initialAddress);
    if (r == null) return;
    setState(() => saving = true);
    try {
      await widget.saveLocation(r);
      widget.log('Locație adăugată', r.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.name} a fost adăugată și salvată.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Locația NU a fost adăugată: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<Location?> _newLocationForm({LatLng? initialPoint, String? initialAddress}) async {
    final formKey = GlobalKey<FormState>();
    final n = TextEditingController(), a = TextEditingController(text: initialAddress ?? ''), p = TextEditingController(), m = TextEditingController(), f = TextEditingController(), note = TextEditingController();
    String categoryId = visibleCategories.isNotEmpty ? visibleCategories.first.id : 'horeca';
    final result = await showDialog<Location>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Locație nouă'),
      content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 560, child: Form(key: formKey, child: SingleChildScrollView(child: Column(children: [
        TextFormField(controller: n, decoration: const InputDecoration(labelText: 'Nume *'), validator: (v) => v == null || v.trim().isEmpty ? 'Numele este obligatoriu.' : null),
        const SizedBox(height: 8),
        TextFormField(
          controller: a,
          decoration: InputDecoration(
            labelText: 'Adresă *',
            helperText: initialPoint == null
                ? null
                : (initialAddress == null ? 'Adresa nu a putut fi identificată automat. O poți completa manual.' : 'Adresă preluată automat din punctul ales pe hartă.'),
            suffixIcon: initialPoint == null ? null : const Icon(Icons.location_searching),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Adresa este obligatorie.' : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Categorie'), items: visibleCategories.map((x) => DropdownMenuItem(value: x.id, child: Row(children: [categoryBrandWidget(x.id, size: 24, fallbackColor: x.color), const SizedBox(width: 8), Text(x.name)]))).toList(), onChanged: (v) { if (v != null) setD(() => categoryId = v); }),
        const SizedBox(height: 8),
        TextField(controller: p, decoration: const InputDecoration(labelText: 'Telefon principal')),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: TextFormField(controller: m, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Suprafață m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; })), const SizedBox(width: 8), Expanded(child: TextFormField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fațadă m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; }))]),
        const SizedBox(height: 8),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
        if (initialPoint != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('GPS preluat: ${initialPoint.latitude.toStringAsFixed(6)}, ${initialPoint.longitude.toStringAsFixed(6)}')),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () {
        if (!(formKey.currentState?.validate() ?? false)) return;
        final phone = p.text.trim();
        Navigator.pop(c, Location(
          id: idNow(), name: n.text.trim(), address: a.text.trim(), type: legacyTypeForCategory(categoryId), categoryId: categoryId,
          latitude: initialPoint?.latitude, longitude: initialPoint?.longitude, phone: phone.isEmpty ? null : phone,
          contacts: phone.isEmpty ? <LocationContact>[] : <LocationContact>[LocationContact(name: 'Contact locație', phone: phone)],
          surfaceM2: double.tryParse(m.text.replaceAll(',', '.')) ?? 0, facadeM2: double.tryParse(f.text.replaceAll(',', '.')) ?? 0,
          notes: note.text.trim(), status: LocationStatus.open, active: true,
        ));
      }, child: const Text('Salvează'))],
    )));
    n.dispose(); a.dispose(); p.dispose(); m.dispose(); f.dispose(); note.dispose();
    return result;
  }
}
