# Mapbox follow-up: service layer

- Directions requests are now routed through `lib/mapbox_services.dart`, with a 10-minute in-memory cache and a request counter. Failed responses are never cached as successful distances.
- `matchTrace` supports optional, explicit matching of 2–100 GPS points; it does not start background tracking or transmit location automatically.
- `optimizedOrder` supports fixed start/end for 3–12 points and returns original indices. It is NOT wired to automatic schedule reordering: existing Learning and schedule constraints must remain authoritative.
- The Mapbox token must be a restricted public `pk.*` token supplied via dart-define. Web builds need their own define.
- No automatic retries. Calls are billed by Mapbox according to current plan; counter resets on app restart and is not billing analytics.
- Flutter/Dart tests and Mapbox live API checks were not run in this environment. Test with a real token before deployment.
- GitHub and APK unchanged.
