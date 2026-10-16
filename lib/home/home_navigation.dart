part of '../main.dart';

extension _HomeNavigation on _HomePageState {
  void _recomputeGroupUnread() {
    if (!_sessionActive) return;
    final seenAt = _lastGroupChatSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    _unreadGroupMessageCount = _recentGroupDocs.where((doc) {
      final data = doc.data();
      if ((data['senderId'] ?? '').toString() == currentUserId) return false;
      final raw = data['createdAt'];
      final createdAt = raw is Timestamp ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      return createdAt.isAfter(seenAt);
    }).length;
    _refreshUnreadMessageCount();
  }

  void _refreshUnreadMessageCount() {
    if (!_sessionActive) return;
    if (!_sessionActive) return;
    setState(() => _unreadMessageCount = _unreadPrivateMessageCount + _unreadGroupMessageCount);
  }

  void _openGroupChat() {
    if (!_sessionActive) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupChatPage(currentUser: me, users: users, functionDefinitions: functionDefinitions))).then((_) {
      if (!_sessionActive) return;
      _unreadGroupMessageCount = 0;
      _refreshUnreadMessageCount();
    });
  }

  void _openMembersDirectory({bool chatMode=false}) {
    if (!_sessionActive) return;
    // Directorul membrilor este disponibil tuturor utilizatorilor autentificați.
    // Documentele sunt proiectate în memberDirectory fără date private.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MembersDirectoryPage(currentUser: me, functionDefinitions: functionDefinitions, chatMode: chatMode),
    ));
  }

  void _openProfile() {
    if (!_sessionActive) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(
      user: me,
      teams: teams,
      functionDefinitions: functionDefinitions,
      records: records,
      perDiems: perDiems,
    )));
  }

  Future<void> _openNotificationsSheet() async {
    if (!_sessionActive) return;
    final mine = notifications.where((n) => n.userId == currentUserId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),
                  ],
                ),
              ),
              Expanded(
                child: mine.isEmpty
                    ? const Center(child: Text('Nu ai notificări.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                        children: mine.take(50).map((n) => Card(
                          child: ListTile(
                            leading: Icon(n.read ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined),
                            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w900)),
                            subtitle: Text('${n.message}\n${formatDate(n.createdAt)} · ${timeText(n.createdAt)}'),
                            isThreeLine: true,
                            onTap: n.read ? null : () async {
                              if (!_sessionActive) return;
                              n.read = true;
                              await FirebaseFirestore.instance.collection('notifications').doc(n.id).set({'read': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                              if (_sessionActive) setState(() {});
                            },
                          ),
                        )).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAbout() {
    if (!_sessionActive) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppInformationPage(settings: settings, isAdmin: isAdmin)));
  }

  void _openAdmin() {
    if (!_sessionActive) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPanelPage(users: users, teams: teams, cars: cars, locations: locations, categories: categories, functionDefinitions: functionDefinitions, schedules: schedules, records: records, expenses: expenses, perDiems: perDiems, finances: finances, settlements: settlements, notifications: notifications, audit: audit, settings: settings, userName: userName, onChanged: refresh, log: log, saveLocation: _saveLocationDirect, deleteLocation: _deleteLocationDirect)));
  }
}
