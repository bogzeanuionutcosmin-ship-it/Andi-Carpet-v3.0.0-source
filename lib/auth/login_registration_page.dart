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
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AppBackdrop(
        settings: widget.settings,
        child: Container(
          color: Colors.black.withValues(alpha: 0.22),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Card(
                    elevation: 12,
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        appBrandLogo(widget.settings, width: 520, height: 130),
                        const SizedBox(height: 12),
                        _InstallAppButtons(settings:widget.settings),
                        const SizedBox(height: 20),
                        Text(createMode ? 'Creează cont' : 'Autentificare', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(createMode ? 'Contul nou va aștepta aprobarea Administratorului.' : 'Andi Carpetă · acces securizat'),
                        const SizedBox(height: 20),
                        if (createMode) ...[
                          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nume și prenume', prefixIcon: Icon(Icons.person_outline))),
                          const SizedBox(height: 12),
                          TextField(controller: username, autocorrect: false, textCapitalization: TextCapitalization.none, decoration: const InputDecoration(labelText: 'Username', hintText: 'ex: timi', prefixIcon: Icon(Icons.alternate_email))),
                          const SizedBox(height: 12),
                          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon (opțional)', prefixIcon: Icon(Icons.phone_outlined))),
                          const SizedBox(height: 12),
                        ],
                        TextField(controller: email, keyboardType: createMode ? TextInputType.emailAddress : TextInputType.text, autocorrect: false, textCapitalization: TextCapitalization.none, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: InputDecoration(labelText: createMode ? 'Email' : 'Email / username / telefon', prefixIcon: Icon(createMode ? Icons.email_outlined : Icons.account_circle_outlined))),
                        const SizedBox(height: 12),
                        TextField(controller: password, obscureText: obscure, autofillHints: const [AutofillHints.password], onSubmitted: (_) => createMode ? null : _submit(), decoration: InputDecoration(labelText: 'Parolă', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)))),
                        if (createMode) ...[
                          const SizedBox(height: 12),
                          TextField(controller: confirmPassword, obscureText: obscure, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Confirmă parola', prefixIcon: Icon(Icons.lock_reset))),
                        ],
                        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)),
                        const SizedBox(height: 18),
                        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : _submit, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(createMode ? Icons.person_add_alt_1 : Icons.login), label: Text(createMode ? 'Creează contul' : 'Intră în cont'))),
                        if (!createMode) TextButton(onPressed: busy ? null : _resetPassword, child: const Text('Am uitat parola')),
                        const Divider(height: 28),
                        TextButton(onPressed: busy ? null : () => setState(() { createMode = !createMode; error = null; }), child: Text(createMode ? 'Am deja cont · Autentificare' : 'Nu am cont · Creează cont')),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

