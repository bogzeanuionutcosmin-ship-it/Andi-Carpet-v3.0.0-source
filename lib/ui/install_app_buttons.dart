part of '../main.dart';

Future<void> _showAndroidInstallFlow(BuildContext context, AppSettings settings) async {
  final proceed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Row(children:[Icon(Icons.android),SizedBox(width:10),Expanded(child:Text('Instalare Android'))]),
    content: const Text(
      'Instalarea APK-ului Andi Carpet din afara magazinului poate necesita dezactivarea temporară a funcției Auto Blocker pe unele telefoane Samsung. '
      'De regulă: Setări → Securitate și confidențialitate → Auto Blocker. După instalare, recomandăm activarea lui din nou. '
      'Android poate cere și permisiunea de instalare pentru browserul sau aplicația din care deschizi fișierul.'
    ),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.download),label:const Text('Continuă la descărcare'))],
  )) ?? false;
  if (!proceed || !context.mounted) return;
  final raw=settings.androidDownloadUrl.trim();
  if(raw.isEmpty){showErrorMessage(context,'Linkul APK nu este încă publicat. Adminul îl poate adăuga din Admin Panel → Setări sistem.');return;}
  final uri=Uri.tryParse(raw);
  if(uri==null || !await launchUrl(uri,mode:LaunchMode.externalApplication)){
    if(context.mounted)showErrorMessage(context,'Linkul pentru APK nu a putut fi deschis.');
  }
}

Future<void> _showAppleInstallFlow(BuildContext context) async {
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Row(children:[Icon(Icons.apple),SizedBox(width:10),Expanded(child:Text('Instalare pe iPhone / iPad'))]),
    content:const Text(
      'Pentru versiunea Andi Carpet disponibilă acum pe iPhone/iPad folosește varianta web instalată din Safari. '
      'Deschide aplicația în Safari → Partajare → Adaugă pe ecranul principal. Dacă opțiunea nu apare imediat, apasă „Mai multe” în meniul de partajare și caută „Adaugă pe ecranul principal”. '
      'După adăugare, aplicația se deschide din pictograma de pe ecranul principal.'
    ),
    actions:[FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Am înțeles'))],
  ));
}

class _InstallAppButtons extends StatelessWidget {
  final AppSettings settings;
  final bool compact;
  const _InstallAppButtons({required this.settings,this.compact=false});
  @override Widget build(BuildContext context)=>Wrap(
    spacing:8,runSpacing:8,alignment:WrapAlignment.center,
    children:[
      FilledButton.tonalIcon(onPressed:()=>_showAndroidInstallFlow(context,settings),icon:const Icon(Icons.android),label:Text(compact?'Android':'Instalează aplicația · Android')),
      OutlinedButton.icon(onPressed:()=>_showAppleInstallFlow(context),icon:const Icon(Icons.apple),label:Text(compact?'Apple':'Instalează aplicația · Apple')),
    ],
  );
}

