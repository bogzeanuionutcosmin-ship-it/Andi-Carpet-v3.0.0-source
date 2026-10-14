part of '../main.dart';

class MembersDirectoryPage extends StatefulWidget {
  final AppUser currentUser;
  final List<FunctionDefinition> functionDefinitions;
  final bool chatMode;
  const MembersDirectoryPage({super.key, required this.currentUser, required this.functionDefinitions, this.chatMode=false});
  @override State<MembersDirectoryPage> createState() => _MembersDirectoryPageState();
}

class _MembersDirectoryPageState extends State<MembersDirectoryPage> {
  final Set<String> _selected = <String>{};

  void _openChat(String uid, Map<String,dynamic> d) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivateChatPage(
      currentUser: widget.currentUser,
      otherUserId: uid,
      otherName: (d['name'] ?? d['email'] ?? 'Membru').toString(),
      otherPhotoBase64: (d['photoBase64'] ?? '').toString(),
    )));
  }

  void _openProfile(String uid) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberProfilePage(
      currentUser: widget.currentUser,
      memberId: uid,
      functionDefinitions: widget.functionDefinitions,
    )));
  }

  Future<void> _sendBulkMessage(Set<String> recipients, Map<String,Map<String,dynamic>> dataById) async {
    if (recipients.isEmpty) return;
    final message = TextEditingController();
    final ok = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text('Mesaj către ${recipients.length} membri'),
      content:SizedBox(width:560,child:TextField(controller:message,autofocus:true,minLines:4,maxLines:8,decoration:const InputDecoration(labelText:'Mesaj',hintText:'Mesajul va intra în conversația fiecărui membru.'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:(){if(message.text.trim().isNotEmpty)Navigator.pop(c,true);},icon:const Icon(Icons.send),label:const Text('Trimite'))],
    ))??false;
    if(!ok){message.dispose();return;}
    final body=message.text.trim();message.dispose();
    try{
      final db=FirebaseFirestore.instance;final batch=db.batch();final now=Timestamp.now();
      for(final uid in recipients){
        final d=dataById[uid]??<String,dynamic>{};
        final ref=db.collection('chatMessages').doc();
        batch.set(ref,{
          'chatId':privateChatId(widget.currentUser.id,uid),'senderId':widget.currentUser.id,'senderName':widget.currentUser.name,
          'recipientId':uid,'recipientName':_profileDisplayName(d),'participantIds':<String>[widget.currentUser.id,uid],'text':body,'createdAt':now,'read':false,'updatedAt':FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if(!mounted)return;setState(()=>_selected.removeAll(recipients));showSuccessMessage(context,'Mesajul a fost adăugat în conversațiile selectate.');
    }catch(e){if(mounted)showErrorMessage(context,'Mesajul nu a putut fi trimis: $e');}
  }

  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:Text(widget.chatMode?'Chat live':'Membrii')),body:SafeArea(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:(widget.currentUser.role == UserRole.director ? FirebaseFirestore.instance.collection('users') : FirebaseFirestore.instance.collection('memberDirectory')).where('active',isEqualTo:true).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return Center(child:Text('Nu am putut încărca membrii: ${snap.error}'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final docs=snap.data!.docs.where((doc){
          final d=doc.data();
          if(widget.currentUser.role == UserRole.director || doc.id == widget.currentUser.id) return true;
          return !((d['role']??'').toString() == 'admin' && d['hiddenFromMembers'] == true);
        }).toList()..sort((a,b)=>(a.data()['name']??a.data()['email']??'').toString().toLowerCase().compareTo((b.data()['name']??b.data()['email']??'').toString().toLowerCase()));
        final dataById=<String,Map<String,dynamic>>{for(final d in docs)d.id:d.data()};
        return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('chatMessages').where('recipientId', isEqualTo: widget.currentUser.id).snapshots(),
          builder: (context, messageSnap) {
            final unreadBySender=<String,int>{};
            if(messageSnap.hasData){
              for(final m in messageSnap.data!.docs){
                final md=m.data();final deletedFor=md['deletedFor'];
                if(md['read']==true || (deletedFor is List && deletedFor.map((e)=>e.toString()).contains(widget.currentUser.id)))continue;
                final sender=(md['senderId']??'').toString();if(sender.isNotEmpty)unreadBySender[sender]=(unreadBySender[sender]??0)+1;
              }
            }
            return Column(children:[
              Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),child:Row(children:[
                Expanded(child:Text('${docs.length} membri activi',style:const TextStyle(fontWeight:FontWeight.w800))),
                FilledButton.icon(onPressed:_selected.isEmpty?null:()=>_sendBulkMessage({..._selected},dataById),icon:const Icon(Icons.send),label:Text(_selected.length<=1?'Trimite mesaj':'Mesaj către ${_selected.length}')),
              ])),
              Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Align(alignment:Alignment.centerLeft,child:Text(widget.chatMode?'Chatul live principal este comun pentru toți membrii. Mai jos poți intra și în conversații private.':'Apasă pe un membru pentru profil. Bulina de pe chat arată mesajele necitite.'))),
              const SizedBox(height:6),
              Expanded(child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:docs.length + (widget.chatMode ? 1 : 0),itemBuilder:(context,index){
                if(widget.chatMode && index == 0){
                  return Card(child:ListTile(
                    onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>GroupChatPage(currentUser: widget.currentUser, functionDefinitions: widget.functionDefinitions))),
                    contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                    leading:const CircleAvatar(child:Icon(Icons.forum_outlined)),
                    title:const Text('Chat live · Toți membrii',style:TextStyle(fontWeight:FontWeight.w900)),
                    subtitle:const Text('Conversație comună între toți membrii activi ai aplicației.'),
                    trailing:const Icon(Icons.chevron_right),
                  ));
                }
                final realIndex = index - (widget.chatMode ? 1 : 0);
                final doc=docs[realIndex];final d=doc.data();final uid=doc.id;final name=_profileDisplayName(d,fallback:uid);final photoData=(d['photoBase64']??'').toString();final photo=decodeProfilePhoto(photoData);final isMe=uid==widget.currentUser.id;final checked=_selected.contains(uid);final unread=unreadBySender[uid]??0;final functionIds=d['functionIds'] is List?(d['functionIds'] as List).map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():<String>[];
                return Card(child:ListTile(
                  onTap:()=>widget.chatMode&&!isMe?_openChat(uid,d):_openProfile(uid),contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                  leading:Row(mainAxisSize:MainAxisSize.min,children:[Checkbox(value:checked,onChanged:isMe?null:(v)=>setState((){if(v==true){_selected.add(uid);}else{_selected.remove(uid);}})),GestureDetector(onTap:photo==null?null:()=>showProfilePhotoViewer(context,photoData,name),child:CircleAvatar(key:ValueKey('member-$uid-${photoData.hashCode}'),radius:29,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person):null))]),
                  title:Row(children:[Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w800))),if(isMe)const Chip(label:Text('Eu'))]),
                  subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text('${memberFunctionsText(d,widget.functionDefinitions)}${unread>0?' · $unread mesaj${unread==1?'':'e'} necitit${unread==1?'':'e'}':''}'),if(functionIds.isNotEmpty)...[const SizedBox(height:7),memberBadgeStripWidget(widget.functionDefinitions,functionIds,size:32)]]),
                  trailing:isMe?const Icon(Icons.chevron_right):Badge(isLabelVisible:unread>0,label:Text(unread>99?'99+':'$unread'),child:IconButton(tooltip:'Deschide conversația',onPressed:()=>_openChat(uid,d),icon:Icon(unread>0?Icons.mark_chat_unread:Icons.chat_bubble_outline))),
                ));
              })),
            ]);
          },
        );
      },
    )));
  }
}

