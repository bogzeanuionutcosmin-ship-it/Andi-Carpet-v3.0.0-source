part of '../main.dart';

class _ProfileLiveStats extends StatelessWidget {
  final String? teamId;
  final String memberId;
  const _ProfileLiveStats({required this.teamId, required this.memberId});

  DateTime? _date(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recordsQuery = teamId == null || teamId!.isEmpty
        ? null
        : FirebaseFirestore.instance.collection('records').where('teamId', isEqualTo: teamId);
    final perDiemsQuery = FirebaseFirestore.instance.collection('perDiems').where('memberId', isEqualTo: memberId);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recordsQuery?.snapshots(),
      builder: (context, recordsSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: perDiemsQuery.snapshots(),
        builder: (context, perSnap) {
          final rows = (recordsSnap.data?.docs ?? const []).map((doc) => centralizerRecordFromData(doc.id, doc.data()))
              .where((r) => r.completed && r.duration != null && !r.duration!.isNegative).toList();
          final dayRows = rows.where((r) => sameDay(r.startedAt!, now)).toList();
          final monthRows = rows.where((r) => r.startedAt!.year == now.year && r.startedAt!.month == now.month).toList();
          final yearRows = rows.where((r) => r.startedAt!.year == now.year).toList();
          String hours(Iterable<CentralizerRecord> rs) {
            final value = rs.fold<double>(0, (sum, r) => sum + r.duration!.inMinutes / 60.0);
            return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} h';
          }
          Set<String> workedDays(Iterable<CentralizerRecord> rs) => rs.map((r) {
            final d = r.startedAt!;
            return '${d.year}-${two(d.month)}-${two(d.day)}';
          }).toSet();
          double paidAmount(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final d = doc.data();
            if (d['status'] != PerDiemStatus.confirmed.name || d['received'] != true) return 0;
            final raw = d['actualReceivedAmount'] ?? d['amount']; // fallback for confirmed legacy records
            final amount = raw is num ? raw.toDouble() : double.tryParse('$raw');
            return amount != null && amount.isFinite && amount > 0 ? amount : 0;
          }
          final paid = (perSnap.data?.docs ?? const []).where((doc) => doc.data()['status'] == PerDiemStatus.confirmed.name && doc.data()['received'] == true);
          final perMonth = paid.where((doc) { final d = _date(doc.data()['date']); return d != null && d.year == now.year && d.month == now.month; }).fold<double>(0, (sum, doc) => sum + paidAmount(doc));
          final perYear = paid.where((doc) { final d = _date(doc.data()['date']); return d != null && d.year == now.year; }).fold<double>(0, (sum, doc) => sum + paidAmount(doc));
          final perAll = paid.fold<double>(0, (sum, doc) => sum + paidAmount(doc));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Statistici angajat', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (recordsSnap.hasError || perSnap.hasError) const Text('Statisticile nu s-au putut sincroniza.'),
            if (recordsSnap.connectionState == ConnectionState.waiting || perSnap.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _ProfileStatCard(title: 'Zile lucrate luna curentă', value: '${workedDays(monthRows).length}', icon: Icons.calendar_view_month),
              _ProfileStatCard(title: 'Zile lucrate anul curent', value: '${workedDays(yearRows).length}', icon: Icons.calendar_today_outlined),
              _ProfileStatCard(title: 'Ore lucrate azi', value: hours(dayRows), icon: Icons.schedule),
              _ProfileStatCard(title: 'Ore lucrate luna curentă', value: hours(monthRows), icon: Icons.more_time),
              _ProfileStatCard(title: 'Ore lucrate anul curent', value: hours(yearRows), icon: Icons.access_time_filled),
            ]),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Diurne încasate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
              Text('Luna curentă: ${perMonth.toStringAsFixed(2)} lei'), Text('Anul curent: ${perYear.toStringAsFixed(2)} lei'), Text('Total: ${perAll.toStringAsFixed(2)} lei'),
            ]))),
            const SizedBox(height: 8),
            Text('Notă: orele și zilele de lucru sunt calculate din intervențiile finalizate ale echipei la care este alocat contul.', style: Theme.of(context).textTheme.bodySmall),
          ]);
        },
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _ProfileStatCard({required this.title, required this.value, required this.icon});
  @override Widget build(BuildContext context) => SizedBox(width: 210, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(title)]))));
}

