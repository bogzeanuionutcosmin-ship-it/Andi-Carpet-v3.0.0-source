part of '../main.dart';

class MessagesContactsPage extends StatefulWidget {
  final List<Location> locations;
  final AppSettings settings;
  final bool canEditContacts;
  final bool canManageTemplates;
  final VoidCallback onChanged;
  final void Function(String,String) log;
  const MessagesContactsPage({super.key,required this.locations,required this.settings,required this.canEditContacts,required this.canManageTemplates,required this.onChanged,required this.log});
  @override State<MessagesContactsPage> createState()=>_MessagesContactsPageState();
}

class _MessagesContactsPageState extends State<MessagesContactsPage>{
  final search=TextEditingController();
  String query='';
  @override void dispose(){search.dispose();super.dispose();}

  Future<void> _call(String phone) async {
    final clean=phone.trim();
    if(clean.isEmpty)return;
    final uri=Uri(scheme:'tel',path:clean);
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)showErrorMessage(context,'Telefonul nu poate deschide apelul pentru $clean.');
  }

  Future<LocationContact?> _contactDialog([LocationContact? existing]) async {
    final name=TextEditingController(text:existing?.name??'');
    final phone=TextEditingController(text:existing?.phone??'');
    var role=(existing?.role.trim().isNotEmpty??false)?existing!.role:'Manager';
    if(!const ['Manager','Casierie','Alt contact'].contains(role))role='Alt contact';
    var smsEnabled=existing?.smsEnabled??true;
    final result=await showDialog<LocationContact>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(existing==null?'Adaugă număr locație':'Editează contact'),
      content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Tip contact'),items:const[
          DropdownMenuItem(value:'Manager',child:Text('Manager')),
          DropdownMenuItem(value:'Casierie',child:Text('Casierie')),
          DropdownMenuItem(value:'Alt contact',child:Text('Alt contact')),
        ],onChanged:(v){if(v!=null)setD(()=>role=v);}),
        const SizedBox(height:8),
        TextField(controller:name,decoration:InputDecoration(labelText:role=='Casierie'?'Nume / denumire (opțional)':'Nume contact')),
        const SizedBox(height:8),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon *')),
        const SizedBox(height:4),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:smsEnabled,onChanged:(v)=>setD(()=>smsEnabled=v),title:const Text('Primește SMS automat'),subtitle:const Text('Dacă este oprit, numărul rămâne disponibil pentru apel, dar nu primește mesajele automate ale graficului.')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:(){
        if(phone.text.trim().isEmpty){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Completează numărul de telefon.')));return;}
        final displayName=name.text.trim().isEmpty?role:name.text.trim();
        Navigator.pop(c,LocationContact(name:displayName,phone:phone.text.trim(),role:role,smsEnabled:smsEnabled));
      },child:const Text('Salvează'))],
    )));
    name.dispose();phone.dispose();return result;
  }

  Future<void> _saveContacts(Location location,List<LocationContact> contacts) async {
    try{
      await FirebaseFirestore.instance.collection('locations').doc(location.id).set({
        'contacts':contacts.map((c)=>{'name':c.name,'phone':c.phone,'role':c.role,'smsEnabled':c.smsEnabled}).toList(),
        'phone':contacts.isEmpty?null:contacts.first.phone,
        'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true));
      location.contacts=contacts;
      location.phone=contacts.isEmpty?null:contacts.first.phone;
      widget.onChanged();
      widget.log('Contacte locație modificate',location.name);
      if(mounted)showSuccessMessage(context,'Contactele pentru ${location.name} au fost salvate.');
    }catch(e){if(mounted)showErrorMessage(context,'Contactele nu au putut fi salvate: $e');}
  }

  Future<void> _editLocationContacts(Location location) async {
    if(!widget.canEditContacts)return;
    final work=location.contacts.map((c)=>LocationContact(name:c.name,phone:c.phone,role:c.role,smsEnabled:c.smsEnabled)).toList();
    final save=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(location.name),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(location.address,style:Theme.of(c).textTheme.bodySmall),
        const SizedBox(height:12),
        Row(children:[const Expanded(child:Text('Telefoane locație',style:TextStyle(fontWeight:FontWeight.w800))),FilledButton.tonalIcon(onPressed:()async{final x=await _contactDialog();if(x!=null)setD(()=>work.add(x));},icon:const Icon(Icons.add_call),label:const Text('Adaugă'))]),
        if(work.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('Nu există telefoane salvate.')),
        ...List.generate(work.length,(i){final x=work[i];return ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(backgroundColor:Colors.green.withValues(alpha:.16),child:const Icon(Icons.phone,color:Colors.green)),title:Text('${x.role} · ${x.name}'),subtitle:Text('${x.phone}${x.smsEnabled?' · SMS automat':' · doar apel'}'),trailing:Wrap(spacing:2,children:[IconButton(tooltip:'Sună',onPressed:()=>_call(x.phone),icon:const Icon(Icons.call,color:Colors.green)),IconButton(tooltip:'Editează',onPressed:()async{final next=await _contactDialog(x);if(next!=null)setD(()=>work[i]=next);},icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Șterge',onPressed:()=>setD(()=>work.removeAt(i)),icon:const Icon(Icons.delete_outline))]));}),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează'))],
    )))??false;
    if(save)await _saveContacts(location,work);
  }

  Future<void> _editTemplates() async {
    if(!widget.canManageTemplates)return;
    final initial=TextEditingController(text:widget.settings.smsTemplates['initial']??'');
    final rescheduled=TextEditingController(text:widget.settings.smsTemplates['rescheduled']??'');
    final postponed=TextEditingController(text:widget.settings.smsTemplates['postponed']??'');
    final save=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Șabloane SMS automate'),
      content:SizedBox(width:760,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _InfoCard(icon:Icons.data_object,title:'Variabile disponibile',text:'Folosește [data exactă] pentru data programată și [locație] dacă vrei să incluzi numele sălii. Mesajul inițial se trimite în ziua calendaristică anterioară intervenției, la ora ${widget.settings.smsPreviousDayTime} setată de Admin.'),
        const SizedBox(height:10),
        TextField(controller:initial,minLines:3,maxLines:6,decoration:InputDecoration(labelText:'Mesaj inițial · ziua precedentă la ${widget.settings.smsPreviousDayTime}')),
        const SizedBox(height:10),
        TextField(controller:rescheduled,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Mesaj reprogramare pe altă dată')),
        const SizedBox(height:10),
        TextField(controller:postponed,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Mesaj amânare')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează'))],
    ))??false;
    if(save){
      widget.settings.smsTemplates['initial']=initial.text.trim();
      widget.settings.smsTemplates['rescheduled']=rescheduled.text.trim();
      widget.settings.smsTemplates['postponed']=postponed.text.trim();
      try{
        await FirebaseFirestore.instance.collection('meta').doc('uiSettings').set({'smsTemplates':widget.settings.smsTemplates,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
        widget.log('Șabloane SMS modificate','Mesaje automate locații');
        widget.onChanged();
        if(mounted)showSuccessMessage(context,'Șabloanele SMS au fost salvate.');
      }catch(e){if(mounted)showErrorMessage(context,'Șabloanele nu au putut fi salvate: $e');}
    }
    initial.dispose();rescheduled.dispose();postponed.dispose();
  }

  @override Widget build(BuildContext context){
    final needle=query.trim().toLowerCase();
    final list=widget.locations.where((l){if(!l.active)return false;if(needle.isEmpty)return true;return '${l.name} ${l.address} ${l.contacts.map((e)=>'${e.name} ${e.phone} ${e.role}').join(' ')}'.toLowerCase().contains(needle);}).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _Page(title:'Mesaje & Contacte',subtitle:'Telefoane locații și mesaje automate Andi Carpet',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Caută locație, contact sau număr'))),if(widget.canManageTemplates)...[const SizedBox(width:8),FilledButton.tonalIcon(onPressed:_editTemplates,icon:const Icon(Icons.sms_outlined),label:const Text('Șabloane mesaje'))]]),
      const SizedBox(height:10),
      const _InfoCard(icon:Icons.info_outline,title:'Acces rapid',text:'Butonul verde apelează direct numărul. Contactele marcate „SMS automat” sunt cele folosite de gateway-ul Android când un grafic intră în condițiile de notificare. Editarea este controlată prin drepturile funcției.'),
      const SizedBox(height:10),
      if(list.isEmpty)const _Empty(icon:Icons.contact_phone_outlined,text:'Nu există locații pentru căutarea curentă.'),
      ...list.map((l)=>Card(child:ExpansionTile(
        leading:const CircleAvatar(backgroundColor:Color(0x1A00A86B),child:Icon(Icons.store_mall_directory_outlined,color:Colors.green)),
        title:Text(l.name,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(l.address,maxLines:2,overflow:TextOverflow.ellipsis),
        trailing:widget.canEditContacts?IconButton(tooltip:'Editează telefoanele',onPressed:()=>_editLocationContacts(l),icon:const Icon(Icons.edit_outlined)):null,
        children:[
          if(l.contacts.isEmpty)const ListTile(title:Text('Niciun telefon salvat.')),
          ...l.contacts.map((c)=>ListTile(leading:const CircleAvatar(backgroundColor:Color(0x1A00A86B),child:Icon(Icons.phone,color:Colors.green)),title:Text('${c.role} · ${c.name}'),subtitle:Text('${c.phone}${c.smsEnabled?' · SMS automat':' · doar apel'}'),trailing:IconButton(style:IconButton.styleFrom(backgroundColor:Colors.green,foregroundColor:Colors.white),tooltip:'Sună ${c.phone}',onPressed:()=>_call(c.phone),icon:const Icon(Icons.call)))),
        ],
      ))),
    ]));
  }
}


