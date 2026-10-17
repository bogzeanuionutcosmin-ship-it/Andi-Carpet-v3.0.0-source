# Offline APK hash verifier

Executable: `tools/independent_release/verify_apk_manifest.py`.

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_verify_apk_manifest.py' -v
python3 tools/independent_release/verify_apk_manifest.py candidate.apk approved-manifest.json
```

Manifest example: `{"sha256":"<64-character approved SHA-256>"}`. The manifest MUST come from an independently trusted release approver, not the same untrusted download endpoint as the APK.

Exit 0 = bytes match supplied digest; exit 2 = mismatch; exit 3 = invalid input. Even exit 0 explicitly reports `signature_verified: false` and `release_approved: false`. Independently verify certificate and package identity using Android SDK tools before distribution.

The utility reads local files only, streams the hash in bounded chunks and does not access networks, Firebase, signing keys or production. Four synthetic tests are included; CI execution evidence is pending.
