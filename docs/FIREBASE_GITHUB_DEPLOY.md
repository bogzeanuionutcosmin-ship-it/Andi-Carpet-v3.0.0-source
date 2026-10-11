# Firebase deployment via GitHub Actions

This repository deploys to Firebase project `andicarpet-e777e`.

## Security and rollout

The workflow `.github/workflows/firebase-oidc-deploy.yml` is **manual only**. Its `auth-only` mode checks OIDC authentication without deploying. Hosting and Functions deployment are restricted to the `main` branch and require typing `DEPLOY` in the confirmation input.

The GitHub Actions environment `firebase-production` should be configured in repository Settings → Environments, with deployment branches restricted to `main` and required reviewers where available. Note: GitHub environment protection and approval features vary by plan and repository visibility.

## Google Cloud prerequisites

- Project: `andicarpet-e777e` (project number `141489733149`).
- Workload Identity Pool: `github-actions-andicarpet`.
- Provider ID in the workflow: `github-actions`. **Confirm this is the actual provider ID**, not just its display name.
- Service account: `andicarpet-github-deploy@andicarpet-e777e.iam.gserviceaccount.com`.

Configure the OIDC provider to accept GitHub token issuer `https://token.actions.githubusercontent.com`, map `google.subject=assertion.sub` and `attribute.repository=assertion.repository`, and enforce this repository in the provider attribute condition:

```text
assertion.repository == 'bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source'
```

Allow the repository to impersonate the service account using `roles/iam.workloadIdentityUser` on **that service account**, with a member matching the repository:

```text
principalSet://iam.googleapis.com/projects/141489733149/locations/global/workloadIdentityPools/github-actions-andicarpet/attribute.repository/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source
```

Grant only the Google Cloud / Firebase roles needed for the specific deploy. Functions deployments may require additional permissions (including Cloud Build, Artifact Registry, Cloud Run and service account act-as), depending on the Firebase CLI and function setup. Avoid granting Owner or broad Service Account Admin privileges.

## First test

1. Merge the reviewed workflow PR into `main` once the Google Cloud binding and GitHub environment have been configured. This does **not** deploy.
2. In Actions, select **Firebase OIDC deploy** → **Run workflow**, branch `main`, target `auth-only`.
3. Check that the authentication step succeeds. If not, verify the provider ID, service-account IAM binding, attribute condition and environment protection.
4. Only after successful testing, manually choose `hosting` or `functions` and enter `DEPLOY`.

Hosting builds the Flutter web app. Functions deploy installs the dependencies in `functions/`. Neither Firestore rules nor indexes are deployed by this workflow.

## Rollback

For Hosting, redeploy a known-good commit or roll back from Firebase Hosting release history. For Functions, deploy a known-good commit. Keep the previous stable commit reference before each production deployment.
