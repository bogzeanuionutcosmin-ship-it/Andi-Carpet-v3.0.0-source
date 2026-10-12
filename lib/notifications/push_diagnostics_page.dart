part of '../main.dart';

class PushDiagnosticsPage extends StatefulWidget {
  final String userId;
  const PushDiagnosticsPage({super.key, required this.userId});
  @override State<PushDiagnosticsPage> createState() => _PushDiagnosticsPageState();
}

class _PushDiagnosticsPageState extends State<PushDiagnosticsPage> {
  bool _busy = false;
  String _permission = 'Neverificat';
  String _vapid = kIsWeb ? (_webPushVapidKey.trim().isEmpty ? 'LIPSEȘTE' : 'Configurată') : 'Nu este necesară';
  String _token = 'Neverificat';
  String _firestore = 'Neverificat';
  String _details = '';

  String _tokenDocId(String token) => base64UrlEncode(utf8.encode(token)).replaceAll('=', '');
  String _authorizationLabel(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized => 'Permisă',
    AuthorizationStatus.provisional => 'Provizorie',
    AuthorizationStatus.denied => 'Refuzată',
    AuthorizationStatus.deniedPermanently => 'Refuzată permanent',
    AuthorizationStatus.notDetermined => 'Nealeasă',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnly());
  }

  Future<void> _checkOnly() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() => _permission = _authorizationLabel(settings.authorizationStatus));
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(widget.userId).collection('pushTokens').get();
      if (!mounted) return;
      setState(() {
        _firestore = snap.docs.isEmpty ? 'Niciun token salvat' : '${snap.docs.length} token(uri) salvate';
      });
    } catch (e) {
      if (mounted) setState(() => _details = 'Verificare: $e');
    }
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _details = '';
      _token = 'Se generează...';
      _firestore = 'În așteptare...';
    });
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (!mounted) return;
      setState(() => _permission = _authorizationLabel(settings.authorizationStatus));
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.deniedPermanently) {
        throw StateError('Permisiunea pentru notificări este refuzată în browser/telefon.');
      }
      if (kIsWeb && _webPushVapidKey.trim().isEmpty) {
        throw StateError('Cheia VAPID nu există în build. Recompilează cu --dart-define=FCM_WEB_VAPID_KEY=CHEIA_PUBLICĂ.');
      }
      if (kIsWeb) await Future<void>.delayed(const Duration(seconds: 1));
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webPushVapidKey)
          : await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Firebase Messaging nu a returnat niciun token FCM.');
      }
      if (!mounted) return;
      setState(() => _token = '${token.substring(0, token.length < 18 ? token.length : 18)}… (${token.length} caractere)');

      final ref = FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('pushTokens').doc(_tokenDocId(token));
      await ref.set({
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final verify = await ref.get();
      if (!verify.exists) throw StateError('Tokenul a fost trimis către Firestore, dar documentul nu poate fi recitit.');
      if (!mounted) return;
      setState(() {
        _firestore = 'Salvat corect';
        _details = 'Dispozitivul este înregistrat pentru push. Acum poți închide aplicația și trimite o notificare de test.';
      });
      showSuccessMessage(context, 'Dispozitivul a fost înregistrat pentru notificări Push.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _token = 'Eroare';
        _firestore = e.plugin == 'cloud_firestore' ? 'Eroare Firestore' : _firestore;
        _details = '${e.plugin}/${e.code}: ${e.message ?? e.toString()}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _token = 'Eroare';
        _details = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String title, String value, {IconData? icon}) => ListTile(
    leading: Icon(icon ?? Icons.info_outline),
    title: Text(title),
    subtitle: Text(value),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificări Push')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Diagnostic dispozitiv', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Înregistrarea se face automat la login/pornire. Pagina aceasta rămâne doar pentru diagnostic: permisiune → VAPID → token FCM → salvare Firestore.'),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        _row('Permisiune notificări', _permission, icon: Icons.notifications_outlined),
        const Divider(height: 1),
        _row('Cheie VAPID', _vapid, icon: Icons.vpn_key_outlined),
        const Divider(height: 1),
        _row('Token FCM', _token, icon: Icons.key_outlined),
        const Divider(height: 1),
        _row('Firestore / pushTokens', _firestore, icon: Icons.cloud_done_outlined),
      ])),
      if (_details.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: SelectableText(_details, style: const TextStyle(fontFamily: 'monospace')),
        )),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _register,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
        label: Text(_busy ? 'Se înregistrează...' : 'Reînregistrează manual (diagnostic)'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _checkOnly,
        icon: const Icon(Icons.search),
        label: const Text('Verifică din nou'),
      ),
      const SizedBox(height: 12),
      if (kIsWeb) const Text(
        'Dacă apare o eroare care menționează FCM Registration API, activează API-ul Firebase Cloud Messaging Registration pentru proiect și încearcă din nou. Pe web cheia VAPID publică trebuie inclusă la fiecare build.',
        style: TextStyle(fontSize: 12),
      ),
    ]),
  );
}

