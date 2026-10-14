part of '../main.dart';

class GroupChatPage extends StatefulWidget {
  final AppUser currentUser;
  final List<AppUser> users;
  final List<FunctionDefinition> functionDefinitions;
  const GroupChatPage({super.key, required this.currentUser, this.users = const <AppUser>[], this.functionDefinitions = const <FunctionDefinition>[]});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  static const int _historyLimit = 50;
  static const int _retentionDays = 7;
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  CollectionReference<Map<String,dynamic>> get _messages => FirebaseFirestore.instance.collection('groupChatMessages');
  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => _messages
      .orderBy('createdAt', descending: true)
      .limit(_historyLimit)
      .snapshots();

  @override
  void initState() {
    super.initState();
    unawaited(_markChatOpened());
    unawaited(_cleanupExpiredMessages());
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markChatOpened() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.currentUser.id).set({
        'lastGroupChatSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _cleanupExpiredMessages() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: _retentionDays)));
      while (true) {
        final old = await _messages.where('createdAt', isLessThan: cutoff).limit(100).get();
        if (old.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in old.docs) { batch.delete(doc.reference); }
        await batch.commit();
        if (old.docs.length < 100) break;
      }
    } catch (_) {
      // Curățarea este best-effort; chatul rămâne funcțional chiar dacă un client nu poate șterge.
    }
  }

  Future<void> _send({String? customEmoji}) async {
    if (_sending) return;
    final body = customEmoji == null ? _text.text.trim() : (_andiReactionFallback(customEmoji) ?? 'Sticker Andi');
    if (body.isEmpty) return;
    setState(() => _sending = true);
    if (customEmoji == null) _text.clear();
    try {
      final hidden = widget.currentUser.hiddenFromMembers;
      await _messages.add({
        'senderId': widget.currentUser.id,
        'senderName': hidden ? 'Sistem' : widget.currentUser.name,
        'senderPhotoBase64': hidden ? '' : widget.currentUser.photoBase64,
        'text': body,
        if (customEmoji != null) 'customEmoji': customEmoji,
        'createdAt': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Mesajul nu a putut fi trimis: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openEmojiPicker() async {
    final key = await _showAndiReactionPicker(
      context,
      subtitle: 'Chat comun · ultimele 50 de mesaje · retenție 7 zile.',
    );
    if (key != null) await _send(customEmoji: key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat live · Toți membrii'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text('50 mesaje · 7 zile', style: Theme.of(context).textTheme.labelSmall)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Nu am putut încărca chatul live: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.toList()
                  ..sort((a, b) {
                    final aa = a.data()['createdAt'];
                    final bb = b.data()['createdAt'];
                    final ad = aa is Timestamp ? aa.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                    final bd = bb is Timestamp ? bb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                    return ad.compareTo(bd);
                  });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });
                if (docs.isEmpty) return const Center(child: Text('Niciun mesaj încă. Scrie primul mesaj în chatul comun.'));
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final mine = (d['senderId'] ?? '').toString() == widget.currentUser.id;
                    final when = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : DateTime.now();
                    final photoData = (d['senderPhotoBase64'] ?? '').toString();
                    final photo = decodeProfilePhoto(photoData);
                    final senderName = (d['senderName'] ?? 'Membru').toString();
                    AppUser? senderUser;
                    for (final u in widget.users) { if (u.id == (d['senderId'] ?? '').toString()) { senderUser = u; break; } }
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!mine) ...[
                              GestureDetector(
                                onTap: photo == null ? null : () => showProfilePhotoViewer(context, photoData, senderName),
                                child: CircleAvatar(radius: 18, backgroundImage: photo == null ? null : MemoryImage(photo), child: photo == null ? const Icon(Icons.person, size: 18) : null),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                                decoration: BoxDecoration(
                                  color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(mine ? 15 : 3),
                                    bottomRight: Radius.circular(mine ? 3 : 15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!mine) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text(senderName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                      ),
                                      if (senderUser != null && widget.functionDefinitions.isNotEmpty && senderUser.functionIds.isNotEmpty)
                                        Padding(padding:const EdgeInsets.only(bottom:5),child:memberBadgeStripWidget(widget.functionDefinitions,senderUser.functionIds,size:24)),
                                    ],
                                    if (_andiHasReaction((d['customEmoji'] ?? '').toString()))
                                      _andiReactionWidget((d['customEmoji'] ?? '').toString(), size: 126)
                                    else
                                      Text((d['text'] ?? '').toString(), style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 3),
                                    Text('${two(when.hour)}:${two(when.minute)}', style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(tooltip: 'Stickere & emoticoane Andi', onPressed: _sending ? null : _openEmojiPicker, icon: const Icon(Icons.emoji_emotions_outlined)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Mesaj pentru toți membrii...', prefixIcon: Icon(Icons.forum_outlined)),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

