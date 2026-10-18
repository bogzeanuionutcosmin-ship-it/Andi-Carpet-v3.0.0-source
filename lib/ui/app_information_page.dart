part of '../main.dart';

class AppInformationPage extends StatelessWidget {
  final AppSettings settings;
  final bool isAdmin;
  const AppInformationPage({super.key,required this.settings,this.isAdmin=false});

  static const List<Map<String,String>> _builtInHistory=<Map<String,String>>[
    {'version':'3.0.0+32','title':'Finalizare v3.0.0 · mesaje automate și curățare','summary':'Mesajul automat inițial către locații se trimite în ziua calendaristică precedentă intervenției, la ora configurată de Admin (implicit 10:00), în loc de 24 de ore înainte. Data modificată anulează programarea veche înainte de trimitere.'},
    {'version':'3.0.0+31','title':'Interfață unificată, badge-uri și stickere BRC','summary':'Iconuri vizuale consistente în Dashboard, Admin Panel și navigare, badge-uri refăcute complet și previzualizare mărită la hover/tap, plus un set nou de stickere BRC disponibile în chatul comun și conversațiile private.'},
    {'version':'2.0.10+30','title':'Ecusoane premium, Chat comun și profil extins','summary':'Ecusoane semi-3D mari cu contur în culoarea funcției, ștergerea funcțiilor cu eliminare automată de la membri, Chat live comun deschis direct cu istoric limitat și retenție scurtă, plus vizualizare mărită/zoom pentru pozele de profil.'},
    {'version':'2.0.9+29','title':'Profil, Setări, Chat live și Despre','summary':'Schimbarea rapidă între conturi reîncarcă acum complet identitatea și drepturile. Profilul a fost separat de Setări, au fost adăugate statistici de angajat, poreclă pentru afișarea internă, funcție conform CIM și câmpuri/linkuri suplimentare. Chat live are acces direct și emoticoane Andi. Pagina Despre include capacitățile aplicației și istoricul update-urilor. Au fost pregătite și butoanele de instalare Android/Apple.'},
    {'version':'2.0.8+28','title':'Branding, fațade, Centralizator și Decont compact','summary':'Branding global cu logo-uri și fundaluri tematice, SMS cu data exactă a intervenției, fațadă planificată/realizată, Centralizator PDF grupat pe locație și Decont tabelar. OCR-ul păstrează doar datele structurate, nu fotografia bonului/facturii. Au fost adăugate Calcule generale anual/all-time și desfășurătorul sumelor primite.'},
    {'version':'2.0.7+27','title':'Web, conturi și fonturi','summary':'Corecții pentru geocodarea punctelor de plecare/sosire pe Web, începutul sistemului de comutare rapidă între două conturi, ascunderea contului Admin și refacerea selecției de font.'},
    {'version':'2.0.6+26','title':'Stabilizare pornire Android','summary':'Hotfix pentru crash-ul de startup WorkManager/Room produs de optimizarea R8 în release. Build-ul Android a fost stabilizat pentru utilizarea internă.'},
    {'version':'2.0.5+25','title':'Detectarea sosirii și Android release','summary':'Detectare asistată a sosirii lângă locația programată, întrebare înainte de începerea lucrului, strategie GPS economic/high accuracy și corecții pentru build-ul Android release.'},
    {'version':'2.0.4+23','title':'SMS manageri prin telefonul Android','summary':'Gateway SMS folosind SIM-ul telefonului Android, contacte de locație, mesaje automate înainte de intervenție, actualizări la reprogramare/amânare și protecție anti-dubluri.'},
    {'version':'2.0.3+22','title':'Traseu complet și Dashboard locație','summary':'Punct de plecare și punct final/retur la START, calcul complet al kilometrilor/consumului/timpului și afișarea inteligibilă a locației membrilor fără coordonate brute.'},
    {'version':'2.0.2+21','title':'Push automat și PWA','summary':'Înregistrarea automată a dispozitivului pentru notificări push și îmbunătățiri pentru experiența de instalare/utilizare PWA.'},
    {'version':'2.0.1+20','title':'Compatibilitate Web','summary':'Corecții de compilare Web pentru setările native și API-ul File Picker.'},
    {'version':'2.0.0','title':'Pachet funcțional complet','summary':'Integrarea într-un singur proiect a Learning-ului, Dashboard-ului, rutării, hărții, Centralizatorului, Decontului, OCR-ului, notificărilor și pregătirii multiplatformă.'},
    {'version':'1.9.0','title':'Localizare nativă și autentificare','summary':'Extinderea localizării pe Android/iOS și autentificare cu email, username sau telefon.'},
    {'version':'1.8.0','title':'Vizual, PDF și fundaluri','summary':'Îmbunătățiri de interfață, export PDF, branding și fundaluri.'},
    {'version':'1.7.0','title':'Dashboard și Learning extins','summary':'Dashboard operațional, explicații și indicatori Learning, estimări și istoric.'},
    {'version':'1.6.0','title':'Learning core','summary':'Baza sistemului Learning: istoric de execuție, durate, rutare, motive și reguli de încredere.'},
    {'version':'1.5.x','title':'Fundația aplicației conectate','summary':'Firebase, conturi, echipe, grafice, hartă, centralizator, decont, chat și primele notificări.'},
  ];

