part of '../main.dart';

class PendingApprovalPage extends StatelessWidget {
  final FirebaseUserProfile profile;
  final AppSettings settings;

  const PendingApprovalPage({
    super.key,
    required this.profile,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return account_access_views.PendingApprovalView(
      profileName: profile.name,
      email: profile.email,
      logo: appBrandLogo(settings, width: 500, height: 125),
      backdropBuilder: (child) => _AppBackdrop(
        settings: settings,
        child: child,
      ),
      onSignOut: () => FirebaseAuth.instance.signOut(),
    );
  }
}

class MissingProfilePage extends StatelessWidget {
  final String email;

  const MissingProfilePage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return account_access_views.MissingProfileView(
      email: email,
      onSignOut: () => FirebaseAuth.instance.signOut(),
    );
  }
}
