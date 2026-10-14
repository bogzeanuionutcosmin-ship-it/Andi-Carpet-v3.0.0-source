part of '../main.dart';

class AuthGate extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final AuthGateSources? sources;
  final bool Function(String?)? onSessionChanged;
  final Widget Function(Key key, FirebaseUserProfile profile)? activePageBuilder;
  final Widget Function(Key key, FirebaseUserProfile profile, bool Function() sessionIsCurrent)? activeSessionPageBuilder;
  const AuthGate({super.key, required this.settings, required this.onSettingsChanged, this.sources, this.activePageBuilder, this.activeSessionPageBuilder, this.onSessionChanged});

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
  int _sessionGeneration = 0;
  int _profileGeneration = 0;

  late final AuthGateSources _sources;
  User? get _currentUser => _sources.currentUser();

  @override
  void initState() {
    super.initState();
    _sources = widget.sources ?? _firebaseAuthGateSources();

    _uiSettingsSubscription = _sources.uiSettingsSnapshots().listen((snap) {
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

    _authSubscription = _sources.authStateChanges().listen(
      _handleAuthChange,
      onError: (Object e) {
        if (!mounted) return;
        // Stream errors do not authorize fallback across a changed SDK UID.
        final current = _currentUser;
        if (_user?.uid != current?.uid) {
          _handleAuthChange(current);
          return;
        }
        setState(() => _error = 'Autentificare: $e');
      },
    );
  }

  void _resetPersonalPreferences() {
    final defaults = AppSettings();
    final changed = widget.settings.theme != defaults.theme ||
        widget.settings.fontFamily != defaults.fontFamily ||
        widget.settings.personalBackgroundId != defaults.personalBackgroundId;
    widget.settings.theme = defaults.theme;
    widget.settings.fontFamily = defaults.fontFamily;
    widget.settings.personalBackgroundId = defaults.personalBackgroundId;
    // Branding, global backgrounds, templates and business settings are shared.
    if (changed && mounted) widget.onSettingsChanged();
  }

  void _handleAuthChange(User? eventUser) {
    if (!mounted) return;
    // Preserve transient same-UID reconnects while SDK currentUser is valid.
    final effectiveUser = eventUser ?? _currentUser;
    if (effectiveUser == null) {
      final hadSession = _user != null;
      if (hadSession) _sessionGeneration++;
      _profileGeneration++;
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
      if (hadSession) _resetPersonalPreferences();
      widget.onSessionChanged?.call(null);
      return;
    }

    final changedUser = _user?.uid != effectiveUser.uid;
    if (changedUser) {
      // Invalidate ownership synchronously, before the next frame/dispose.
      _sessionGeneration++;
      _profileGeneration++;
      _profileSubscription?.cancel();
      _profileSubscription = null;
      setState(() {
        _user = effectiveUser;
        _authInitialized = true;
        _profile = null;
        _profileUid = null;
        _profileInitialized = false;
        _error = null;
      });
      _resetPersonalPreferences();
      // A replacing root will create its own listener; avoid a duplicate read.
      if (widget.onSessionChanged?.call(effectiveUser.uid) != true) {
        _listenProfile(effectiveUser);
      }
      return;
    }

    _user = effectiveUser;
    _authInitialized = true;
    _error = null;
    if (_profileUid != effectiveUser.uid || _profileSubscription == null) {
      _listenProfile(effectiveUser);
    } else if (_profile == null) {
      setState(() {});
    }
  }

  void _listenProfile(User user) {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _profileUid = user.uid;
    _profileInitialized = false;
    final generation = ++_profileGeneration;
    final session = _sessionGeneration;
    bool ownsProfile() => mounted && generation == _profileGeneration &&
        session == _sessionGeneration && _user?.uid == user.uid &&
        _currentUser?.uid == user.uid;

    _profileSubscription = _sources.profileSnapshots(user.uid)
        .listen((snap) {
      if (!ownsProfile()) return;

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
      if (!ownsProfile()) return;
      // Dacă aveam deja profil valid, păstrăm interfața și nu pâlpâim spre
      // pagina de eroare la o reconectare scurtă. Arătăm eroarea doar la
      // încărcarea inițială când nu avem nimic utilizabil.
      if (_profile?.uid == user.uid) return;
      setState(() {
        _profileInitialized = true;
        _error = 'Nu am putut citi profilul: $e';
      });
    });
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _profileGeneration++;
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

    final profile = _profile?.uid == user.uid ? _profile : null;
    if (_error != null && profile == null) {
      return _FirebaseError(message: _error!);
    }

    // Profilul este singura încărcare pentru care acceptăm splash, și doar
    // la prima deschidere reală a sesiunii. După aceea UI-ul rămâne montat.
    if (!_profileInitialized && profile == null) {
      return _FirebaseLoading(text: 'Se încarcă profilul...', settings: widget.settings);
    }

    if (profile == null) {
      return MissingProfilePage(email: user.email ?? '');
    }
    if (!profile.active) return PendingApprovalPage(profile: profile, settings: widget.settings);

    final generation = _sessionGeneration;
    bool sessionIsCurrent() => mounted && generation == _sessionGeneration &&
        _user?.uid == profile.uid && _currentUser?.uid == profile.uid;
    if (widget.activeSessionPageBuilder != null) {
      return widget.activeSessionPageBuilder!(ValueKey(profile.uid), profile, sessionIsCurrent);
    }
    if (widget.activePageBuilder != null) {
      return widget.activePageBuilder!(ValueKey(profile.uid), profile);
    }
    return HomePage(
      key: ValueKey(profile.uid),
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      profile: profile,
      sessionIsCurrent: sessionIsCurrent,
    );
  }
}