String privateChatId(String a, String b) {
  final ids = <String>[a, b]..sort();
  return '${ids[0]}__${ids[1]}';
}

Uint8List? decodeProfilePhoto(String? value) {
  if (value == null || value.isEmpty) return null;
  try { return base64Decode(value); } catch (_) { return null; }
}

Future<void> showProfilePhotoViewer(BuildContext context, String photoBase64, String displayName) async {
  final bytes = decodeProfilePhoto(photoBase64);
  if (bytes == null) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .90),
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: SizedBox(
        width: MediaQuery.sizeOf(c).width * .94,
        height: MediaQuery.sizeOf(c).height * .90,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              left: 16,
              top: 14,
              right: 62,
              child: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
            ),
            Positioned(
              right: 8,
              top: 6,
              child: IconButton.filled(
                tooltip: 'Închide',
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(c),
                icon: const Icon(Icons.close),
              ),
            ),
            const Positioned(
              left: 16,
              bottom: 12,
              child: Text('Zoom cu două degete', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    ),
  );
}

String memberFunctionsText(Map<String,dynamic> d, List<FunctionDefinition> defs) {
  final ids = d['functionIds'] is List
      ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : <String>[(d['function'] ?? '').toString()].where((e) => e.isNotEmpty).toList();
  final names = ids.map((id) => functionById(defs, id)?.name ?? id).where((e) => e.trim().isNotEmpty).toList();
  return names.isEmpty ? 'Membru' : names.join(', ');
}

String _profileDisplayName(Map<String,dynamic> d,{String fallback='Membru'}) {
  final nickname=(d['nickname']??'').toString().trim();
  final name=(d['name']??d['email']??fallback).toString().trim();
  return d['useNickname']==true && nickname.isNotEmpty ? nickname : (name.isEmpty?fallback:name);
}

const Map<String,String> _andiCustomEmojis=<String,String>{
  'mop_magic':'🧹✨',
  'clean_done':'🧼✅',
  'money_day':'💸🧽',
  'salary_late':'🥲💸',
  'coffee_shift':'☕🧹',
  'foam_party':'🫧🎉',
  'snow_clean':'❄️🧼',
  'casino_clean':'🎰🧹',
};