  Future<void> _addManualHistory(BuildContext context) async {
    if(!isAdmin)return;
    final version=TextEditingController();
    final title=TextEditingController();
    final summary=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Adaugă în istoricul update-urilor'),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:version,decoration:const InputDecoration(labelText:'Versiune',hintText:'ex: 2.0.10+30')),
        const SizedBox(height:10),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Titlu update')),
        const SizedBox(height:10),
        TextField(controller:summary,minLines:4,maxLines:8,decoration:const InputDecoration(labelText:'Ce s-a adăugat / modificat')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:(){if(version.text.trim().isNotEmpty&&summary.text.trim().isNotEmpty)Navigator.pop(c,true);},child:const Text('Salvează'))],
    ))??false;
    if(ok){
      try{
        await FirebaseFirestore.instance.collection('updateHistory').add({
          'version':version.text.trim(),'title':title.text.trim(),'summary':summary.text.trim(),
          'createdAt':FieldValue.serverTimestamp(),'createdBy':FirebaseAuth.instance.currentUser?.uid??'',
        });
        if(context.mounted)showSuccessMessage(context,'Intrarea a fost adăugată în istoricul update-urilor.');
      }catch(e){if(context.mounted)showErrorMessage(context,'Istoricul nu a putut fi salvat: $e');}
    }
    version.dispose();title.dispose();summary.dispose();
  }

  Widget _history(BuildContext context)=>Column(children:[
    if(isAdmin)Padding(padding:const EdgeInsets.fromLTRB(14,12,14,0),child:Align(alignment:Alignment.centerRight,child:FilledButton.tonalIcon(onPressed:()=>_addManualHistory(context),icon:const Icon(Icons.add),label:const Text('Adaugă manual')))),
    Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('updateHistory').orderBy('createdAt',descending:true).snapshots(),
      builder:(context,snap){
        final manual=snap.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[];
        return ListView(padding:const EdgeInsets.all(14),children:[
          if(manual.isNotEmpty)...[
            const Text('Adăugate manual',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            ...manual.map((doc){final d=doc.data();final raw=d['createdAt'];final dt=raw is Timestamp?raw.toDate():null;return Card(child:ListTile(
              leading:const Icon(Icons.new_releases_outlined),
              title:Text('${(d['version']??'Versiune').toString()}${(d['title']??'').toString().trim().isEmpty?'':' · ${(d['title']??'').toString()}'}',style:const TextStyle(fontWeight:FontWeight.w900)),
              subtitle:Text('${(d['summary']??'').toString()}${dt==null?'':'\n${formatDate(dt)}'}'),isThreeLine:true,
            ));}),
            const SizedBox(height:12),
          ],
          const Text('Istoric inclus în aplicație',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          ..._builtInHistory.map((e)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${e['version']} · ${e['title']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:5),Text(e['summary']??'',style:const TextStyle(height:1.3)),
          ])))),
        ]);
      },
    )),
  ]);

  @override Widget build(BuildContext context)=>DefaultTabController(length:2,child:Scaffold(
    body:_AppBackdrop(settings:settings,child:SafeArea(child:Column(children:[
      Material(color:Theme.of(context).colorScheme.surface.withValues(alpha:.96),child:Column(children:[
        Row(children:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back)),const Expanded(child:Text('Despre Andi Carpetă',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),Padding(padding:const EdgeInsets.only(right:12),child:Text('v$_appVersionLabel'))]),
        const TabBar(tabs:[Tab(icon:Icon(Icons.auto_awesome_outlined),text:'Capacități'),Tab(icon:Icon(Icons.history),text:'Istoric update')]),
      ])),
      Expanded(child:TabBarView(children:[app_capabilities.AppCapabilitiesView(),_history(context)])),
    ]))),
  ));
}

