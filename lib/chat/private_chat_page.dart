part of '../main.dart';

class PrivateChatPage extends StatefulWidget {
  final AppUser currentUser;
  final String otherUserId;
  final String otherName;
  final String otherPhotoBase64;
  const PrivateChatPage({super.key, required this.currentUser, required this.otherUserId, required this.otherName, this.otherPhotoBase64 = ''});
  @override State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _sentReady = false;
  bool _receivedReady = false;
  String? _chatError;
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _sentDocs = <QueryDocumentSnapshot<Map<String,dynamic>>>[];
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _receivedDocs = <QueryDocumentSnapshot<Map<String,dynamic>>>[];
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _sentSubscription;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _receivedSubscription;
  String get _chatId => privateChatId(widget.currentUser.id, widget.otherUserId);

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance.collection('chatMessages');
    _sentSubscription = db.where('senderId', isEqualTo: widget.currentUser.id).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _sentReady = true;
        _sentDocs = snap.docs.where((d) => (d.data()['recipientId'] ?? '').toString() == widget.otherUserId).toList();
      });
    }, onError: (Object e) { if (mounted) setState(() { _sentReady = true; _chatError = '$e'; }); });
    _receivedSubscription = db.where('recipientId', isEqualTo: widget.currentUser.id).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _receivedReady = true;
        _receivedDocs = snap.docs.where((d) => (d.data()['senderId'] ?? '').toString() == widget.otherUserId).toList();
      });
    }, onError: (Object e) { if (mounted) setState(() { _receivedReady = true; _chatError = '$e'; }); });
  }

  List<QueryDocumentSnapshot<Map<String,dynamic>>> get _visibleDocs {
    final all = <QueryDocumentSnapshot<Map<String,dynamic>>>[..._sentDocs, ..._receivedDocs];
    final visible = all.where((d) {
      final deletedFor = d.data()['deletedFor'];
      return !(deletedFor is List && deletedFor.map((e) => e.toString()).contains(widget.currentUser.id));
    }).toList();
    visible.sort((a,b){
      final aa=a.data()['createdAt']; final bb=b.data()['createdAt'];
      final ad=aa is Timestamp?aa.toDate():DateTime.fromMillisecondsSinceEpoch(0);
      final bd=bb is Timestamp?bb.toDate():DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });
    return visible;
  }

  @override
  void dispose() {
    _sentSubscription?.cancel();
    _receivedSubscription?.cancel();
    _text.dispose(); _scroll.dispose(); super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _text.clear();
    try {
      await FirebaseFirestore.instance.collection('chatMessages').add({
        'chatId': _chatId,
        'senderId': widget.currentUser.id,
        'senderName': widget.currentUser.name,
        'recipientId': widget.otherUserId,
        'recipientName': widget.otherName,
        'participantIds': <String>[widget.currentUser.id, widget.otherUserId],
        'text': body,
        'createdAt': Timestamp.now(),
        'read': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      });
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Mesajul nu a putut fi trimis: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendCustomEmoji(String key) async {
    final display=_andiReactionFallback(key);
    if(display==null || _sending)return;
    setState(()=>_sending=true);
    try{
      await FirebaseFirestore.instance.collection('chatMessages').add({
        'chatId':_chatId,
        'senderId':widget.currentUser.id,
        'senderName':widget.currentUser.name,
        'recipientId':widget.otherUserId,
        'recipientName':widget.otherName,
        'participantIds':<String>[widget.currentUser.id,widget.otherUserId],
        'text':display,
        'customEmoji':key,
        'createdAt':Timestamp.now(),
        'read':false,
        'updatedAt':FieldValue.serverTimestamp(),
      });
    }catch(e){if(mounted)showErrorMessage(context,'Emoticonul nu a putut fi trimis: $e');}
    finally{if(mounted)setState(()=>_sending=false);}
  }

  Future<void> _openEmojiPicker() async {
    final key=await _showAndiReactionPicker(context,subtitle:'Set intern de stickere și emoticoane pentru conversațiile private.');
    if(key!=null)await _sendCustomEmoji(key);
  }

  Future<void> _markRead(List<QueryDocumentSnapshot<Map<String,dynamic>>> docs) async {
    final unread = docs.where((d) {
      final x=d.data();
      return x['recipientId'] == widget.currentUser.id && x['read'] != true;
    }).toList();
    if (unread.isEmpty) return;
    var batch = FirebaseFirestore.instance.batch();
    var count=0;
    for (final d in unread) {
      batch.update(d.reference, {'read': true, 'readAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      count++;
      if (count >= 400) { await batch.commit(); batch=FirebaseFirestore.instance.batch(); count=0; }
    }
    if (count>0) await batch.commit();
  }

  Future<void> _clearChatForMe() async {
    final docs = <QueryDocumentSnapshot<Map<String,dynamic>>>[..._sentDocs, ..._receivedDocs];
    if (docs.isEmpty) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Ștergi conversația?'),
      content: const Text('Conversația va dispărea doar pentru tine. Celălalt membru își păstrează istoricul. Mesajele noi vor apărea din nou aici.'),
      actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.delete_outline),label:const Text('Șterge pentru mine'))],
    )) ?? false;
    if (!ok) return;
    try {
      var batch = FirebaseFirestore.instance.batch();
      var count = 0;
      for (final d in docs) {
        batch.set(d.reference, {'deletedFor': FieldValue.arrayUnion([widget.currentUser.id]), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        count++;
        if (count >= 400) { await batch.commit(); batch = FirebaseFirestore.instance.batch(); count = 0; }
      }
      if (count > 0) await batch.commit();
      if (mounted) showSuccessMessage(context, 'Conversația a fost ștearsă pentru tine.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu am putut șterge conversația: $e');
    }
  }

  Widget _conversation() {
    if (_chatError != null && !_sentReady && !_receivedReady) return Center(child: Text('Nu am putut încărca discuția: $_chatError'));
    if (!_sentReady || !_receivedReady) return const Center(child: CircularProgressIndicator());
    final docs = _visibleDocs;
    unawaited(_markRead(docs));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
    if (docs.isEmpty) return const Center(child: Text('Niciun mesaj încă. Scrie primul mesaj.'));
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: docs.length,
      itemBuilder: (context,index){
        final d=docs[index].data();
        final mine=(d['senderId']??'').toString()==widget.currentUser.id;
        final raw=d['createdAt'];
        final when=raw is Timestamp?raw.toDate():DateTime.now();
        final read=d['read']==true;
        return Align(
          alignment: mine?Alignment.centerRight:Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width*.78),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(12,8,10,6),
            decoration: BoxDecoration(
              color: mine?Theme.of(context).colorScheme.primaryContainer:Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(mine?15:3), bottomRight: Radius.circular(mine?3:15),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              if(_andiHasReaction((d['customEmoji']??'').toString()))
                _andiReactionWidget((d['customEmoji']??'').toString(),size:118)
              else
                Text((d['text']??'').toString(), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children:[
                Text('${two(when.hour)}:${two(when.minute)}', style: Theme.of(context).textTheme.labelSmall),
                if(mine)...[const SizedBox(width:4),Icon(read?Icons.done_all:Icons.done,size:15)],
              ]),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = decodeProfilePhoto(widget.otherPhotoBase64);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          GestureDetector(
            onTap:photo==null?null:()=>showProfilePhotoViewer(context,widget.otherPhotoBase64,widget.otherName),
            child:CircleAvatar(radius: 20, backgroundImage: photo == null ? null : MemoryImage(photo), child: photo == null ? const Icon(Icons.person, size: 20) : null),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.otherName, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [IconButton(tooltip:'Șterge conversația pentru mine', onPressed:_clearChatForMe, icon:const Icon(Icons.delete_outline))],
      ),
      body: Column(children: [
        Expanded(child: _conversation()),
        SafeArea(top:false, child: Padding(
          padding: const EdgeInsets.fromLTRB(10,7,10,8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children:[
            IconButton(tooltip:'Stickere & emoticoane Andi',onPressed:_sending?null:_openEmojiPicker,icon:const Icon(Icons.emoji_emotions_outlined)),
            const SizedBox(width:4),
            Expanded(child: TextField(
              controller:_text,
              minLines:1,maxLines:5,
              textCapitalization:TextCapitalization.sentences,
              decoration: const InputDecoration(hintText:'Mesaj...', prefixIcon:Icon(Icons.chat_bubble_outline)),
              onSubmitted:(_)=>_send(),
            )),
            const SizedBox(width:8),
            IconButton.filled(onPressed:_sending?null:_send,icon:_sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send)),
          ]),
        )),
      ]),
    );
  }
}