class ProfilePage extends StatefulWidget {
  final AppUser user;
  final List<Team> teams;
  final List<FunctionDefinition> functionDefinitions;
  final List<CentralizerRecord> records;
  final List<PerDiemEntry> perDiems;
  const ProfilePage({super.key,required this.user,required this.teams,required this.functionDefinitions,required this.records,required this.perDiems});
  @override State<ProfilePage> createState()=>_ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>{
  Uint8List? _photoFromData(String? value){if(value==null||value.isEmpty)return null;try{return base64Decode(value);}catch(_){return null;}}
  Future<String?> _pickProfilePhoto()async{
    try{
      final picked=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1600,imageQuality:92);
      if(picked==null)return null;
      final bytes=await picked.readAsBytes();final source=img.decodeImage(bytes);if(source==null)return null;
      final square=img.copyResizeCropSquare(source,size:320);return base64Encode(img.encodeJpg(square,quality:82));
    }catch(e){if(mounted)showErrorMessage(context,'Poza nu a putut fi selectată: $e');return null;}
  }
  DateTime? _dateFromRaw(Object? raw){if(raw is Timestamp)return raw.toDate();if(raw is DateTime)return raw;if(raw is String)return DateTime.tryParse(raw);return null;}
  Future<void> _openLink(String raw)async{
    final text=raw.trim();if(text.isEmpty)return;
    final normalized=RegExp(r'^https?://',caseSensitive:false).hasMatch(text)?text:'https://$text';
    final uri=Uri.tryParse(normalized);
    if(uri==null||!await launchUrl(uri,mode:LaunchMode.externalApplication)){
      await Clipboard.setData(ClipboardData(text:text));if(mounted)showErrorMessage(context,'Linkul nu a putut fi deschis. A fost copiat.');
    }
  }

