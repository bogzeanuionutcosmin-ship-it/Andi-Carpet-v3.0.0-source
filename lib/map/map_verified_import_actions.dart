part of '../main.dart';

extension _MapVerifiedImportActions on _MapPageState {
  Location? _locationForVerifiedFix(_VerifiedLocationFix fix) {
    for (final l in widget.locations) {
      if (l.id == fix.id) return l;
    }
    return null;
  }

  Future<void> _showVerifiedImportPreview() async {
    if (!widget.isAdmin || saving) return;
    final gpsCandidates = <MapEntry<Location, _VerifiedLocationFix>>[];
    final statusCandidates = <MapEntry<Location, _VerifiedLocationFix>>[];
    final verifiedButNoGps = <MapEntry<Location, _VerifiedLocationFix>>[];
    for (final fix in _verifiedLocationFixes) {
      final l = _locationForVerifiedFix(fix);
      if (l == null) continue;
      if ((l.latitude == null || l.longitude == null) && fix.hasGps) {
        gpsCandidates.add(MapEntry(l, fix));
      }
      if (fix.status != null && l.status != fix.status) {
        statusCandidates.add(MapEntry(l, fix));
      }
      if ((l.latitude == null || l.longitude == null) && !fix.hasGps) {
        verifiedButNoGps.add(MapEntry(l, fix));
      }
    }
    final fixById = {for (final x in _verifiedLocationFixes) x.id: x};
    final unresolved = widget.locations.where((l) =>
      (l.latitude == null || l.longitude == null) && !(fixById[l.id]?.hasGps ?? false)
    ).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final changedIds = <String>{...gpsCandidates.map((e)=>e.key.id), ...statusCandidates.map((e)=>e.key.id)};
    final apply = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(children:[Icon(Icons.fact_check_outlined),SizedBox(width:10),Expanded(child:Text('Verificare GPS și status'))]),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .86 : 680,
          height: MediaQuery.sizeOf(context).height * .68,
          child: ListView(children:[
            const Text('Previzualizare înainte de import. Coordonatele existente NU sunt mutate sau suprascrise.', style: TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:12),
            Wrap(spacing:8,runSpacing:8,children:[
              Chip(avatar:const Icon(Icons.add_location_alt_outlined,size:18),label:Text('${gpsCandidates.length} GPS de completat')),
              Chip(avatar:const Icon(Icons.sync_alt,size:18),label:Text('${statusCandidates.length} statusuri de schimbat')),
              Chip(avatar:const Icon(Icons.gps_off,size:18),label:Text('${unresolved.length} rămân fără GPS')),
            ]),
            const SizedBox(height:12),
            if (gpsCandidates.isNotEmpty) ...[
              const Text('Coordonate care vor fi completate',style:TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              ...gpsCandidates.map((e)=>ListTile(
                dense:true,contentPadding:EdgeInsets.zero,
                leading:const Icon(Icons.add_location_alt,color:Colors.green),
                title:Text(e.key.name),
                subtitle:Text('${e.value.verifiedAddress}\n${e.value.latitude!.toStringAsFixed(6)}, ${e.value.longitude!.toStringAsFixed(6)} · ${e.value.confidence}'),
                isThreeLine:true,
              )),
            ],
            if (statusCandidates.isNotEmpty) ...[
              const Divider(),
              const Text('Statusuri care vor fi actualizate',style:TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              ...statusCandidates.map((e)=>ListTile(
                dense:true,contentPadding:EdgeInsets.zero,
                leading:Icon(e.value.status!.icon,color:e.value.status!.color),
                title:Text(e.key.name),
                subtitle:Text('${e.key.status.label} → ${e.value.status!.label}\n${e.value.verifiedAddress}${e.value.note.isEmpty?'':' · ${e.value.note}'}'),
                isThreeLine:true,
              )),
            ],
            if (verifiedButNoGps.isNotEmpty) ...[
              const Divider(),
              const Text('Verificate, dar fără punct GPS suficient de sigur',style:TextStyle(fontWeight:FontWeight.bold)),
              ...verifiedButNoGps.map((e)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.manage_search,color:Colors.orange),title:Text(e.key.name),subtitle:Text(e.value.verifiedAddress))),
            ],
            if (unresolved.isNotEmpty) ...[
              const Divider(),
              ExpansionTile(
                tilePadding:EdgeInsets.zero,
                title:Text('Necesită verificare manuală (${unresolved.length})',style:const TextStyle(fontWeight:FontWeight.bold)),
                subtitle:const Text('Nu inventăm coordonate. Aceste locații rămân în „Neașezate pe hartă”.'),
                children:unresolved.map((l)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:categoryBrandWidget(l.categoryId,size:26,fallbackColor:_color(l)),title:Text(l.name),subtitle:Text(l.address))).toList(),
              ),
            ],
          ]),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Renunță')),
          FilledButton.icon(onPressed:changedIds.isEmpty?null:()=>Navigator.pop(c,true),icon:const Icon(Icons.cloud_upload_outlined),label:Text('Aplică ${changedIds.length} locații')),
        ],
      ),
    );
    if (apply == true && mounted) await _applyVerifiedImport();
  }

  Future<void> _applyVerifiedImport() async {
    if (!widget.isAdmin || saving) return;
    setState(() => saving = true);
    var gpsCount = 0;
    var statusCount = 0;
    var touched = 0;
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      for (final fix in _verifiedLocationFixes) {
        final l = _locationForVerifiedFix(fix);
        if (l == null) continue;
        final update = <String,dynamic>{};
        var changed = false;
        if ((l.latitude == null || l.longitude == null) && fix.hasGps) {
          l.latitude = fix.latitude;
          l.longitude = fix.longitude;
          update['latitude'] = fix.latitude;
          update['longitude'] = fix.longitude;
          gpsCount++;
          changed = true;
        }
        if (fix.status != null && l.status != fix.status) {
          l.status = fix.status!;
          update['status'] = fix.status!.name;
          statusCount++;
          changed = true;
        }
        if (!changed) continue;
        update['locationVerifiedAt'] = FieldValue.serverTimestamp();
        update['verificationSource'] = fix.source;
        update['verificationConfidence'] = fix.confidence;
        update['verifiedAddress'] = fix.verifiedAddress;
        if (fix.note.isNotEmpty) update['verificationNote'] = fix.note;
        batch.set(firestore.collection('locations').doc(l.id), update, SetOptions(merge:true));
        touched++;
      }
      if (touched > 0) await batch.commit();
      if (!mounted) return;
      widget.log('Import GPS verificat', '$touched locații · $gpsCount GPS · $statusCount statusuri');
      widget.onChanged();
      setState(() {});
      showSuccessMessage(context, touched == 0
          ? 'Nu există modificări noi de aplicat.'
          : 'Import finalizat: $gpsCount coordonate GPS și $statusCount statusuri actualizate. Coordonatele existente au rămas neschimbate.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Importul GPS nu a putut fi finalizat: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


}
