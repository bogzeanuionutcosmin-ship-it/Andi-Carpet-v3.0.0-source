part of '../main.dart';

class LoginPage extends StatefulWidget {
  final AppSettings settings;
  final LoginActions? actions;
  const LoginPage({super.key, required this.settings, this.actions});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginActions _actions;

  @override
  void initState() {
    super.initState();
    _actions = widget.actions ?? _firebaseLoginActions();
  }

  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final name = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  bool createMode = false;
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); confirmPassword.dispose(); name.dispose(); username.dispose(); phone.dispose(); super.dispose(); }

  String _friendly(Object e) => friendlyLoginError(e);

  String _normalizePhone(String value) => normalizeLoginPhone(value);

  Future<String> _resolveLoginIdentifier(String identifier, String pass) =>
      _actions.resolveIdentifier(identifier, pass);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final identifier = email.text.trim();
    final pass = password.text;
    final requestedUsername = username.text.trim().toLowerCase();
    final requestedPhone = phone.text.trim();
    if (identifier.isEmpty || pass.isEmpty || (createMode && (name.text.trim().isEmpty || requestedUsername.isEmpty))) {
      setState(() => error = 'Completează toate câmpurile obligatorii.');
      return;
    }
    if (createMode && !RegExp(r'^[a-zA-Z0-9._-]{3,30}$').hasMatch(requestedUsername)) {
      setState(() => error = 'Username-ul trebuie să aibă 3–30 caractere: litere, cifre, punct, _ sau - .');
      return;
    }
    if (createMode && requestedPhone.isNotEmpty && _normalizePhone(requestedPhone).length < 8) {
      setState(() => error = 'Numărul de telefon nu pare complet.');
      return;
    }
    if (createMode && pass != confirmPassword.text) {
      setState(() => error = 'Parolele nu coincid.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      if (createMode) {
        final mail = identifier;
        final credential = await _actions.createUser(email: mail, password: pass);
        final user = credential.user!;
        await user.updateDisplayName(name.text.trim());
        await _actions.writeProfile(user.uid, {
          'name': name.text.trim(),
          'email': mail,
          'username': requestedUsername,
          'usernameNormalized': requestedUsername,
          'phone': requestedPhone,
          'phoneNormalized': _normalizePhone(requestedPhone),
          'role': 'member',
          'function': '',
          'functionIds': const <String>[],
          'effectivePermissions': const <String>[],
          'active': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final resolvedEmail = await _resolveLoginIdentifier(identifier, pass);
        await _actions.signIn(email: resolvedEmail, password: pass);
        TextInput.finishAutofillContext(shouldSave: true);
      }
    } catch (e) {
      if (mounted) setState(() => error = _friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty || !mail.contains('@')) { setState(() => error = 'Pentru resetarea parolei scrie adresa de email a contului.'); return; }
    try {
      await _actions.resetPassword(email: mail);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emailul pentru resetarea parolei a fost trimis.')));
    } catch (e) { if (mounted) setState(() => error = _friendly(e)); }
  }

  @override
  Widget build(BuildContext context) => LoginPageView(
    controllers: LoginFormControllers(email: email, password: password,
      confirmPassword: confirmPassword, name: name, username: username, phone: phone),
    backdrop: (child) => _AppBackdrop(settings: widget.settings, child: child),
    logo: appBrandLogo(widget.settings, width: 520, height: 130),
    installButtons: _InstallAppButtons(settings: widget.settings),
    createMode: createMode, busy: busy, obscure: obscure, error: error,
    onSubmit: _submit, onResetPassword: _resetPassword,
    onToggleObscure: () => setState(() => obscure = !obscure),
    onToggleMode: () => setState(() { createMode = !createMode; error = null; }),
  );
}
