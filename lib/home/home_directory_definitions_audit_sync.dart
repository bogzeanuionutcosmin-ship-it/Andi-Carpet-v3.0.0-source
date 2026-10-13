part of '../main.dart';

// Abonări administrative/definiții/director: extrase textual, fără schimbarea fluxului.
extension _HomeDirectoryDefinitionsAuditSync on _HomePageState {
  void _startAuditSync(FirebaseFirestore db) {
    if (!isAdmin) return;
    _coreSubscriptions.add(
      db.collection('audit').orderBy('at', descending: true).limit(500).snapshots().listen((snap) {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          return AuditEntry(
            id: doc.id,
            actor: (d['actor'] ?? '').toString(),
            action: (d['action'] ?? '').toString(),
            target: (d['target'] ?? '').toString(),
            at: _dateFrom(d['at']) ?? DateTime.now(),
          );
        }).toList();
        if (!mounted) return;
        setState(() {
          audit
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Audit: $e');
      }),
    );
  }

  void _startDefinitionsSync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      db.collection('locationCategories').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedDefinitionsIfNeeded());
          return;
        }
        final list = snap.docs.map(_categoryFromDoc).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final item = _categoryFromDoc(doc);
          _categoryCache[item.id] = _encoded(_categoryMap(item));
        }
        if (!mounted) return;
        setState(() { categories..clear()..addAll(list); });
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Categorii: $e'); }),
    );

    _coreSubscriptions.add(
      db.collection('backgrounds').snapshots().listen((snap) {
        final next=<String,Map<String,String>>{};
        for(final doc in snap.docs){
          final d=doc.data();
          if(d['active']==false)continue;
          final image=(d['imageBase64']??'').toString();
          if(image.isEmpty)continue;
          next[doc.id]={'name':(d['name']??doc.id).toString(),'imageBase64':image};
        }
        if(!mounted)return;
        setState((){settings.customBackgrounds..clear()..addAll(next);});
        WidgetsBinding.instance.addPostFrameCallback((_)=>widget.onSettingsChanged());
      },onError:(Object e){if(mounted)setState(()=>coreSyncError='Fundaluri: $e');}),
    );

    _coreSubscriptions.add(
      db.collection('functions').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedDefinitionsIfNeeded());
          return;
        }
        final list = snap.docs.map(_functionFromDoc).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final item = _functionFromDoc(doc);
          _functionCache[item.id] = _encoded(_functionMap(item));
        }
        if (!mounted) return;
        setState(() { functionDefinitions..clear()..addAll(list); });
        _startFinancialSync();
        if (isAdmin) unawaited(_syncUserPermissionSnapshots());
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Funcții: $e'); }),
    );

  }

  void _startDirectorySync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      (isAdmin ? db.collection('users') : db.collection('memberDirectory')).snapshots().listen((snap) {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          final roleText = (d['role'] ?? 'member').toString();
          final role = roleText == 'admin' ? UserRole.director : UserRole.member;
          final function = FirebaseUserProfile.functionFrom(d['function']?.toString(), roleText);
          final email = (d['email'] ?? '').toString();
          var name = (d['name'] ?? '').toString().trim();
          final nickname = (d['nickname'] ?? '').toString().trim();
          if (d['useNickname'] == true && nickname.isNotEmpty) name = nickname;
          if (name.isEmpty) name = roleText == 'admin' ? 'Administrator' : (email.isEmpty ? doc.id : email.split('@').first);
          _userTeamCache[doc.id] = d['teamId']?.toString();
          if (doc.id == currentUserId) {
            _personalLocationMode = (d['locationMode'] ?? 'economic').toString();
            _personalLocationIntervalMinutes = (d['locationIntervalMinutes'] is num) ? (d['locationIntervalMinutes'] as num).toInt().clamp(1, 60).toInt() : 10;
            final rawNotificationPreferences=d['notificationPreferences'];
            if(rawNotificationPreferences is Map){for(final key in _personalNotificationPreferences.keys.toList()){if(rawNotificationPreferences[key] is bool)_personalNotificationPreferences[key]=rawNotificationPreferences[key] as bool;}}
            final rawGroupSeen = d['lastGroupChatSeenAt'];
            _lastGroupChatSeenAt = rawGroupSeen is Timestamp ? rawGroupSeen.toDate() : null;
            if (_recentGroupDocs.isNotEmpty) _recomputeGroupUnread();
            final personalTheme = AppThemeChoice.values.firstWhere((x) => x.name == (d['theme'] ?? settings.theme.name).toString(), orElse: () => settings.theme);
            final personalFont = _normalizeFontChoice((d['fontFamily'] ?? settings.fontFamily).toString());
            final visualChanged = personalTheme != settings.theme || personalFont != settings.fontFamily;
            settings.theme = personalTheme;
            // Fundalul este global și este controlat exclusiv de Admin.
            settings.personalBackgroundId = 'global';
            settings.fontFamily = personalFont;
            if (visualChanged) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSettingsChanged());
          }
          final functionIds = d['functionIds'] is List
              ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : <String>[(roleText == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
          return AppUser(
            id: doc.id,
            name: name,
            role: role,
            function: function,
            functionIds: functionIds,
            teamId: d['teamId']?.toString(),
            email: email,
            active: d['active'] == true,
            hiddenFromMembers: d['hiddenFromMembers'] == true,
            photoBase64: (d['photoBase64'] ?? '').toString(),
          );
        }).where((u) => isAdmin || !u.hiddenFromMembers || u.id == currentUserId).toList();
        final hiddenIds = snap.docs.where((doc) {
          final d = doc.data();
          return (d['role'] ?? '').toString() == 'admin' && d['hiddenFromMembers'] == true;
        }).map((doc) => doc.id).toSet();
        list.sort((a, b) {
          if (a.role != b.role) return a.role == UserRole.director ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        if (!mounted) return;
        setState(() {
          _hiddenUserIds
            ..clear()
            ..addAll(hiddenIds);
          users
            ..clear()
            ..addAll(list);
          if (!users.any((u) => u.id == currentUserId)) {
            users.add(AppUser(
              id: widget.profile.uid,
              name: widget.profile.name,
              role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
              function: widget.profile.function,
              functionIds: widget.profile.functionIds,
              email: widget.profile.email,
              active: widget.profile.active,
            ));
          }
          _applyTeamMembership();
        });
        _startFinancialSync();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Conturi: $e');
      }),
    );

  }

}
