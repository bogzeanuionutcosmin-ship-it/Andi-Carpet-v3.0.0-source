part of '../main.dart';

// Abonări Firestore din HomePage, păstrate ca metode pe starea existentă.
// Etapă intermediară de modularizare: aceeași bibliotecă Dart și același lifecycle.
extension _HomeSyncListeners on _HomePageState {
  void _startOwnProfileSync(FirebaseFirestore db) {
    final sources = widget.identityQueries ?? HomeIdentityQueries.fromFirestore(db);
    // Datele private ale contului propriu nu sunt in directorul public.
    if (!isAdmin) _coreSubscriptions.add(
      sources.ownProfile(currentUserId).snapshots().listen((snap) {
        final d = snap.data();
        if (d == null || !mounted) return;
        _personalLocationMode = (d['locationMode'] ?? 'economic').toString();
        _personalLocationIntervalMinutes = (d['locationIntervalMinutes'] is num)
            ? (d['locationIntervalMinutes'] as num).toInt().clamp(1, 60).toInt() : 10;
        final prefs = d['notificationPreferences'];
        if (prefs is Map) {
          for (final key in _personalNotificationPreferences.keys.toList()) {
            if (prefs[key] is bool) _personalNotificationPreferences[key] = prefs[key] as bool;
          }
        }
        final seen = d['lastGroupChatSeenAt'];
        _lastGroupChatSeenAt = seen is Timestamp ? seen.toDate() : null;
        if (_recentGroupDocs.isNotEmpty) _recomputeGroupUnread();
        final personalTheme = AppThemeChoice.values.firstWhere(
          (x) => x.name == (d['theme'] ?? settings.theme.name).toString(),
          orElse: () => settings.theme);
        final personalFont = _normalizeFontChoice((d['fontFamily'] ?? settings.fontFamily).toString());
        final visualChanged = personalTheme != settings.theme || personalFont != settings.fontFamily;
        settings.theme = personalTheme;
        settings.personalBackgroundId = 'global';
        settings.fontFamily = personalFont;
        if (visualChanged) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSettingsChanged());
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Profil propriu: $e'); }),
    );

  }

  void _startOperationsSync(FirebaseFirestore db) {
    final sources = widget.operationalQueries ?? HomeOperationalQueries.fromFirestore(db);
    _coreSubscriptions.add(
      sources.teams().snapshots().listen((snap) {
        final list = snap.docs.map(_teamFromDoc).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final t = _teamFromDoc(doc);
          _teamCache[doc.id] = _encoded(_teamMap(t));
        }
        if (!mounted) return;
        setState(() {
          teams
            ..clear()
            ..addAll(list);
          _applyTeamMembership();
        });
        _startFinancialSync();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Echipe: $e');
      }),
    );

    _coreSubscriptions.add(
      sources.cars().snapshots().listen((snap) {
        final list = snap.docs.map(_carFromDoc).toList()..sort((a, b) => a.plate.compareTo(b.plate));
        for (final doc in snap.docs) {
          final c = _carFromDoc(doc);
          _carCache[doc.id] = _encoded(_carMap(c));
        }
        if (!mounted) return;
        setState(() {
          cars
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Mașini: $e');
      }),
    );

    _coreSubscriptions.add(
      sources.locations().snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedLocationsIfNeeded());
          return;
        }
        final list = snap.docs.map(_locationFromDoc).toList()..sort((a, b) => a.id.compareTo(b.id));
        for (final doc in snap.docs) {
          final l = _locationFromDoc(doc);
          _locationCache[doc.id] = _encoded(_locationMap(l));
        }
        if (!mounted) return;
        setState(() {
          locations
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Locații: $e');
      }),
    );

    _coreSubscriptions.add(
      sources.schedules().snapshots().listen((snap) {
        final list = snap.docs.map(_scheduleFromDoc).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        for (final doc in snap.docs) {
          final item = _scheduleFromDoc(doc);
          _scheduleCache[doc.id] = _encoded(_scheduleMap(item));
        }
        if (!mounted) return;
        setState(() {
          schedules
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Grafice de lucru: $e');
      }),
    );

    _coreSubscriptions.add(
      sources.records().snapshots().listen((snap) {
        final list = snap.docs.map(_recordFromDoc).toList()
          ..sort((a, b) => (a.startedAt ?? DateTime(2000)).compareTo(b.startedAt ?? DateTime(2000)));
        for (final doc in snap.docs) {
          final item = _recordFromDoc(doc);
          _recordCache[doc.id] = _encoded(_recordMap(item));
        }
        if (!mounted) return;
        setState(() {
          records
            ..clear()
            ..addAll(list);
        });
        unawaited(_maybeAutoCloseResolvedSchedules(operationalWorkDate(DateTime.now())));
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Execuții: $e');
      }),
    );


  }

  void _startNotificationSync(FirebaseFirestore db) {
    final sources = widget.messageQueries ?? HomeMessageQueries.fromFirestore(db);
    final Query<Map<String, dynamic>> notificationQuery =
        sources.notifications(isAdmin: isAdmin, uid: currentUserId);
    _coreSubscriptions.add(
      notificationQuery.snapshots().listen((snap) {
        final list = snap.docs.map(_notificationFromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final ownUnread = snap.docs.where((d) {
          final data = d.data();
          return (data['userId'] ?? '').toString() == currentUserId && data['read'] != true;
        }).toList();
        if (!_notificationsPrimed) {
          _knownNotificationIds.addAll(snap.docs.map((d) => d.id));
          _notificationsPrimed = true;
          final alertable=ownUnread.where((doc){final d=doc.data();return _allowPersonalAlert((d['title']??'Notificare').toString(),(d['message']??'').toString());}).toList();
          if (alertable.isNotEmpty) {
            _showIncomingPopup(
              title: alertable.length == 1 ? (alertable.first.data()['title']??'Notificare nouă').toString() : '${alertable.length} notificări necitite',
              body: alertable.length == 1 ? (alertable.first.data()['message'] ?? '').toString() : 'Le găsești în Setări → Istoric notificări.',
            );
          }
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null || (data['userId'] ?? '').toString() != currentUserId || data['read'] == true) continue;
            if (!_knownNotificationIds.add(doc.id)) continue;
            final title=(data['title']??'Notificare nouă').toString();final body=(data['message']??'').toString();
            if(_allowPersonalAlert(title,body))_showIncomingPopup(title:title,body:body);
          }
          _knownNotificationIds.addAll(snap.docs.map((d) => d.id));
        }
        if (!mounted) return;
        setState(() {
          notifications
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Notificări: $e');
      }),
    );

  }

  void _startChatSync(FirebaseFirestore db) {
    final sources = widget.messageQueries ?? HomeMessageQueries.fromFirestore(db);
    String visibleSenderName(Map<String, dynamic> data) {
      final senderId = (data['senderId'] ?? '').toString();
      if (!isAdmin && _hiddenUserIds.contains(senderId)) return 'Sistem';
      return (data['senderName'] ?? 'un membru').toString();
    }

    bool mandatoryChatAlert(Map<String,dynamic> data) {
      final senderId=(data['senderId']??'').toString();
      if(_hiddenUserIds.contains(senderId))return true;
      return users.any((u)=>u.id==senderId&&u.role==UserRole.director);
    }

    _coreSubscriptions.add(
      sources.privateMessages(currentUserId).snapshots().listen((snap) {
        final unread = snap.docs.where((d) {
          final data = d.data();
          final deletedFor = data['deletedFor'];
          final senderId = (data['senderId'] ?? '').toString();
          if (!isAdmin && _hiddenUserIds.contains(senderId)) return false;
          return data['read'] != true && !(deletedFor is List && deletedFor.map((e) => e.toString()).contains(currentUserId));
        }).toList();
        if (!_messagesPrimed) {
          _knownIncomingMessageIds.addAll(snap.docs.map((d) => d.id));
          _messagesPrimed = true;
          final mandatoryUnread=unread.any((doc)=>mandatoryChatAlert(doc.data()));
          if (unread.isNotEmpty && ((_personalNotificationPreferences['chat']??true)||mandatoryUnread)) {
            final one = unread.length == 1 ? unread.first.data() : null;
            _showIncomingPopup(
              title: unread.length == 1 ? 'Mesaj nou de la ${visibleSenderName(one!)}' : '${unread.length} mesaje necitite',
              body: unread.length == 1 ? (one?['text'] ?? '').toString() : 'Deschide Chat live pentru conversații.',
              onView: one == null ? ()=>_openMembersDirectory(chatMode:true) : () => unawaited(_openChatFromAlert((one['senderId'] ?? '').toString())),
            );
          }
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null || data['read'] == true || !_knownIncomingMessageIds.add(doc.id)) continue;
            if((_personalNotificationPreferences['chat']??true)||mandatoryChatAlert(data))_showIncomingPopup(
              title: 'Mesaj nou de la ${visibleSenderName(data)}',
              body: (data['text'] ?? '').toString(),
              onView: () => unawaited(_openChatFromAlert((data['senderId'] ?? '').toString())),
            );
          }
          _knownIncomingMessageIds.addAll(snap.docs.map((d) => d.id));
        }
        _unreadPrivateMessageCount = unread.length;
        _refreshUnreadMessageCount();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Mesaje: $e');
      }),
    );

    _coreSubscriptions.add(
      sources.groupMessages().snapshots().listen((snap) {
        final docs = snap.docs;
        _recentGroupDocs = docs;
        _recomputeGroupUnread();
        if (!_groupMessagesPrimed) {
          _knownGroupMessageIds.addAll(docs.map((d) => d.id));
          _groupMessagesPrimed = true;
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null) continue;
            if ((data['senderId'] ?? '').toString() == currentUserId || !_knownGroupMessageIds.add(doc.id)) continue;
            if (_personalNotificationPreferences['chat'] ?? true) {
              _showIncomingPopup(
                title: 'Mesaj nou în Chat live',
                body: '${(data['senderName'] ?? 'Membru').toString()}: ${(data['text'] ?? '').toString()}',
                onView: _openGroupChat,
              );
            }
          }
          _knownGroupMessageIds.addAll(docs.map((d) => d.id));
        }
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Chat comun: $e');
      }),
    );

  }

  void _startSettingsSync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      db.collection('meta').doc('uiSettings').snapshots().listen((snap) {
        final d = snap.data();
        if (!mounted) return;
        if (d == null) { if (isAdmin) unawaited(_runAutomaticMaintenance()); return; }
        setState(() {
          settings.background = (d['background'] ?? settings.background).toString();
          settings.brandingBackgroundId = (d['brandingBackgroundId'] ?? settings.brandingBackgroundId).toString();
          settings.brandingLogoId = (d['brandingLogoId'] ?? settings.brandingLogoId).toString();
          settings.androidDownloadUrl = (d['androidDownloadUrl'] ?? settings.androidDownloadUrl).toString();
          final smsTime = (d['smsPreviousDayTime'] ?? settings.smsPreviousDayTime).toString().trim();
          if (RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(smsTime)) settings.smsPreviousDayTime = smsTime;
          final rawTemplates = d['smsTemplates'];
          if (rawTemplates is Map) {
            for (final key in <String>['initial','rescheduled','postponed']) {
              final value = rawTemplates[key]?.toString().trim();
              if (value != null && value.isNotEmpty) settings.smsTemplates[key] = value;
            }
          }
          if (d['backgroundOpacity'] is num) settings.backgroundOpacity = (d['backgroundOpacity'] as num).toDouble().clamp(0.0, .70).toDouble();
          if (d['defaultPerDiem'] is num) settings.defaultPerDiem = (d['defaultPerDiem'] as num).toDouble();
          if (d['allowUndo'] is bool) settings.allowUndo = d['allowUndo'] as bool;
          if (d['autoStart'] is bool) settings.autoStart = d['autoStart'] as bool;
          if (d['autoFinish'] is bool) settings.autoFinish = d['autoFinish'] as bool;
          if (d['autoCloseWhenAllDone'] is bool) settings.autoCloseWhenAllDone = d['autoCloseWhenAllDone'] as bool;
          if (d['pushNotifications'] is bool) settings.pushNotifications = d['pushNotifications'] as bool;
          if (d['automaticBackup'] is bool) settings.automaticBackup = d['automaticBackup'] as bool;
          if (d['backupRetentionDays'] is num) settings.backupRetentionDays = (d['backupRetentionDays'] as num).toInt().clamp(1,365).toInt();
          if (d['notificationHistoryDays'] is num) settings.notificationHistoryDays = (d['notificationHistoryDays'] as num).toInt().clamp(1,365).toInt();
          final rawLearning = d['learning'];
          if (rawLearning is Map) {
            for (final entry in settings.learning.entries) {
              final raw = rawLearning[entry.key];
              if (raw is! Map) continue;
              if (raw['enabled'] is bool) entry.value.enabled = raw['enabled'] as bool;
              final modeName = raw['mode']?.toString();
              for (final mode in LearningMode.values) {
                if (mode.name == modeName) entry.value.mode = mode;
              }
            }
          }
        });
        if (isAdmin) unawaited(_runAutomaticMaintenance());
      }, onError: (Object e) {
        if (mounted && isAdmin) setState(() => coreSyncError = 'Setări UI: $e');
      }),
    );

  }

}
