part of '../main.dart';

class SmsManagerGatewayCard extends StatefulWidget {
  const SmsManagerGatewayCard({super.key});
  @override State<SmsManagerGatewayCard> createState()=>_SmsManagerGatewayCardState();
}

class _SmsManagerGatewayCardState extends State<SmsManagerGatewayCard> {
  bool _busy=false;
  bool _enabled=false;
  bool _permission=false;
  String _deviceId='';
  String _lastError='';
  int _lastCheckAt=0;
  int _lastSentAt=0;

  bool get _androidNative => !kIsWeb && defaultTargetPlatform==TargetPlatform.android;

  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_refresh());}

  Future<void> _refresh() async {
    if(!_androidNative||!mounted)return;
    try{
      final raw=await _smsGatewayChannel.invokeMapMethod<String,dynamic>('gatewayStatus')??<String,dynamic>{};
      if(!mounted)return;
      setState((){
        _enabled=raw['enabled']==true;
        _permission=raw['permission']==true;
        _deviceId=(raw['deviceId']??'').toString();
        _lastError=(raw['lastError']??'').toString();
        _lastCheckAt=(raw['lastCheckAt'] is num)?(raw['lastCheckAt'] as num).toInt():0;
        _lastSentAt=(raw['lastSentAt'] is num)?(raw['lastSentAt'] as num).toInt():0;
      });
    }catch(e){if(mounted)setState(()=>_lastError=e.toString());}
  }

  String _stamp(int value){
    if(value<=0)return 'niciodată';
    final d=DateTime.fromMillisecondsSinceEpoch(value);
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<http.Response> _adminPost(String url, Map<String,dynamic> body) async {
    final user=FirebaseAuth.instance.currentUser;
    final token=await user?.getIdToken(true);
    if(token==null||token.isEmpty)throw StateError('Sesiunea Admin nu este disponibilă.');
    return http.post(Uri.parse(url),headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},body:jsonEncode(body));
  }

  Future<void> _enable() async {
    if(!_androidNative||_busy)return;
    setState(()=>_busy=true);
    try{
      final prepared=await _smsGatewayChannel.invokeMapMethod<String,dynamic>('prepareGateway')??<String,dynamic>{};
      final deviceId=(prepared['deviceId']??'').toString();
      final secret=(prepared['secret']??'').toString();
      if(deviceId.isEmpty||secret.isEmpty)throw StateError('Telefonul nu a generat identitatea gateway.');
      final response=await _adminPost(_registerSmsGatewayUrl,{'deviceId':deviceId,'secret':secret});
      if(response.statusCode<200||response.statusCode>=300)throw StateError('Înregistrare server: HTTP ${response.statusCode} ${response.body}');
      await _smsGatewayChannel.invokeMethod('configureGateway',{'deviceId':deviceId,'secret':secret});
      await _refresh();
      if(mounted)showSuccessMessage(context,'Telefonul este acum expeditorul automat SMS Andi Carpet.');
    }on PlatformException catch(e){
      if(mounted)showErrorMessage(context,e.message??e.code);
    }catch(e){if(mounted)showErrorMessage(context,e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _disable() async {
    if(!_androidNative||_busy)return;
    setState(()=>_busy=true);
    try{
      final response=await _adminPost(_disableSmsGatewayUrl,const{});
      if(response.statusCode<200||response.statusCode>=300)throw StateError('Dezactivare server: HTTP ${response.statusCode}');
      await _smsGatewayChannel.invokeMethod('disableGateway');
      await _refresh();
      if(mounted)showSuccessMessage(context,'Trimiterea automată SMS a fost oprită.');
    }catch(e){if(mounted)showErrorMessage(context,e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _runNow() async {
    if(!_androidNative)return;
    await _smsGatewayChannel.invokeMethod('runGatewayNow');
    if(mounted)showSuccessMessage(context,'Verificarea SMS a fost pornită.');
    await Future<void>.delayed(const Duration(seconds:2));
    await _refresh();
  }

  Future<void> _testSms() async {
    if(!_androidNative)return;
    final phone=TextEditingController();
    final result=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('SMS de test'),
      content:TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Număr telefon',hintText:'07xxxxxxxx')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,phone.text.trim()),child:const Text('Trimite'))],
    ));
    phone.dispose();
    if(result==null||result.isEmpty)return;
    try{
      await _smsGatewayChannel.invokeMethod('sendTestSms',{'phone':result,'message':'Test Andi Carpet: trimiterea automată SMS de pe telefonul gateway funcționează.'});
      if(mounted)showSuccessMessage(context,'SMS-ul de test a fost predat telefonului pentru trimitere.');
    }on PlatformException catch(e){if(mounted)showErrorMessage(context,e.message??e.code);}
  }

  @override Widget build(BuildContext context){
    if(!_androidNative){
      return Card(child:ListTile(
        leading:const Icon(Icons.sms_outlined),
        title:const Text('SMS automat manageri'),
        subtitle:const Text('Gateway-ul SMS se activează o singură dată din aplicația Android instalată pe telefonul care are SIM-ul expeditor. După activare, mesajele pleacă automat de pe acel număr.'),
      ));
    }
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(_enabled?Icons.sms:Icons.sms_outlined,color:_enabled?Colors.green:null),const SizedBox(width:10),const Expanded(child:Text('SMS automat manageri · Andi Carpet',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold))),Switch(value:_enabled,onChanged:_busy?null:(v)=>v?_enable():_disable())]),
      const SizedBox(height:5),
      Text(_enabled?'Acest Android trimite automat SMS-urile prin SIM-ul lui. Verificarea rulează și în fundal aproximativ la 15 minute.':'Activează pe telefonul Android care are numărul de pe care vrei să plece mesajele.'),
      const SizedBox(height:8),
      Text('Permisiune SMS: ${_permission?'acordată':'neacordată'} · Ultima verificare: ${_stamp(_lastCheckAt)} · Ultimul SMS: ${_stamp(_lastSentAt)}',style:Theme.of(context).textTheme.bodySmall),
      if(_deviceId.isNotEmpty)Text('Gateway: $_deviceId',style:Theme.of(context).textTheme.bodySmall),
      if(_lastError.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text('Ultima eroare: $_lastError',style:TextStyle(color:Theme.of(context).colorScheme.error,fontSize:12))),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton.icon(onPressed:_enabled&&!_busy?_runNow:null,icon:const Icon(Icons.sync),label:const Text('Verifică acum')),
        OutlinedButton.icon(onPressed:_enabled&&!_busy?_testSms:null,icon:const Icon(Icons.send_outlined),label:const Text('SMS test')),
        IconButton(onPressed:_busy?null:_refresh,tooltip:'Actualizează starea',icon:_busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.refresh)),
      ]),
      const SizedBox(height:6),
      const Text('Regulă: mesaj inițial cu o zi înainte; dacă data se schimbă, locația se amână sau ETA se modifică cu cel puțin 60 de minute, managerul este informat din nou. Mesajele folosesc numele Andi Carpet.',style:TextStyle(fontSize:12)),
    ])));
  }
}

