import 'package:flutter/material.dart';

class AppCapabilitiesView extends StatelessWidget {
  const AppCapabilitiesView({super.key});

  Widget _section(BuildContext context,String title,String text,{IconData icon=Icons.info_outline})=>Card(
    child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(width:9),Expanded(child:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)))]),
      const SizedBox(height:8),Text(text,style:const TextStyle(height:1.35)),
    ])),
  );

@override
  Widget build(BuildContext context) => ListView(padding:const EdgeInsets.all(14),children:[
    _section(context,'Operațiuni zilnice și Dashboard','Dashboard-ul arată ziua de lucru, echipele active, progresul pe locații, intervenția curentă, stările de așteptare/refuz/nerealizat și estimarea de final când există suficiente date. Poți porni și opri programul, urmări progresul și vedea rapid ce a rămas de făcut.',icon:Icons.dashboard_outlined),
    _section(context,'Grafice de lucru și trasee','Poți crea grafice pe una sau mai multe zile, adăuga locații, ordona intervențiile, planifica fațade și porni traseul de la un punct ales până la punctul final/retur. Aplicația calculează distanțe, timp estimat, consum și cost de combustibil și poate recalcula traseul rămas când apar întârzieri sau schimbări.',icon:Icons.route_outlined),
    _section(context,'Execuție în locație','Pentru fiecare sală pot fi înregistrate START/STOP, așteptarea pentru acces, refuzul, nerealizarea și motivul. La final se confirmă obligatoriu dacă fațada a fost realizată atunci când modulul de fațade este folosit. Evenimentele intră în istoric și pot alimenta Learning-ul.',icon:Icons.play_circle_outline),
    _section(context,'Hartă, GPS și detectarea sosirii','Harta păstrează locațiile firmei, coordonatele lor și pozițiile live ale echipelor. Localizarea poate funcționa economic sau cu precizie ridicată, iar aplicația crește temporar precizia când te apropii de următoarea locație. La sosire poate întreba dacă începi lucrul, ești în așteptare sau nu încă.',icon:Icons.map_outlined),
    _section(context,'Centralizator și documente PDF','Intervențiile sunt centralizate pe locație și dată, cu ore, suprafață și fațadă. Exportul PDF este tabelar și compact: aceeași locație nu se repetă inutil, iar intervențiile ei sunt grupate cronologic pentru printare cu cât mai puține pagini.',icon:Icons.table_chart_outlined),
    _section(context,'Decont, OCR și calcule financiare','Bonurile și facturile pot fi scanate cu OCR. Aplicația extrage numărul, data și valoarea, clasifică documentele în combustibil/facturi/alte cheltuieli și nu păstrează fotografia scanată. Decontul include diurne, sume primite, buget rămas, sumă de recuperat și rapoarte anuale sau totale prin Calcule generale.',icon:Icons.receipt_long_outlined),
    _section(context,'Learning și estimări','Learning-ul folosește execuțiile reale, timpii, așteptările, refuzurile, ordinea aleasă, întârzierile și schimbările de traseu pentru a îmbunătăți estimările. Pentru o locație sunt necesare minimum trei execuții utile înainte ca istoricul ei să fie folosit pentru ordine și durate automate.',icon:Icons.psychology_alt_outlined),
    _section(context,'Mesaje, Chat live și notificări','Aplicația are Chat live comun pentru toți membrii, cu istoric scurt pentru economie de Firestore, mesaje necitite și emoticoane Andi. Mesajele private rămân disponibile separat din profilul membrului. Contactele managerilor/casieriei sunt legate de locații și pot fi apelate direct. Mesajele SMS automate către locații folosesc data exactă a intervenției și pot fi trimise prin telefonul Android folosit ca gateway.',icon:Icons.forum_outlined),
    _section(context,'Profil și statistici de angajat','Profilul poate conține nume, poreclă folosită în afișarea internă, telefon, data angajării, funcția din contract și câmpuri suplimentare inclusiv linkuri sociale. Statisticile personale arată perioada de angajare, zilele și orele de lucru asociate echipei și diurnele încasate.',icon:Icons.badge_outlined),
    _section(context,'Web, Android și iPhone/iPad','Aceeași aplicație poate fi folosită în browser, instalată ca APK pe Android sau adăugată pe ecranul principal din Safari pe iPhone/iPad. Datele operaționale sunt sincronizate prin Firebase între dispozitive.',icon:Icons.devices_outlined),
  ]);
}
