# Staging test data lifecycle

Status: PROCEDURE ONLY. No dataset created or deleted.

## Dataset policy
Use synthetic identities, fake telephone numbers that cannot reach real people, synthetic team names and non-real financial values. Avoid importing production Firestore documents, authentication records or photo data.

## Lifecycle
1. Provision staging-only Auth and Firestore fixtures with a documented namespace and TTL.
2. Record fixture generator revision and SHA-256 of non-sensitive fixture manifest.
3. Run access-control, directory projection, concurrent edit and migration tests.
4. Capture redacted logs and aggregate counts; never publish private profile fields.
5. Delete synthetic staging fixtures using an explicitly scoped project and collection prefix, after confirming no production credentials are present.
6. Retain only anonymized evidence needed for audit; document retention and deletion ownership.

## Fail-closed protections
Every mutating script must require an explicit non-production project ID and refuse `andicarpet-e777e`. Deletion commands must require a synthetic namespace allowlist, dry-run preview and operator review. Unknown project or namespace means STOP.

## Ownership
Luna owns feature implementation; this independent lane defines acceptance and data hygiene only.
