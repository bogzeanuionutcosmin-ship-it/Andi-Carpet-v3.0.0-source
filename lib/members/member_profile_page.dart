part of '../main.dart';

class MemberProfilePage extends StatelessWidget {
  final AppUser currentUser;
  final String memberId;
  final List<FunctionDefinition> functionDefinitions;
  const MemberProfilePage({super.key, required this.currentUser, required this.memberId, required this.functionDefinitions});

  Future<void> _call(BuildContext context,String phone) async {
    final uri=Uri(scheme:'tel',path:phone);
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){
      await Clipboard.setData(ClipboardData(text:phone));
      if(context.mounted) showErrorMessage(context,'Apelarea directă nu este disponibilă aici. Numărul a fost copiat.');
    }
  }

  void _chat(BuildContext context,Map<String,dynamic>d){
    Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PrivateChatPage(
      currentUser:currentUser,
      otherUserId:memberId,
      otherName:_profileDisplayName(d),
      otherPhotoBase64:(d['photoBase64']??'').toString(),
    )));
  }

  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text('Profil membru')),body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection(currentUser.role == UserRole.director || memberId == currentUser.id ? 'users' : 'memberDirectory').doc(memberId).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return Center(child:Text('Nu am putut încărca profilul: ${snap.error}'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final d=snap.data!.data()??<String,dynamic>{};
        if(currentUser.role != UserRole.director && d['hiddenFromMembers'] == true && memberId != currentUser.id){
          return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Acest profil nu este disponibil pentru membri.')));
        }
        final name=_profileDisplayName(d);
        final phone=(d['phone']??'').toString().trim();
        final photoData=(d['photoBase64']??'').toString();
        final photo=decodeProfilePhoto(photoData);
        final functionIds=d['functionIds'] is List?(d['functionIds'] as List).map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():<String>[];
        final rawFields=d['profileFields'];
        final fields=<Map<String,String>>[];
        if(rawFields is List){for(final raw in rawFields){if(raw is Map){final l=(raw['label']??'').toString().trim();final v=(raw['value']??'').toString().trim();final t=(raw['type']??'text').toString();if(l.isNotEmpty||v.isNotEmpty)fields.add({'label':l,'value':v,'type':t});}}}
        return ListView(padding:const EdgeInsets.all(16),children:[
          Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
            GestureDetector(
              onTap:photo==null?null:()=>showProfilePhotoViewer(context,photoData,name),
              child:CircleAvatar(radius:58,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person,size:54):null),
            ),
            const SizedBox(height:12),Text(name,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:4),Text((d['contractFunction']??'').toString().trim().isEmpty?memberFunctionsText(d,functionDefinitions):(d['contractFunction']??'').toString()),
            if(functionIds.isNotEmpty)...[const SizedBox(height:10),memberBadgeStripWidget(functionDefinitions,functionIds,size:42)],
            if((d['email']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Text((d['email']??'').toString())),
            const SizedBox(height:14),
            if(memberId!=currentUser.id)FilledButton.icon(onPressed:()=>_chat(context,d),icon:const Icon(Icons.chat),label:const Text('Mesaj privat')),
          ]))),
          if(phone.isNotEmpty)Card(child:ListTile(
            leading:const CircleAvatar(backgroundColor:Colors.green,child:Icon(Icons.phone,color:Colors.white)),
            title:const Text('Telefon'),subtitle:Text(phone),trailing:const Icon(Icons.call,color:Colors.green),
            onTap:()=>_call(context,phone),
          )),
          ...fields.map((f){final link=f['type']=='link';return Card(child:ListTile(title:Text(f['label']!.isEmpty?'Informație':f['label']!),subtitle:Text(f['value']??''),leading:Icon(link?Icons.link:Icons.info_outline),trailing:link?const Icon(Icons.open_in_new):null,onTap:link?()async{final raw=(f['value']??'').trim();if(raw.isEmpty)return;final normalized=RegExp(r'^https?://',caseSensitive:false).hasMatch(raw)?raw:'https://$raw';final uri=Uri.tryParse(normalized);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);}:null));}),
        ]);
      },
    ));
  }
}

