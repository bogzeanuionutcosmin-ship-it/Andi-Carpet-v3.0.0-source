import '../models/app_data_models.dart';

/// Existing notification-recipient projection. This selects active profiles;
/// it does not grant administrative authority or send a notification.
List<AppUser> activeAdminNotificationRecipients(Iterable<AppUser> users) =>
    users.where((u) => u.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
