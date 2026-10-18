part of '../main.dart';

Uri? validatedAndroidApkUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  final host = uri.host.toLowerCase();
  // The download target is opened by the user's browser, so never accept
  // obvious local network endpoints or IP literals as a claimed public link.
  // DNS names can still resolve privately; the administrator must publish
  // links from the approved distribution host.
  if (host.startsWith('[') || host.contains(':') ||
      RegExp(r'^\\d{1,3}(?:\\.\\d{1,3}){3}$').hasMatch(host)) return null;
  // WHATWG URL parsers used by Android browsers accept non-decimal IPv4
  // spellings (for example 0x7f.0.0.1) and normalize them to an IP literal.
  // Reject a host made entirely of decimal/hexadecimal labels before opening
  // it externally; the single-label form is already rejected below.
  final labels = host.split('.');
  final numericAddressLabels = RegExp(r'^(?:[0-9]+|0x[0-9a-f]+)$', caseSensitive: false);
  if (labels.length > 1 && labels.every(numericAddressLabels.hasMatch)) return null;
  if (!host.contains('.') || host.endsWith('.')) return null;
  const localSuffixes = <String>[
    '.localhost', '.local', '.internal', '.lan', '.home', '.test', '.invalid', '.example',
  ];
  if (localSuffixes.any(host.endsWith)) return null;
  return uri;
}

Future<void> _showAndroidInstallFlow(BuildContext context, AppSettings settings) async {
  final proceed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Row(children:[Icon(Icons.android),SizedBox(width:10),Expanded(child:Text('Instalare Android'))]),
    content: const Text(
      'Descarcă APK-ul numai din linkul HTTPS oficial publicat de administrator și verifică proveniența fișierului înainte de instalare. '
      'Android poate cere permisiunea de instalare pentru browserul sau aplicația din care deschizi fișierul. '
      'Dacă protecția telefonului blochează instalarea, solicită administratorului o distribuție verificată; nu dezactiva protecțiile de securitate pentru un fișier necunoscut.'
    ),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.download),label:const Text('Continuă la descărcare'))],
  )) ?? false;
  if (!proceed || !context.mounted) return;
  final raw=settings.androidDownloadUrl.trim();
  if(raw.isEmpty){showErrorMessage(context,'Linkul APK nu este încă publicat. Adminul îl poate adăuga din Admin Panel → Setări sistem.');return;}
  final uri=validatedAndroidApkUrl(raw);
  if(uri==null){showErrorMessage(context,'Link APK invalid: este necesară o adresă HTTPS publică, fără date de autentificare în URL.');return;}
  try {
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication) && context.mounted){
      showErrorMessage(context,'Linkul pentru APK nu a putut fi deschis.');
    }
  } catch(e) {
    if(context.mounted)showErrorMessage(context,'Descărcarea APK nu a putut fi pornită: $e');
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