  Future<void> _editProfile(Map<String,dynamic> d)async{
    final name=TextEditingController(text:(d['name']??'').toString());
    final nickname=TextEditingController(text:(d['nickname']??'').toString());
    final phone=TextEditingController(text:(d['phone']??'').toString());
    final contractFunction=TextEditingController(text:(d['contractFunction']??'').toString());
    var useNickname=d['useNickname']==true;
    var hireDate=_dateFromRaw(d['hireDate']);
    var photo=(d['photoBase64']??'').toString();
    final fields=<Map<String,dynamic>>[];
    final rawFields=d['profileFields'];
    if(rawFields is List){for(final raw in rawFields){if(raw is Map){fields.add({'label':TextEditingController(text:(raw['label']??'').toString()),'value':TextEditingController(text:(raw['value']??'').toString()),'type':(raw['type']??'text').toString()=='link'?'link':'text'});}}}
    final saved=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:const Text('Editează profilul'),
      content:SizedBox(width:680,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Center(child:Column(children:[CircleAvatar(radius:50,backgroundImage:_photoFromData(photo)==null?null:MemoryImage(_photoFromData(photo)!),child:_photoFromData(photo)==null?const Icon(Icons.person,size:48):null),const SizedBox(height:8),Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()async{final p=await _pickProfilePhoto();if(p!=null)setD(()=>photo=p);},icon:const Icon(Icons.photo_camera_outlined),label:const Text('Poză profil')),if(photo.isNotEmpty)TextButton.icon(onPressed:()=>setD(()=>photo=''),icon:const Icon(Icons.delete_outline),label:const Text('Elimină'))])])),
        const SizedBox(height:14),
        TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nume și prenume')),
        const SizedBox(height:10),
        TextField(controller:nickname,decoration:const InputDecoration(labelText:'Poreclă',hintText:'Ex.: Timi')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:useNickname,onChanged:(v)=>setD(()=>useNickname=v==true),title:const Text('Folosește porecla în grafice, chat și afișarea internă'),subtitle:const Text('Numele complet rămâne salvat în profil.')),
        const SizedBox(height:6),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Număr telefon')),
        const SizedBox(height:10),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month_outlined),title:const Text('Data angajării'),subtitle:Text(hireDate==null?'Nesetată':formatDate(hireDate!)),trailing:OutlinedButton(onPressed:()async{final now=DateTime.now();final picked=await showDatePicker(context:c,initialDate:hireDate??DateTime(now.year,now.month,now.day),firstDate:DateTime(1990),lastDate:DateTime(now.year+1));if(picked!=null)setD(()=>hireDate=picked);},child:const Text('Alege'))),
        const SizedBox(height:6),
        TextField(controller:contractFunction,decoration:const InputDecoration(labelText:'Funcție conform contractului individual de muncă',hintText:'Ex.: Operator curățenie')),
        const Divider(height:28),
        Row(children:[const Expanded(child:Text('Alte informații',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900))),OutlinedButton.icon(onPressed:()=>setD(()=>fields.add({'label':TextEditingController(),'value':TextEditingController(),'type':'text'})),icon:const Icon(Icons.add),label:const Text('Adaugă câmp'))]),
        const SizedBox(height:6),
        const Text('Poți adăuga orice câmp. Pentru Facebook, TikTok sau alte pagini alege tipul Link; valoarea va putea fi deschisă direct din profil.'),
        const SizedBox(height:10),
        ...List.generate(fields.length,(i){final f=fields[i];return Padding(padding:const EdgeInsets.only(bottom:9),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(flex:2,child:TextField(controller:f['label'] as TextEditingController,decoration:const InputDecoration(labelText:'Denumire',hintText:'Ex.: Facebook'))),const SizedBox(width:8),
          Expanded(flex:3,child:TextField(controller:f['value'] as TextEditingController,decoration:InputDecoration(labelText:f['type']=='link'?'Link':'Valoare',hintText:f['type']=='link'?'https://...':'Text'))),const SizedBox(width:8),
          SizedBox(width:110,child:DropdownButtonFormField<String>(value:f['type'] as String,decoration:const InputDecoration(labelText:'Tip'),items:const[DropdownMenuItem(value:'text',child:Text('Text')),DropdownMenuItem(value:'link',child:Text('Link'))],onChanged:(v){if(v!=null)setD(()=>f['type']=v);})),
          IconButton(tooltip:'Șterge',onPressed:()=>setD(()=>fields.removeAt(i)),icon:const Icon(Icons.remove_circle_outline)),
        ]));}),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează'))],
    )))??false;
    if(saved){
      final out=<Map<String,String>>[];
      for(final f in fields){final label=(f['label'] as TextEditingController).text.trim();final value=(f['value'] as TextEditingController).text.trim();if(label.isNotEmpty||value.isNotEmpty)out.add({'label':label,'value':value,'type':f['type'] as String});}
      try{
        await FirebaseFirestore.instance.collection('users').doc(widget.user.id).set({
          'name':name.text.trim(),'nickname':nickname.text.trim(),'useNickname':useNickname,'phone':phone.text.trim(),'phoneNormalized':phone.text.replaceAll(RegExp(r'[^0-9]'),''),
          'hireDate':hireDate==null?null:Timestamp.fromDate(hireDate!),'contractFunction':contractFunction.text.trim(),'photoBase64':photo,'profileFields':out,'updatedAt':FieldValue.serverTimestamp(),
        },SetOptions(merge:true));
        if(mounted)showSuccessMessage(context,'Profilul a fost actualizat.');
      }catch(e){if(mounted)showErrorMessage(context,'Profilul nu a putut fi salvat: $e');}
    }
    name.dispose();nickname.dispose();phone.dispose();contractFunction.dispose();
    for(final f in fields){(f['label'] as TextEditingController).dispose();(f['value'] as TextEditingController).dispose();}
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Profil')),body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('users').doc(widget.user.id).snapshots(),
    builder:(context,snap){
      final d=snap.data?.data()??<String,dynamic>{};final display=_profileDisplayName(d,fallback:widget.user.name);final photo=_photoFromData((d['photoBase64']??'').toString());
      final hire=_dateFromRaw(d['hireDate']);final employment=hire==null?null:calculateEmploymentParts(hire, now: DateTime.now());
      final teamId=(d['teamId']??widget.user.teamId)?.toString();
      final rawFields=d['profileFields'];final fields=<Map<String,String>>[];if(rawFields is List){for(final raw in rawFields){if(raw is Map){final label=(raw['label']??'').toString().trim();final value=(raw['value']??'').toString().trim();final type=(raw['type']??'text').toString();if(label.isNotEmpty||value.isNotEmpty)fields.add({'label':label,'value':value,'type':type});}}}
      return ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          GestureDetector(
            onTap:photo==null?null:()=>showProfilePhotoViewer(context,(d['photoBase64']??'').toString(),display),
            child:CircleAvatar(radius:48,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person,size:46):null),
          ),const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),if((d['nickname']??'').toString().trim().isNotEmpty&&display!=(d['name']??'').toString())Text((d['name']??'').toString()),if((d['contractFunction']??'').toString().trim().isNotEmpty)Text((d['contractFunction']??'').toString()),Text(widget.user.email,style:Theme.of(context).textTheme.bodySmall),if((d['phone']??'').toString().trim().isNotEmpty)Text((d['phone']??'').toString()),if(widget.user.functionIds.isNotEmpty)...[const SizedBox(height:8),memberBadgeStripWidget(widget.functionDefinitions,widget.user.functionIds,size:40)]])),
          FilledButton.tonalIcon(onPressed:()=>_editProfile(d),icon:const Icon(Icons.edit_outlined),label:const Text('Editează')),
        ]))),
        if(fields.isNotEmpty)...[const SizedBox(height:10),Card(child:Column(children:fields.map((f){final link=f['type']=='link';return ListTile(leading:Icon(link?Icons.link:Icons.info_outline),title:Text(f['label']!.isEmpty?'Informație':f['label']!),subtitle:Text(f['value']??''),trailing:link?const Icon(Icons.open_in_new):null,onTap:link?()=>_openLink(f['value']??''):null);}).toList()))],
        const SizedBox(height:12),
        if(employment==null)const _InfoCard(icon:Icons.event_outlined,title:'Perioada de angajare',text:'Completează data angajării din Editare profil pentru calculul perioadei.')
        else _InfoCard(icon:Icons.event_available_outlined,title:'Perioada de angajare',text:'${employment.years} ani · ${employment.months} luni · ${employment.days} zile  |  ${employment.totalDays} zile calendaristice de la angajare'),
        const SizedBox(height:12),
        _ProfileLiveStats(teamId:teamId,memberId:widget.user.id),
      ]);
    },
  ));
}

