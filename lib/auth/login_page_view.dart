import 'package:flutter/material.dart';

/// Borrowed controllers: ownership and disposal remain with LoginPage State.
class LoginFormControllers {
  final TextEditingController email, password, confirmPassword, name, username, phone;
  const LoginFormControllers({required this.email, required this.password,
    required this.confirmPassword, required this.name, required this.username, required this.phone});
}

/// Visual form only: no Auth, Firestore, storage, validation or session state.
class LoginPageView extends StatelessWidget {
  final LoginFormControllers controllers;
  final Widget Function(Widget child) backdrop;
  final Widget logo;
  final Widget installButtons;
  final bool createMode, busy, obscure;
  final String? error;
  final Future<void> Function() onSubmit, onResetPassword;
  final VoidCallback onToggleMode, onToggleObscure;
  const LoginPageView({super.key, required this.controllers, required this.backdrop,
    required this.logo, required this.installButtons, required this.createMode,
    required this.busy, required this.obscure, required this.error,
    required this.onSubmit, required this.onResetPassword,
    required this.onToggleMode, required this.onToggleObscure});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: backdrop(
        Container(
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
                        logo,
                        const SizedBox(height: 12),
                        installButtons,
                        const SizedBox(height: 20),
                        Text(createMode ? 'Creează cont' : 'Autentificare', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(createMode ? 'Contul nou va aștepta aprobarea Administratorului.' : 'Andi Carpetă · acces securizat'),
                        const SizedBox(height: 20),
                        if (createMode) ...[
                          TextField(controller: controllers.name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nume și prenume', prefixIcon: Icon(Icons.person_outline))),
                          const SizedBox(height: 12),
                          TextField(controller: controllers.username, autocorrect: false, textCapitalization: TextCapitalization.none, decoration: const InputDecoration(labelText: 'Username', hintText: 'ex: timi', prefixIcon: Icon(Icons.alternate_email))),
                          const SizedBox(height: 12),
                          TextField(controller: controllers.phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon (opțional)', prefixIcon: Icon(Icons.phone_outlined))),
                          const SizedBox(height: 12),
                        ],
                        TextField(controller: controllers.email, keyboardType: createMode ? TextInputType.emailAddress : TextInputType.text, autocorrect: false, textCapitalization: TextCapitalization.none, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: InputDecoration(labelText: createMode ? 'Email' : 'Email / username / telefon', prefixIcon: Icon(createMode ? Icons.email_outlined : Icons.account_circle_outlined))),
                        const SizedBox(height: 12),
                        TextField(controller: controllers.password, obscureText: obscure, autofillHints: const [AutofillHints.password], onSubmitted: (_) => createMode ? null : onSubmit(), decoration: InputDecoration(labelText: 'Parolă', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: onToggleObscure, icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)))),
                        if (createMode) ...[
                          const SizedBox(height: 12),
                          TextField(controller: controllers.confirmPassword, obscureText: obscure, onSubmitted: (_) => onSubmit(), decoration: const InputDecoration(labelText: 'Confirmă parola', prefixIcon: Icon(Icons.lock_reset))),
                        ],
                        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)),
                        const SizedBox(height: 18),
                        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : onSubmit, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(createMode ? Icons.person_add_alt_1 : Icons.login), label: Text(createMode ? 'Creează contul' : 'Intră în cont'))),
                        if (!createMode) TextButton(onPressed: busy ? null : onResetPassword, child: const Text('Am uitat parola')),
                        const Divider(height: 28),
                        TextButton(onPressed: busy ? null : onToggleMode, child: Text(createMode ? 'Am deja cont · Autentificare' : 'Nu am cont · Creează cont')),
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
