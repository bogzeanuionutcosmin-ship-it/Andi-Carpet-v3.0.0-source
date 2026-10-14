# MISIUNEA IV — AuthGate modularizat: execuție

## Lot RED pregătit

Bază #35 `71369b6b0eebc7c73ddf2cb55455309b3f0e1ba8`, #28 `fd602ed4bd727e2c2b41cf24ac988a818a2564ff`; sursă #33 `a5f43ef9ce0bfedaf59766aafe18732fef7f8f47`. #34 a avansat extern (`6f57c4645cd80f7ceaef6457c7bbd6eae558d139` la preflight), #29 `545e0202755a8ee86a7b3406adccd469aac84f9e`; sursele nu sunt modificate.

12 acceptanțe și 8 controale portate din #33. Harness-ul folosește AuthGateSources #28 și State Home modularizat real; seam-uri opționale SDK FCM și startup, porturile query/sync/push/maintenance existente păstrate. ROOT primește sursele și builderul injectat; încă nu are reset de Navigator/Messenger. Builderul existent cu două argumente rămâne compatibil; un builder separat permite ownership. În acest lot ownership este doar mounted, fără remediere funcțională.

Matrice destinație: AuthGate/Sources → `lib/auth/auth_gate.dart`; ROOT → `lib/ui/app_root_theme.dart`; Home/ownership → `lib/home/home_page.dart`; FCM → `home_push_notifications.dart`; GPS → `home_live_location.dart`; deliveries/post-frame → `home_sync_listeners.dart`, `home_directory_definitions_audit_sync.dart`, `home_financial_sync.dart`; rute → `home_navigation.dart`.

Assertions #33 păstrate; două adaptări de wiring: Sources în mount și syncFirestore/pushFirestore în fixture Home. Caracterizările KNOWN DEFECT #28 rămân intacte în RED. Contractele Python actualizează numai literalii de fallback SDK/startup, păstrând ordinea și toate invariant-ele anterioare.

Local: 158 Python PASS; diff whitespace PASS. Flutter/Dart lipsesc local. Dovada RED de comportament trebuie citită din CI manual pe SHA exact înainte de fix. Nicio eroare de fixture/compilare nu va fi considerată dovadă P1.

Fără main/merge/deploy/APK/Firebase producție/finanțe/roluri/parser/backup ori editări #28/#33/#34/#29. Cele 59 parts rămân. Stadiu A01–A12/C01–C08: NEEXECUTAT până la CI; P1 încă deschis pe integrare.