const Map<String,String> _andiStickerAssets=<String,String>{
  'brc_01':'assets/stickers/sticker_01.png',
  'brc_02':'assets/stickers/sticker_02.png',
  'brc_03':'assets/stickers/sticker_03.png',
  'brc_04':'assets/stickers/sticker_04.png',
  'brc_05':'assets/stickers/sticker_05.png',
  'brc_06':'assets/stickers/sticker_06.png',
  'brc_07':'assets/stickers/sticker_07.png',
  'brc_08':'assets/stickers/sticker_08.png',
  'brc_09':'assets/stickers/sticker_09.png',
  'brc_10':'assets/stickers/sticker_10.png',
  'brc_11':'assets/stickers/sticker_11.png',
  'brc_12':'assets/stickers/sticker_12.png',
  'brc_13':'assets/stickers/sticker_13.png',
  'brc_14':'assets/stickers/sticker_14.png',
  'brc_15':'assets/stickers/sticker_15.png',
  'brc_16':'assets/stickers/sticker_16.png',
  'brc_17':'assets/stickers/sticker_17.png',
  'brc_18':'assets/stickers/sticker_18.png',
  'brc_19':'assets/stickers/sticker_19.png',
  'brc_20':'assets/stickers/sticker_20.png',
  'brc_21':'assets/stickers/sticker_21.png',
  'brc_22':'assets/stickers/sticker_22.png',
  'brc_23':'assets/stickers/sticker_23.png',
  'brc_24':'assets/stickers/sticker_24.png',
  'brc_25':'assets/stickers/sticker_25.png',
  'brc_26':'assets/stickers/sticker_26.png',
  'brc_27':'assets/stickers/sticker_27.png',
  'brc_28':'assets/stickers/sticker_28.png',
  'brc_29':'assets/stickers/sticker_29.png',
  'brc_30':'assets/stickers/sticker_30.png',
  'brc_31':'assets/stickers/sticker_31.png',
  'brc_32':'assets/stickers/sticker_32.png',
};

const Map<String,String> _andiStickerFallback=<String,String>{
  'brc_01':'MU!E!',
  'brc_02':'MARȘ!',
  'brc_03':'IA-O!',
  'brc_04':'CHEF DE MUNCĂ: 0%',
  'brc_05':'NU ȘTIU...',
  'brc_06':'CAFELUȚA ȘI BĂGAȚI MOCHETA',
  'brc_07':'TU?',
  'brc_08':'TU EȘTI PROBLEMA!',
  'brc_09':'VOI SUNTEȚI PROBLEMA!',
  'brc_10':'BRC CREW',
  'brc_11':'BOSS',
  'brc_12':'ȘTII TU...',
  'brc_13':'PE BUNE?',
  'brc_14':'HAHAHA!',
  'brc_15':'VINERI!!',
  'brc_16':'ȘEFU VINE!',
  'brc_17':'FACEM?',
  'brc_18':'PSST...',
  'brc_19':'IAR MOCHETA?!',
  'brc_20':'NU E TREABA MEA',
  'brc_21':'NE MAI DUCEM O TURĂ?',
  'brc_22':'BERE?',
  'brc_23':'POFTIM?',
  'brc_24':'CE ZI DE CĂCAT...',
  'brc_25':'DU-TE-N...',
  'brc_26':'IAR?',
  'brc_27':'POWER',
  'brc_28':'WTF?',
  'brc_29':'NA, IA-O!',
  'brc_30':'MUNCĂ... MÂINE',
  'brc_31':'AM VENIT PENTRU MOCHETĂ... CICĂ',
  'brc_32':'AȘA DA!',
};

String? _andiReactionFallback(String key) => _andiStickerFallback[key] ?? _andiCustomEmojis[key];

bool _andiHasReaction(String key) => _andiStickerAssets.containsKey(key) || _andiCustomEmojis.containsKey(key);

Widget _andiReactionWidget(String key, {double size = 104}) {
  final asset = _andiStickerAssets[key];
  if (asset != null) return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  final emoji = _andiCustomEmojis[key] ?? '';
  return Text(emoji, style: TextStyle(fontSize: size * .38));
}

Future<String?> _showAndiReactionPicker(BuildContext context, {String? subtitle}) {
  final keys = <String>[..._andiStickerAssets.keys, ..._andiCustomEmojis.keys];
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final compact = MediaQuery.sizeOf(c).width < 600;
      return SafeArea(
        child: SizedBox(
          height: math.min(MediaQuery.sizeOf(c).height * .74, 680.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Stickere & emoticoane Andi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle ?? 'Set intern pentru chat și mesaje.'),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: keys.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: compact ? 4 : 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final label = _andiReactionFallback(key) ?? 'Sticker Andi';
                    return Tooltip(
                      message: label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(c, key),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(c).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: _andiReactionWidget(key, size: compact ? 76 : 92)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

