import 'package:flutter/material.dart';

typedef AccountAccessBackdropBuilder = Widget Function(Widget child);

class PendingApprovalView extends StatelessWidget {
  final String profileName;
  final String email;
  final Widget logo;
  final AccountAccessBackdropBuilder backdropBuilder;
  final VoidCallback onSignOut;

  const PendingApprovalView({
    super.key,
    required this.profileName,
    required this.email,
    required this.logo,
    required this.backdropBuilder,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: backdropBuilder(
        Container(
          color: Colors.black.withValues(alpha: .26),
          child: Center(
            child: Card(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(height: 22),
                      const Icon(Icons.hourglass_top, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Cont în așteptare',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('$profileName\n$email', textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      const Text(
                        'Contul a fost creat. Administratorul trebuie să îl activeze și să îi atribuie funcția înainte de acces.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Ieși din cont'),
                      ),
                    ],
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

class MissingProfileView extends StatelessWidget {
  final String email;
  final VoidCallback onSignOut;

  const MissingProfileView({
    super.key,
    required this.email,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.manage_accounts_outlined, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Contul există în Authentication, dar profilul Firestore lipsește.',
                textAlign: TextAlign.center,
              ),
              if (email.isNotEmpty) Text(email),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onSignOut,
                child: const Text('Ieși din cont'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
