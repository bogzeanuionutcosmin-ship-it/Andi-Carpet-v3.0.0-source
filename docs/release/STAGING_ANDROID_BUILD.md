# Isolated Android staging build

Status: PREPARED, NOT BUILT OR VALIDATED ON A PHONE. No isolated staging Firebase
configuration was supplied in this session. An emulator artifact is not this APK.

Use an independently configured Firebase project whose ID contains `staging`.
Register Android package `com.example.andi_carpeta.staging`, download that client's
public google-services.json, and configure test Auth/users/permissions, Firestore
rules, Functions (including closeProgramGraph), budgets and synthetic data in
that project through a separately authorized rollout. No production copy/restore.

The optional `staging-android.yml` job requires repository variables:

- `ANDICARPET_STAGING_ANDROID_CONFIG`: the separate Android public Firebase JSON;
- `ANDICARPET_STAGING_PROJECT_ID`: its exact approved project ID.

Missing variables skip the build; they do not create a placeholder APK or prove
staging acceptance. No service account, private signing key or deploy credential
is used by this build. The same builder can run locally:

```sh
python3 scripts/build_staging_android.py --config /absolute/path/staging-google-services.json --output build/staging
```

The builder rejects production project/number/storage/package configuration,
compiles only debug, temporarily substitutes native Firebase config and label,
and restores the original bytes even after failure. Dart initialization selects
explicit staging options without falling back to production. Login alias,
geocoding, SMS administration and STOP endpoints derive from the selected project.
The staging package installs alongside production and uses the debug test key.
It does not validate production signing lineage or an upgrade of production.

The generated manifest records source SHA, APK SHA-256, inspected package ID and
certificate SHA-256. Verify these values before installation. No APK has been
published or distributed by the builder. Run ANDROID_DEVICE_TEST_MATRIX and
ANDROID_UPGRADE_ROLLBACK_RUNBOOK with staged test identities. GPS/background,
camera/real ML OCR, offline/reconnect, process death and test-to-test upgrade
remain NOT RUN until physical evidence is recorded. Provider tokens/costs and
backend rollout are independent required gates, not implied by compilation.
