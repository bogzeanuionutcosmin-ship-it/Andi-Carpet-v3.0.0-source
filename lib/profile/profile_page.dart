part of '../main.dart';

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
  int _daysInMonth(int year,int month)=>DateTime(year,month+1,0).day;
  ({int years,int months,int days,int totalDays}) _employmentParts(DateTime start){
    final now=DateTime.now();
    if(start.isAfter(now))return (years:0,months:0,days:0,totalDays:0);
    var totalMonths=(now.year-start.year)*12+(now.month-start.month);
    DateTime anchorFor(int months){final y=start.year+((start.month-1+months)~/12);final m=((start.month-1+months)%12)+1;final d=math.min(start.day,_daysInMonth(y,m));return DateTime(y,m,d);}
    var anchor=anchorFor(totalMonths);if(anchor.isAfter(now)){totalMonths--;anchor=anchorFor(totalMonths);}
    return (years:totalMonths~/12,months:totalMonths%12,days:now.difference(anchor).inDays,totalDays:now.difference(start).inDays);
  }
  double _hours(Iterable<CentralizerRecord> rows)=>rows.fold<double>(0,(sum,r)=>sum+(r.duration?.inMinutes??0)/60.0);
  String _hoursText(double v)=>'${v.toStringAsFixed(v>=10?1:2)} h';
  Set<String> _workedDayKeys(Iterable<CentralizerRecord> rows)=>rows.map((r){final d=r.startedAt??r.finishedAt!;return '${d.year}-${two(d.month)}-${two(d.day)}';}).toSet();

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

  Widget _statCard(BuildContext context,String title,String value,IconData icon)=>SizedBox(width:210,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(title)]))));

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Profil')),body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('users').doc(widget.user.id).snapshots(),
    builder:(context,snap){
      final d=snap.data?.data()??<String,dynamic>{};final display=_profileDisplayName(d,fallback:widget.user.name);final photo=_photoFromData((d['photoBase64']??'').toString());
      final hire=_dateFromRaw(d['hireDate']);final employment=hire==null?null:_employmentParts(hire);
      final teamId=widget.user.teamId;final completed=widget.records.where((r)=>teamId!=null&&r.teamId==teamId&&r.completed).toList();final now=DateTime.now();
      final today=completed.where((r){final x=r.startedAt??r.finishedAt;return x!=null&&sameDay(x,now);}).toList();
      final month=completed.where((r){final x=r.startedAt??r.finishedAt;return x!=null&&x.year==now.year&&x.month==now.month;}).toList();
      final year=completed.where((r){final x=r.startedAt??r.finishedAt;return x!=null&&x.year==now.year;}).toList();
      final myPer=widget.perDiems.where((x)=>x.memberId==widget.user.id&&(x.received==true||x.status==PerDiemStatus.confirmed)).toList();
      final perMonth=myPer.where((x)=>x.date.year==now.year&&x.date.month==now.month).fold<double>(0,(a,b)=>a+b.amount);final perYear=myPer.where((x)=>x.date.year==now.year).fold<double>(0,(a,b)=>a+b.amount);final perAll=myPer.fold<double>(0,(a,b)=>a+b.amount);
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
        Text('Statistici angajat',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:8),
        if(employment==null)const _InfoCard(icon:Icons.event_outlined,title:'Perioada de angajare',text:'Completează data angajării din Editare profil pentru calculul perioadei.')
        else _InfoCard(icon:Icons.event_available_outlined,title:'Perioada de angajare',text:'${employment.years} ani · ${employment.months} luni · ${employment.days} zile  |  ${employment.totalDays} zile calendaristice de la angajare'),
        const SizedBox(height:8),
        Wrap(spacing:10,runSpacing:10,children:[
          _statCard(context,'Zile lucrate luna curentă','${_workedDayKeys(month).length}',Icons.calendar_view_month),
          _statCard(context,'Zile lucrate anul curent','${_workedDayKeys(year).length}',Icons.calendar_today_outlined),
          _statCard(context,'Ore lucrate azi',_hoursText(_hours(today)),Icons.schedule),
          _statCard(context,'Ore lucrate luna curentă',_hoursText(_hours(month)),Icons.more_time),
          _statCard(context,'Ore lucrate anul curent',_hoursText(_hours(year)),Icons.access_time_filled),
        ]),
        const SizedBox(height:10),
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Diurne încasate',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Luna curentă: ${perMonth.toStringAsFixed(2)} lei'),Text('Anul curent: ${perYear.toStringAsFixed(2)} lei'),Text('Total: ${perAll.toStringAsFixed(2)} lei')]))),
        const SizedBox(height:8),
        Text('Notă: orele și zilele de lucru sunt calculate din intervențiile finalizate ale echipei la care este alocat contul.',style:Theme.of(context).textTheme.bodySmall),
      ]);
    },
  ));
}

