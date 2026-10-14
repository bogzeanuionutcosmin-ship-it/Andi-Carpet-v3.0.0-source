part of '../main.dart';

class AuthGate extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final Widget Function(Key, FirebaseUserProfile, bool Function())? homeBuilder;
  const AuthGate({super.key, required this.settings, required this.onSettingsChanged, this.auth, this.firestore, this.homeBuilder});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _uiSettingsSubscription;

  User? _user;
  FirebaseUserProfile? _profile;
  String? _profileUid;
  String? _error;
  bool _authInitialized = false;
  bool _profileInitialized = false;

  User? get _currentUser => widget.auth == null
      ? FirebaseAuth.instance.currentUser : widget.auth!.currentUser;
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _uiSettingsSubscription = _db.collection('meta').doc('uiSettings').snapshots().listen((snap) {
      final d = snap.data();
      if (d == null || !mounted) return;
      var changed = false;
      final bg = (d['brandingBackgroundId'] ?? widget.settings.brandingBackgroundId).toString();
      final logo = (d['brandingLogoId'] ?? widget.settings.brandingLogoId).toString();
      final apkUrl = (d['androidDownloadUrl'] ?? widget.settings.androidDownloadUrl).toString();
      final opacity = d['backgroundOpacity'] is num
          ? (d['backgroundOpacity'] as num).toDouble().clamp(0.0, .70).toDouble()
          : widget.settings.backgroundOpacity;
      if (bg != widget.settings.brandingBackgroundId) { widget.settings.brandingBackgroundId = bg; changed = true; }
      if (logo != widget.settings.brandingLogoId) { widget.settings.brandingLogoId = logo; changed = true; }
      if (apkUrl != widget.settings.androidDownloadUrl) { widget.settings.androidDownloadUrl = apkUrl; changed = true; }
      if (opacity != widget.settings.backgroundOpacity) { widget.settings.backgroundOpacity = opacity; changed = true; }
      if (changed) {
        widget.onSettingsChanged();
        setState(() {});
      }
    });

    // Folosim currentUser imediat, astfel încât Chrome/PWA să nu afișeze
    // splash-ul între refaceri de widget / reconectări scurte ale streamului.
    _user = _currentUser;
    _authInitialized = true;
    if (_user != null) {
      _listenProfile(_user!);
    }

    _authSubscription = (widget.auth ?? FirebaseAuth.instance).authStateChanges().listen(
      _handleAuthChange,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = 'Autentificare: $e');
      },
    );
  }

  void _handleAuthChange(User? eventUser) {
    if (!mounted) return;

    // Unele versiuni Chrome/PWA pot emite o stare intermediară în timp ce
    // Firebase își reface persistența. Dacă Firebase încă are currentUser,
    // păstrăm sesiunea activă și NU revenim la splash/login.
    final effectiveUser = eventUser ?? _currentUser;

    if (effectiveUser == null) {
      _profileSubscription?.cancel();
      _profileSubscription = null;
      setState(() {
        _authInitialized = true;
        _user = null;
        _profile = null;
        _profileUid = null;
        _profileInitialized = false;
        _error = null;
      });
      return;
    }

    final changedUser = _user?.uid != effectiveUser.uid;
    _user = effectiveUser;
    _authInitialized = true;
    _error = null;

    if (changedUser || _profileUid != effectiveUser.uid || _profileSubscription == null) {
      _listenProfile(effectiveUser);
    } else {
      // Nu chemăm setState inutil dacă avem deja profilul activ.
      if (_profile == null && mounted) setState(() {});
    }
  }

  void _listenProfile(User user) {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _profileUid = user.uid;
    _profileInitialized = false;

    _profileSubscription = _db
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      if (!mounted || _user?.uid != user.uid) return;

      // Snapshot-urile din cache sunt perfect valide pentru UI. Nu revenim
      // la ecranul de încărcare cât timp avem deja un profil bun memorat.
      if (!snap.exists) {
        setState(() {
          _profileInitialized = true;
          _profile = null;
          _error = null;
        });
        return;
      }

      final next = FirebaseUserProfile.fromSnapshot(user, snap);
      setState(() {
        _profileInitialized = true;
        _profile = next;
        _error = null;
      });
    }, onError: (Object e) {
      if (!mounted || _user?.uid != user.uid) return;
      // Dacă aveam deja profil valid, păstrăm interfața și nu pâlpâim spre
      // pagina de eroare la o reconectare scurtă. Arătăm eroarea doar la
      // încărcarea inițială când nu avem nimic utilizabil.
      if (_profile != null) return;
      setState(() {
        _profileInitialized = true;
        _error = 'Nu am putut citi profilul: $e';
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _uiSettingsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authInitialized) {
      return _FirebaseLoading(text: 'Se verifică autentificarea...', settings: widget.settings);
    }

    final user = _user ?? _currentUser;
    if (user == null) return LoginPage(settings: widget.settings);

    if (_error != null && _profile == null) {
      return _FirebaseError(message: _error!);
    }

    // Profilul este singura încărcare pentru care acceptăm splash, și doar
    // la prima deschidere reală a sesiunii. După aceea UI-ul rămâne montat.
    if (!_profileInitialized && _profile == null) {
      return _FirebaseLoading(text: 'Se încarcă profilul...', settings: widget.settings);
    }

    final profile = _profile;
    if (profile == null) {
      return MissingProfilePage(email: user.email ?? '');
    }
    if (!profile.active) return PendingApprovalPage(profile: profile, settings: widget.settings);

    if (widget.homeBuilder != null) {
      return widget.homeBuilder!(ValueKey(profile.uid), profile, () => true);
    }
    return HomePage(
      key: ValueKey(profile.uid),
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      profile: profile,
    );
  }
}

