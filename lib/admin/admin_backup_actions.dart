part of '../main.dart';

// Backup operations are inherited by the Admin panel state; UI stays in the panel.
mixin _AdminBackupActions on State<AdminPanelPage> {
  FirebaseFirestore get _backupDb;
  AdminBackupFiles get _backupFiles;
  Future<void> _exportBackup() async {
    const names=['teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit','learningEvents','backgrounds'];
    final db=_backupDb;
    final data=<String,dynamic>{
      'format':'AndiCarpetaBackupV1',
      'createdAt':DateTime.now().toIso8601String(),
      'collections':<String,dynamic>{},
    };
    final uiSettings=await db.collection('meta').doc('uiSettings').get();
    data['uiSettings']=_backupEncode(uiSettings.data());
    final collections=data['collections'] as Map<String,dynamic>;
    for(final name in names){
      final snap=await db.collection(name).get();
      collections[name]={for(final doc in snap.docs) doc.id:_backupEncode(doc.data())};
    }
    final bytes=Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    final filename='andi_carpeta_backup_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}_${two(DateTime.now().hour)}${two(DateTime.now().minute)}.json';
    final saved=await _backupFiles.saveJson(fileName:filename,bytes:bytes);
    if(saved!=null){
      await db.collection('meta').doc('backup').set({'lastExportAt':FieldValue.serverTimestamp(),'fileName':filename},SetOptions(merge:true));
      widget.log('Backup exportat',filename);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Backup exportat.')));
    }
  }

  Future<void> _restoreAutomaticBackup(String backupId) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Restaurează backup-ul automat?'),
      content:Text('Snapshot: $backupId\n\nColecțiile operaționale vor fi înlocuite cu valorile din snapshot. Conturile Firebase Authentication și profilurile users nu sunt modificate.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restaurează'))],
    ))??false;
    if(!ok)return;
    final db=_backupDb;
    final ref=db.collection('backups').doc(backupId);
    final meta=await ref.get();
    if(!meta.exists||meta.data()?['status']!='complete'){if(mounted)showErrorMessage(context,'Backup-ul selectat nu este complet.');return;}
    final items=await ref.collection('items').get();
    const allowed=<String>{'teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit'};
    // Preflight snapshot data before deleting anything. Missing collections are
    // not evidence that the snapshot intended to empty those live collections.
    final grouped=<String,Map<String,Map<String,dynamic>>>{};
    Map<String,dynamic>? validatedSettings;
    try{
      if(items.docs.isEmpty)throw const FormatException('Snapshot-ul nu conține documente.');
      for(final item in items.docs){
        final d=item.data();
        final collection=(d['collection']??'').toString();
        if(!allowed.contains(collection))continue;
        final documentId=(d['documentId']??'').toString();
        if(documentId.isEmpty||documentId.contains('/'))throw FormatException('ID invalid în $collection.');
        if(d['data'] is! Map)throw FormatException('Document invalid în $collection.');
        final documents=grouped.putIfAbsent(collection,()=> <String,Map<String,dynamic>>{});
        if(documents.containsKey(documentId))throw FormatException('Document duplicat în $collection.');
        documents[documentId]=Map<String,dynamic>.from(d['data'] as Map);
      }
      if(grouped.isEmpty)throw const FormatException('Snapshot-ul nu conține colecții operaționale valide.');
      final settings=meta.data()?['uiSettings'];
      if(settings!=null){
        if(settings is! Map)throw const FormatException('Setările UI sunt invalide.');
        validatedSettings=Map<String,dynamic>.from(settings);
      }
    }catch(e){
      if(mounted)showErrorMessage(context,'Backup automat invalid. Nu s-au modificat date: $e');
      return;
    }
    try{
      for(final collection in grouped.keys){
        final current=await db.collection(collection).get();
        WriteBatch batch=db.batch();var count=0;
        for(final doc in current.docs){batch.delete(doc.reference);count++;if(count>=300){await batch.commit();batch=db.batch();count=0;}}
        if(count>0)await batch.commit();
        batch=db.batch();count=0;
        for(final document in grouped[collection]!.entries){
          batch.set(db.collection(collection).doc(document.key),document.value);count++;
          if(count>=8){await batch.commit();batch=db.batch();count=0;}
        }
        if(count>0)await batch.commit();
      }
      if(validatedSettings!=null)await db.collection('meta').doc('uiSettings').set(validatedSettings,SetOptions(merge:false));
      await db.collection('meta').doc('backup').set({'lastRestoreAt':FieldValue.serverTimestamp(),'restoredAutomaticBackup':backupId},SetOptions(merge:true));
      widget.log('Backup automat restaurat',backupId);
      if(mounted)showSuccessMessage(context,'Backup-ul automat a fost restaurat. Datele se resincronizează.');
    }catch(e){if(mounted)showErrorMessage(context,'Restaurarea backup-ului automat a eșuat: $e');}
  }

  Future<void> _restoreBackup() async {
    final file=await _backupFiles.pickJson();
    if(file==null)return;
    final raw=utf8.decode(await file.readAsBytes());
    final parsed=jsonDecode(raw);
    if(parsed is! Map || parsed['format']!='AndiCarpetaBackupV1' || parsed['collections'] is! Map){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Fișierul nu este un backup Andi Carpetă valid.')));
      return;
    }
    // Preflight the entire backup before the first destructive Firestore write.
    // Validation must happen before the confirmation dialog and deletion loop.
    const allowedRestoreCollections=<String>{'teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit'};
    final rawCollections=parsed['collections'] as Map;
    final validated=<String,Map<String,dynamic>>{};
    try{
      for(final entry in rawCollections.entries){
        final name=entry.key.toString();
        if(!allowedRestoreCollections.contains(name))continue;
        if(entry.value is! Map)throw FormatException('Colecția $name nu este un obiect.');
        final documents=<String,dynamic>{};
        for(final rawEntry in (entry.value as Map).entries){
          final id=rawEntry.key.toString();
          if(id.isEmpty||id.contains('/'))throw FormatException('ID invalid în colecția $name.');
          final decoded=_backupDecode(rawEntry.value);
          if(decoded is! Map)throw FormatException('Document invalid în colecția $name.');
          documents[id]=Map<String,dynamic>.from(decoded);
        }
        validated[name]=documents;
      }
    }catch(e){
      if(mounted)showErrorMessage(context,'Backup invalid. Nu s-au modificat date: $e');
      return;
    }
    Map<String,dynamic>? validatedSettings;
    try{
      if(parsed['uiSettings']!=null){
        final decodedSettings=_backupDecode(parsed['uiSettings']);
        if(decodedSettings is! Map)throw const FormatException('Setările UI nu sunt un obiect.');
        validatedSettings=Map<String,dynamic>.from(decodedSettings);
      }
    }catch(e){
      if(mounted)showErrorMessage(context,'Backup invalid. Nu s-au modificat date: $e');
      return;
    }
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Restaurare backup'),content:const Text('Datele operaționale și Auditul din backup vor înlocui colecțiile existente. Conturile Firebase Authentication nu sunt modificate. Continui?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restaurează'))]))??false;
    if(!ok)return;
    final db=_backupDb;
    for(final entry in validated.entries){
      final name=entry.key;
      final current=await db.collection(name).get();
      var batch=db.batch();
      var count=0;
      for(final doc in current.docs){
        batch.delete(doc.reference);count++;
        if(count>=400){await batch.commit();batch=db.batch();count=0;}
      }
      if(count>0)await batch.commit();
      batch=db.batch();count=0;
      for(final document in entry.value.entries){
        batch.set(db.collection(name).doc(document.key),Map<String,dynamic>.from(document.value as Map));count++;
        if(count>=400){await batch.commit();batch=db.batch();count=0;}
      }
      if(count>0)await batch.commit();
    }
    if(validatedSettings!=null)await db.collection('meta').doc('uiSettings').set(validatedSettings,SetOptions(merge:false));
    await db.collection('meta').doc('backup').set({'lastRestoreAt':FieldValue.serverTimestamp(),'restoredFile':file.name},SetOptions(merge:true));
    widget.log('Backup restaurat',file.name);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Restaurarea s-a terminat. Datele se resincronizează.')));
  }

}
