# Android build reproducibility and supply-chain evidence

Status: NOT VERIFIED.

## Capture for each candidate
- Git commit and combined tree SHA; lockfile hash and exact Flutter/Dart versions.
- JDK, Gradle, Android Gradle Plugin, Android SDK, NDK and build-tools versions.
- Build environment identity, runner image, build command and build logs.
- Artifact SHA-256, package metadata, signing certificate fingerprint and source-to-artifact provenance attestation.
- Dependency vulnerability review, license review and dependency download integrity evidence.

## Rebuild protocol
1. Checkout the exact reviewed commit and verify lockfile.
2. Build in a fresh isolated environment without production credentials.
3. Compare unsigned intermediate outputs where reproducible; signing timestamps and archive metadata can legitimately differ.
4. Verify signed artifact provenance independently rather than requiring naive byte-for-byte identity across signing runs.
5. Retain original and rebuilt artifact hashes, normalized differences and reviewer disposition.

## Release blocks
Unexplained dependency changes, unsigned or debug-signed distribution, missing builder identity, unknown artifact origin, or missing upgrade evidence. No production build or signing performed by this PR.
