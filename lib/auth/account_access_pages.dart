part of '../main.dart';

class PendingApprovalPage extends StatelessWidget {
  final FirebaseUserProfile profile;
  final AppSettings settings;
  const PendingApprovalPage({super.key, required this.profile, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AppBackdrop(
        settings: settings,
        child: Container(
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
                      appBrandLogo(settings, width: 500, height: 125),
                      const SizedBox(height: 22),
                      const Icon(Icons.hourglass_top, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Cont în așteptare',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('${profile.name}\n${profile.email}', textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      const Text(
                        'Contul a fost creat. Administratorul trebuie să îl activeze și să îi atribuie funcția înainte de acces.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
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

class MissingProfilePage extends StatelessWidget {
  final String email;
  const MissingProfilePage({super.key, required this.email});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.manage_accounts_outlined, size: 52),
    const SizedBox(height: 12),
    const Text('Contul există în Authentication, dar profilul Firestore lipsește.', textAlign: TextAlign.center),
    if (email.isNotEmpty) Text(email),
    const SizedBox(height: 16),
    OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Ieși din cont')),
  ]))));
}

