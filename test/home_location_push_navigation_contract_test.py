"""Regression contracts for the unchanged Home GPS, FCM and navigation paths.

These check source integration and security/order invariants, not real GPS or FCM.
The Flutter CI compiles the extension calls, callbacks and lifecycle together.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOME = (ROOT / 'lib/home/home_page.dart').read_text(encoding='utf-8')
MAIN = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
MODULES = {
    'home_push_notifications': ('_HomePushNotifications', (
        '_showIncomingPopup', '_openChatFromAlert', '_pushTokenDocId',
        '_savePushToken', '_offerPushPermissionAutomatically', '_initPushNotifications')),
    'home_live_location': ('_HomeLiveLocation', (
        '_startAdaptiveLiveLocation', '_startNativeBackgroundLocationStream',
        '_updateNativeLocationProximityBoost', '_resolveLiveLocality', '_shareLiveLocationIfAllowed')),
    'home_work_automation': ('_HomeWorkAutomation', (
        '_homeLocationById', '_homeLatestRecord', '_automationNotifyOnce',
        '_applyWorkAutomationFromPosition', '_handleArrivalDetected',
        '_saveArrivalStart', '_saveArrivalWaiting', '_maybeAutoCloseResolvedSchedules')),
    'home_navigation': ('_HomeNavigation', (
        '_recomputeGroupUnread', '_refreshUnreadMessageCount', '_openGroupChat',
        '_openMembersDirectory', '_openProfile', '_openNotificationsSheet', '_openAbout', '_openAdmin')),
}


def source(name):
    return (ROOT / f'lib/home/{name}.dart').read_text(encoding='utf-8')


class HomeLocationPushNavigationContracts(unittest.TestCase):
    def test_extensions_linked_once_and_methods_not_duplicated(self):
        all_sources = '\n'.join(p.read_text(encoding='utf-8') for p in (ROOT / 'lib/home').glob('*.dart'))
        for module, (extension, methods) in MODULES.items():
            with self.subTest(module=module):
                text = source(module)
                self.assertEqual(MAIN.count(f"part 'home/{module}.dart';"), 1)
                self.assertTrue(text.startswith("part of '../main.dart';"))
                self.assertIn(f'extension {extension} on _HomePageState {{', text)
                for method in methods:
                    pattern = rf'^  [\w<>?]+ {method}\('
                    self.assertEqual(len(re.findall(pattern, text, re.M)), 1, method)
                    self.assertEqual(len(re.findall(pattern, all_sources, re.M)), 1, method)
                    self.assertFalse(re.search(pattern, HOME, re.M), method)

    def test_lifecycle_keeps_start_and_disposal_of_existing_resources(self):
        for item in ('void initState()', 'void dispose()', 'Widget build(BuildContext context)',
                     '_startCoreSync();', '(widget.platformEffects?.startLocation ?? widget.startLocation ?? _startAdaptiveLiveLocation)();',
                     'unawaited((widget.platformEffects?.initializePush ?? widget.initializePush ?? _initPushNotifications)());',
                     'for (final sub in _coreSubscriptions) { sub.cancel(); }',
                     'for (final sub in _financialSubscriptions) { sub.cancel(); }',
                     '_liveLocationTimer?.cancel();', '_backgroundLocationSubscription?.cancel();'):
            self.assertIn(item, HOME)

    def test_push_gesture_token_owner_and_disposable_listeners_retained(self):
        push = source('home_push_notifications')
        for item in ("if (!isAdmin && _hiddenUserIds.contains(otherUserId)) return;",
                     "collection(isAdmin ? 'users' : 'memberDirectory')", 'if (kIsWeb && fromUserGesture)',
                     'messaging.requestPermission(alert: true, badge: true, sound: true)',
                     "'deviceOwnerUid': currentUserId", ".collection('pushTokens').doc(_pushTokenDocId(token))",
                     'getToken(vapidKey: _webPushVapidKey)', 'finally {\n      _pushInitializationInFlight = false;',
                     '(widget.messageOpenedApp ?? FirebaseMessaging.onMessageOpenedApp).listen', 'messaging.getInitialMessage()'):
            self.assertIn(item, push)
        self.assertEqual(push.count('_coreSubscriptions.add('), 2)
        self.assertLess(push.index('await _savePushToken(token);'), push.index('if (!_pushListenersAttached)'))

    def test_location_preferences_throttling_and_write_before_detection_retained(self):
        gps = source('home_live_location')
        for item in ('LocationPermission.deniedForever', 'Geolocator.isLocationServiceEnabled()',
                     "if (inWork && effectiveMode == 'offline') effectiveMode = 'economic';",
                     'now.difference(_lastSharedAt!) < minGap', 'nearest <= 3000', 'nearest > 5000',
                     'ForegroundNotificationConfig(', 'showBackgroundLocationIndicator: true',
                     "collection('liveLocations').doc(currentUserId).set({", "'photoBase64': me.photoBase64"):
            self.assertIn(item, gps)
        self.assertLess(gps.index("collection('liveLocations').doc(currentUserId).set({"),
                        gps.index('await _applyWorkAutomationFromPosition(p, now, workDate);'))

    def test_gps_quality_permissions_dwell_and_human_confirmation_retained(self):
        automation = source('home_work_automation')
        for item in ('p.accuracy > 80', 'now.difference(p.timestamp) > const Duration(minutes: 2)',
                     'p.speed > 8', '!hasPermission(FunctionPermission.editProgram)', '!canEditTeam(teamId)',
                     'active.length > 1', 'meters + p.accuracy <= 250',
                     'now.difference(firstInside) < const Duration(seconds: 20)',
                     "if (choice == 'start') {\n      await _saveArrivalStart(schedule, item, workDate);",
                     "if (choice == 'waiting') {\n      await _saveArrivalWaiting(schedule, item, workDate);",
                     'await _saveRecordDirect(started);', 'await _saveRecordDirect(waiting);',
                     'await _saveScheduleDirect(schedule);'):
            self.assertIn(item, automation)
        # Preserve current legacy semantics; this does NOT approve refused = resolved.
        self.assertIn('r.status != WorkAttemptStatus.refused', automation)

    def test_unread_ownership_and_mark_read_are_unchanged(self):
        navigation = source('home_navigation')
        for item in ("(data['senderId'] ?? '').toString() == currentUserId", 'createdAt.isAfter(seenAt)',
                     '_unreadPrivateMessageCount + _unreadGroupMessageCount',
                     'notifications.where((n) => n.userId == currentUserId)', 'mine.take(50)',
                     "set({'read': true, 'updatedAt': FieldValue.serverTimestamp()}",
                     'AdminPanelPage(', 'saveLocation: _saveLocationDirect', 'deleteLocation: _deleteLocationDirect'):
            self.assertIn(item, navigation)
