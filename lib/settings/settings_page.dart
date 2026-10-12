part of '../main.dart';

class SettingsPage extends StatefulWidget {
  final AppUser user;
  final List<AppNotification> notifications;
  final AppSettings settings;
  final VoidCallback onChanged;
  final VoidCallback onThemeChanged;
  final VoidCallback? onAdmin;
  final VoidCallback onLogout;
  const SettingsPage({super.key,required this.user,required this.notifications,required this.settings,required this.onChanged,required this.onThemeChanged,required this.onAdmin,required this.onLogout});
  @override State<SettingsPage> createState()=>_SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>{
  List<_QuickAccount> _quickAccounts=<_QuickAccount>[];bool _quickAccountsLoading=true;bool _quickAccountBusy=false;
  @override void initState(){super.initState();unawaited(_refreshQuickAccounts());}
  String _themeLabel(AppThemeChoice v)=>switch(v){AppThemeChoice.light=>'Luminos',AppThemeChoice.dark=>'Întunecat',AppThemeChoice.system=>'Sistem'};
  Future<void> _refreshQuickAccounts()async{try{final x=await _loadQuickAccounts();if(mounted)setState((){_quickAccounts=x;_quickAccountsLoading=false;});}catch(e){if(mounted){setState(()=>_quickAccountsLoading=false);showErrorMessage(context,'Nu pot citi conturile memorate din stocarea securizată: $e');}}}
  Future<void> _updateOwn(Map<String,dynamic> data,{String? success})async{try{await FirebaseFirestore.instance.collection('users').doc(widget.user.id).set({...data,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));if(success!=null&&mounted)showSuccessMessage(context,success);}catch(e){if(mounted)showErrorMessage(context,'Nu s-a putut salva: $e');}}
  Future<void> _rememberCurrentQuickAccount()async{
    final authUser=FirebaseAuth.instance.currentUser;final mail=(authUser?.email??widget.user.email).trim();if(authUser==null||mail.isEmpty||_quickAccountBusy)return;
    final controller=TextEditingController();final pass=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Memorează contul'),content:TextField(controller:controller,obscureText:true,decoration:InputDecoration(labelText:'Parola pentru $mail')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text),child:const Text('Memorează'))]));controller.dispose();if(pass==null||pass.isEmpty)return;
    setState(()=>_quickAccountBusy=true);try{final credential = EmailAuthProvider.credential(email:mail,password:pass);await authUser.reauthenticateWithCredential(credential);final a=await _loadQuickAccounts();a.removeWhere((x)=>x.email.toLowerCase()==mail.toLowerCase());while(a.length>=2){a.removeAt(0);}a.add(_QuickAccount(email:mail,password:pass));await _saveQuickAccounts(a);if(mounted)setState(()=>_quickAccounts=a);}on FirebaseAuthException catch(e){if(mounted)showErrorMessage(context,'Autentificare nereușită: ${e.message ?? e.code}');}catch(e){if(mounted)showErrorMessage(context,'Salvarea locală a contului a eșuat: $e');}finally{if(mounted)setState(()=>_quickAccountBusy=false);}
  }
  Future<void> _switchQuickAccount(_QuickAccount account)async{if(_quickAccountBusy)return;setState(()=>_quickAccountBusy=true);try{await FirebaseAuth.instance.signInWithEmailAndPassword(email:account.email,password:account.password);if(mounted)showSuccessMessage(context,'Cont schimbat pe ${account.email}.');}catch(e){if(mounted)showErrorMessage(context,'Nu am putut schimba contul. Memorează din nou parola dacă a fost schimbată.');}finally{if(mounted)setState(()=>_quickAccountBusy=false);}}
  Future<void> _forgetQuickAccounts()async{try{await _quickAccountStorage.delete(key:_quickAccountsStorageKey);if(mounted)setState(()=>_quickAccounts=<_QuickAccount>[]);}catch(_){if(mounted)showErrorMessage(context,'Nu am putut șterge conturile salvate din spațiul securizat al dispozitivului.');}}

  Map<String,bool> _prefs(Map<String,dynamic> d){final raw=d['notificationPreferences'];final m=<String,bool>{'chat':true,'schedule':true,'arrival':true,'decont':true,'learning':true,'general':true};if(raw is Map){for(final k in m.keys){if(raw[k] is bool)m[k]=raw[k] as bool;}}return m;}
  Future<void> _setPref(Map<String,bool> prefs,String key,bool value)async{prefs[key]=value;setState((){});await _updateOwn({'notificationPreferences':prefs},success:'Preferința de notificare a fost salvată.');}

  @override Widget build(BuildContext context)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(widget.user.id).snapshots(),builder:(context,snap){
    final d=snap.data?.data()??<String,dynamic>{};final locationMode=(d['locationMode']??'economic').toString();final interval=(d['locationIntervalMinutes'] is num)?(d['locationIntervalMinutes'] as num).toInt().clamp(1,60).toInt():10;final prefs=_prefs(d);
    final mine=widget.notifications.where((n)=>n.userId==widget.user.id).toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt));final unread=mine.where((n)=>!n.read).toList();
    return _Page(title:'Setări',subtitle:'Preferințe personale și cont',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Aspect',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        DropdownButtonFormField<AppThemeChoice>(value:widget.settings.theme,decoration:const InputDecoration(labelText:'Temă'),items:AppThemeChoice.values.map((v)=>DropdownMenuItem(value:v,child:Text(_themeLabel(v)))).toList(),onChanged:(v)async{if(v==null)return;setState(()=>widget.settings.theme=v);widget.onThemeChanged();await _updateOwn({'theme':v.name});}),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:_normalizeFontChoice(widget.settings.fontFamily),decoration:const InputDecoration(labelText:'Font'),items:const[DropdownMenuItem(value:'System',child:Text('System')),DropdownMenuItem(value:'Sans',child:Text('Sans')),DropdownMenuItem(value:'Serif',child:Text('Serif')),DropdownMenuItem(value:'Monospace',child:Text('Monospace')),DropdownMenuItem(value:'Cursive',child:Text('Cursive'))],onChanged:(v)async{if(v==null)return;setState(()=>widget.settings.fontFamily=v);widget.onThemeChanged();await _updateOwn({'fontFamily':v});}),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Notificări',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:4),const Text('Poți opri categoriile opționale. Mesajele trimise de Admin și notificările importante de sistem rămân active.'),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['chat']!,onChanged:(v)=>_setPref(prefs,'chat',v),title:const Text('Chat live')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['schedule']!,onChanged:(v)=>_setPref(prefs,'schedule',v),title:const Text('Grafic și traseu')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['arrival']!,onChanged:(v)=>_setPref(prefs,'arrival',v),title:const Text('Sosire și locație')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['decont']!,onChanged:(v)=>_setPref(prefs,'decont',v),title:const Text('Decont și diurne')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['learning']!,onChanged:(v)=>_setPref(prefs,'learning',v),title:const Text('Learning și recomandări')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['general']!,onChanged:(v)=>_setPref(prefs,'general',v),title:const Text('Alte notificări operaționale')),
        const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.lock_outline),title:Text('Admin & Sistem'),subtitle:Text('Întotdeauna active'),trailing:Icon(Icons.check_circle,color:Colors.green)),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Locație',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        DropdownButtonFormField<String>(value:['live','economic','offline'].contains(locationMode)?locationMode:'economic',decoration:const InputDecoration(labelText:'Mod locație'),items:const[DropdownMenuItem(value:'live',child:Text('Live · precizie mai mare')),DropdownMenuItem(value:'economic',child:Text('Economic')),DropdownMenuItem(value:'offline',child:Text('Offline în afara programului'))],onChanged:(v)async{if(v!=null){await _updateOwn({'locationMode':v});if(v=='offline')await FirebaseFirestore.instance.collection('liveLocations').doc(widget.user.id).delete();}}),
        const SizedBox(height:10),
        DropdownButtonFormField<int>(value:[1,2,3,5,10,15,30,60].contains(interval)?interval:10,decoration:const InputDecoration(labelText:'Interval mod economic'),items:const[1,2,3,5,10,15,30,60].map((v)=>DropdownMenuItem(value:v,child:Text('$v minute'))).toList(),onChanged:(v)async{if(v!=null)await _updateOwn({'locationIntervalMinutes':v});}),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Schimbare rapidă între conturi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:6),
        if(_quickAccountsLoading)const LinearProgressIndicator()else Builder(builder:(context){final current=(FirebaseAuth.instance.currentUser?.email??widget.user.email).toLowerCase();final saved=_quickAccounts.any((a)=>a.email.toLowerCase()==current);final others=_quickAccounts.where((a)=>a.email.toLowerCase()!=current).toList();return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          OutlinedButton.icon(onPressed:_quickAccountBusy?null:_rememberCurrentQuickAccount,icon:Icon(saved?Icons.refresh:Icons.save_outlined),label:Text(saved?'Actualizează parola contului':'Memorează contul curent')),
          ...others.map((a)=>Padding(padding:const EdgeInsets.only(top:7),child:FilledButton.icon(onPressed:_quickAccountBusy?null:()=>_switchQuickAccount(a),icon:const Icon(Icons.swap_horiz),label:Text('Comută pe ${a.email}')))),
          if(_quickAccounts.isNotEmpty)TextButton.icon(onPressed:_quickAccountBusy?null:_forgetQuickAccounts,icon:const Icon(Icons.delete_outline),label:const Text('Șterge conturile memorate')),
        ]);}),
      ]))),
      const SizedBox(height:10),
      Card(child:ExpansionTile(leading:Badge(isLabelVisible:unread.isNotEmpty,label:Text('${unread.length}'),child:const Icon(Icons.notifications_outlined)),title:const Text('Istoric notificări'),subtitle:Text('${unread.length} necitite · ${mine.length} total'),children:mine.isEmpty?[const ListTile(title:Text('Nu ai notificări.'))]:mine.take(30).map((n)=>ListTile(title:Text(n.title,style:TextStyle(fontWeight:n.read?FontWeight.w500:FontWeight.w900)),subtitle:Text('${n.message}\n${formatDate(n.createdAt)} · ${timeText(n.createdAt)}'),isThreeLine:true,onTap:n.read?null:()async{n.read=true;await FirebaseFirestore.instance.collection('notifications').doc(n.id).set({'read':true,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));widget.onChanged();})).toList())),
      const SizedBox(height:10),
      if(widget.onAdmin!=null)...[
        // Contul Admin nu poate fi făcut vizibil din profil.
        // Protecția la nivel de citire Firestore necesită migrarea interogărilor users.
        const SmsManagerGatewayCard(),const SizedBox(height:10),
      ],
      Card(child:ListTile(leading:const Icon(Icons.notifications_active_outlined),title:const Text('Diagnostic Push'),subtitle:const Text('Verifică permisiunea și înregistrarea dispozitivului.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PushDiagnosticsPage(userId:widget.user.id))))),
      Card(child:ListTile(leading:const Icon(Icons.feedback_outlined),title:const Text('Feedback'),subtitle:const Text('Raportează o eroare sau trimite o sugestie.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FeedbackPage(currentUser:widget.user))))),
      if(widget.onAdmin!=null)Card(child:ListTile(leading:const Icon(Icons.admin_panel_settings),title:const Text('Admin Panel'),trailing:FilledButton(onPressed:widget.onAdmin,child:const Text('Deschide')))),
      Card(child:ListTile(leading:const Icon(Icons.logout),title:const Text('Ieșire din cont'),trailing:OutlinedButton(onPressed:widget.onLogout,child:const Text('Ieși')))),
    ]));
  });
}

