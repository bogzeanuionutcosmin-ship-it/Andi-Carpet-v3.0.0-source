# Mapbox integration (v3.0.1)

- Flutter map tiles use Mapbox Streets v12 if a public `pk.*` token is supplied at build time. Without it, OSM tiles are used for local development.
- Road distance estimates use Mapbox Directions driving when token is available. Routes over 25 waypoints are split into overlapping chunks (25 points, 24 new segments per chunk).
- If Mapbox Directions fails, the app returns `null` rather than misrepresenting straight-line distance as road distance.
- GitHub Android workflow already passes `MAPBOX_ACCESS_TOKEN` via `--dart-define`. Do not commit the token. Use a public token (pk.*), never an sk.* secret in a client app.
- For web, pass the same define to `flutter build web`; the existing Firebase Hosting deployment does not automatically inherit GitHub Secrets.
- Mapbox Optimization and Map Matching are **not** implemented by this patch. Existing Learning ordering and GPS location logic remain intact.
- Requires Flutter compilation and on-device checks with valid token. No GitHub or APK changes made.
