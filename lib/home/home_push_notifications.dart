part of '../main.dart';

extension _HomePushNotifications on _HomePageState {
  void _showIncomingPopup({required String title, required String body, VoidCallback? onView}) {
    if (!_sessionActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sessionActive) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff1F2937),
          duration: const Duration(seconds: 7),
          content: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              if (body.trim().isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            ])),
          ]),
          action: onView == null ? null : SnackBarAction(label: 'VEZI', textColor: Colors.white, onPressed: () { if (_sessionActive) onView(); }),
        ));
    });
  }

  Future<void> _openChatFromAlert(String otherUserId) async {
    if (!_sessionActive || otherUserId.trim().isEmpty || otherUserId == currentUserId) return;
    if (!isAdmin && _hiddenUserIds.contains(otherUserId)) return;
    try {
      final snap = await _pushDb.collection(isAdmin ? 'users' : 'memberDirectory').doc(otherUserId).get();
      if (!_sessionActive) return;
      final d = snap.data() ?? <String, dynamic>{};
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivateChatPage(
        currentUser: me,
        otherUserId: otherUserId,
        otherName: (d['name'] ?? d['email'] ?? 'Membru').toString(),
        otherPhotoBase64: (d['photoBase64'] ?? '').toString(),
      )));
    } catch (_) {
      if (_sessionActive) _openMembersDirectory();
    }
  }

  String _pushTokenDocId(String token) => base64UrlEncode(utf8.encode(token)).replaceAll('=', '');

  Future<void> _savePushToken(String token) async {
    if (!_sessionActive || token.trim().isEmpty) return;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await _pushDb
        .collection('users').doc(currentUserId)
        .collection('pushTokens').doc(_pushTokenDocId(token))
        .set({
          'token': token,
          'platform': platform,
          'deviceOwnerUid': currentUserId,
          'active': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _offerPushPermissionAutomatically() {
    if (_pushPermissionDialogShown || !_sessionActive) return;
    _pushPermissionDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sessionActive) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.notifications_active_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('Activează notificările')),
          ]),
          content: const Text(
            'Andi Carpetă îți va înregistra automat acest dispozitiv pentru notificări. '
            'Trebuie doar să confirmi o singură dată permisiunea sistemului. După aceea nu mai este nevoie de „Reînregistrează dispozitivul”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mai târziu'),
            ),
            FilledButton.icon(
              onPressed: () {
                // Important pentru Web/iOS: requestPermission trebuie pornit direct
                // din gestul utilizatorului. Pornim înainte de a închide dialogul.
                unawaited(_initPushNotifications(fromUserGesture: true));
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Activează'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _initPushNotifications({bool fromUserGesture = false}) async {
    if (!_sessionActive || _pushInitializationInFlight) return;
    _pushInitializationInFlight = true;
    try {
      final messaging = widget.messaging ?? FirebaseMessaging.instance;

      NotificationSettings permission;
      if (kIsWeb && fromUserGesture) {
        // Pe Web (inclusiv PWA iPhone), cererea trebuie lansată direct dintr-un
        // gest al utilizatorului. Nu facem niciun await înainte de apelul acesta.
        permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
        if (!_sessionActive) return;
      } else {
        permission = await messaging.getNotificationSettings();
        if (!_sessionActive) return;
        if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
          if (kIsWeb) {
            // Nu cerem utilizatorului să intre în Profil. Afișăm automat dialogul
            // de activare, iar după tap tokenul este creat și salvat singur.
            _offerPushPermissionAutomatically();
            return;
          }
          permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
          if (!_sessionActive) return;
        }
      }

      if (permission.authorizationStatus == AuthorizationStatus.denied ||
          permission.authorizationStatus == AuthorizationStatus.deniedPermanently) {
        debugPrint('[push] Permisiunea pentru notificări este refuzată.');
        return;
      }
      if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (kIsWeb) _offerPushPermissionAutomatically();
        return;
      }

      if (kIsWeb) {
        if (_webPushVapidKey.trim().isEmpty) {
          debugPrint('[push] FCM_WEB_VAPID_KEY lipsește din build.');
          return;
        }
        // După acordarea permisiunii, dăm service worker-ului o clipă să fie gata.
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!_sessionActive) return;
      }

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webPushVapidKey)
          : await messaging.getToken();
      if (!_sessionActive) return;
      if (token == null || token.trim().isEmpty) {
        debugPrint('[push] Firebase Messaging nu a returnat un token.');
        return;
      }

      await _savePushToken(token);
      if (!_sessionActive) return;
      debugPrint('[push] token_saved');

      if (!_pushListenersAttached) {
        _pushListenersAttached = true;
        _coreSubscriptions.add(messaging.onTokenRefresh.listen(
          (value) => unawaited(_savePushToken(value)),
          onError: (Object error) {
            if (!_sessionActive) return;
            VisionErrorTelemetry.report(area: 'fcm', code: 'token_refresh_failed');
            debugPrint('[push] token_refresh_failed');
          },
        ));
        _coreSubscriptions.add((widget.messageOpenedApp ?? FirebaseMessaging.onMessageOpenedApp).listen((message) {
          if (!_sessionActive) return;
          final type = (message.data['type'] ?? '').toString();
          if (type == 'chat') {
            final senderId = (message.data['senderId'] ?? '').toString();
            if (senderId.isNotEmpty) unawaited(_openChatFromAlert(senderId));
          }
        }));
      }

      final initial = await messaging.getInitialMessage();
      if (!_sessionActive) return;
      if (initial != null && (initial.data['type'] ?? '').toString() == 'chat') {
        final senderId = (initial.data['senderId'] ?? '').toString();
        if (senderId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_openChatFromAlert(senderId)));
        }
      }
    } catch (_) {
      if (_sessionActive) VisionErrorTelemetry.report(area: 'fcm', code: 'initialization_failed');
      debugPrint('[push] initialization_failed');
      // Raw SDK stack omitted from app-owned console. Vision keeps constant codes.
      // Butonul din Profil rămâne doar ca diagnostic/fallback. Înregistrarea
      // normală se face automat la fiecare pornire/login.
    } finally {
      _pushInitializationInFlight = false;
    }
  }

}
