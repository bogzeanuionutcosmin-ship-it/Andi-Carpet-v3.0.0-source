part of '../main.dart';

// Backup status and restore controls; implementation remains in _AdminBackupActions.
mixin _AdminBackupPanelActions on State<AdminPanelPage> {
  AppSettings get settings;
  Future<void> restoreAutomaticBackup(String id);
  Future<void> exportBackup();
  Future<void> restoreBackup();

Widget _backup()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Backup & Recuperare',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    Text('Backup manual: fișier JSON descărcat local. Backup intern automat: ${settings.automaticBackup?'ACTIV':'OPRIT'} · retenție ${settings.backupRetentionDays} zile. Conturile Firebase Authentication nu sunt incluse.'),
    const SizedBox(height:12),
    StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('meta').doc('backup').snapshots(),
      builder:(context,snap){
        final d=snap.data?.data();
        final last=d!=null && d['lastExportAt'] is Timestamp ? (d['lastExportAt'] as Timestamp).toDate() : null;
        final restored=d!=null && d['lastRestoreAt'] is Timestamp ? (d['lastRestoreAt'] as Timestamp).toDate() : null;
        return _InfoCard(icon:Icons.backup,title:'Stare backup',text:'Ultimul export: ${last==null?'niciunul':'${formatDate(last)} ${timeText(last)}'}\nUltima restaurare: ${restored==null?'niciuna':'${formatDate(restored)} ${timeText(restored)}'}');
      },
    ),
    const SizedBox(height:10),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('backups').orderBy('createdAt',descending:true).limit(1).snapshots(),
      builder:(context,snap){
        if(!snap.hasData||snap.data!.docs.isEmpty)return _InfoCard(icon:Icons.cloud_outlined,title:'Backup intern automat',text:settings.automaticBackup?'Activ · încă nu există niciun snapshot complet.':'Oprit din Setări sistem.');
        final doc=snap.data!.docs.first;final d=doc.data();final at=d['createdAt'] is Timestamp?(d['createdAt'] as Timestamp).toDate():null;final status=(d['status']??'').toString();final count=d['documentCount'] is num?(d['documentCount'] as num).toInt():0;
        return Card(child:ListTile(leading:const Icon(Icons.cloud_done_outlined),title:const Text('Backup intern automat',style:TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${status=='complete'?'Complet':status} · ${at==null?'dată în curs':'${formatDate(at)} ${timeText(at)}'} · $count documente · retenție ${settings.backupRetentionDays} zile'),trailing:status=='complete'?OutlinedButton.icon(onPressed:()=>restoreAutomaticBackup(doc.id),icon:const Icon(Icons.restore),label:const Text('Restaurează')):null));
      },
    ),
    const SizedBox(height:12),
    Wrap(spacing:10,runSpacing:10,children:[
      FilledButton.icon(onPressed:exportBackup,icon:const Icon(Icons.download),label:const Text('Exportă backup')),
      OutlinedButton.icon(onPressed:restoreBackup,icon:const Icon(Icons.restore),label:const Text('Restaurează backup')),
    ]),
    const SizedBox(height:12),
    const _InfoCard(icon:Icons.security,title:'Siguranță',text:'Restaurarea cere confirmare și înlocuiește datele operaționale și Auditul: echipe, mașini, locații, grafice, execuții, deplasări/deconturi, diurne, financiar, documente, notificări și audit. Conturile de autentificare rămân intacte.'),
  ]);
}
