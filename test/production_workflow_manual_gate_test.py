"""Read-only inventory of release and repository-mutation admission gates.

The repository's legacy production deploy workflows are protected byte-for-byte
by 116 SHA256 freeze pins. They contain KNOWN UNSAFE push-to-deploy triggers.
This characterization prevents *new* automatic deploy paths without changing
or hiding the two existing risks. It does not certify production readiness.
"""
from pathlib import Path
import hashlib
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
MANIFEST = ROOT / "docs" / "ROUTING_PDF_PROTECTED_2026-10-13.json"

PUBLISH = WORKFLOWS / "publish-authorized-release.yml"
RESTORE = WORKFLOWS / "restore-member-directory.yml"
OIDC = WORKFLOWS / "firebase-oidc-deploy.yml"
IMPORT = WORKFLOWS / "import-v3.0.1.yml"
SETUP = WORKFLOWS / "setup-source.yml"

# These two are NOT secure; they are documented production exposure until
# explicit release-governance authorization permits updating frozen files.
KNOWN_UNSAFE_AUTO_DEPLOY = {PUBLISH, RESTORE}


def _trigger(source):
    match = re.search(r"(?ms)^on:\s*\n(.*?)(?=^[a-z][a-z_-]*:\s*|\Z)",
                      source)
    if match is None:
        raise AssertionError("Top-level workflow 'on' block is missing")
    return match.group(1)


def _automatic(trigger):
    return bool(re.search(r"(?m)^\s{2}(?:push|pull_request)\s*:", trigger))


class ProductionWorkflowCharacterization(unittest.TestCase):
    def test_no_additional_automatic_production_deploy_workflows(self):
        # Explicit technical debt, NOT a claim that the known two are safe.
        for path in sorted(WORKFLOWS.glob("*.yml")):
            source = path.read_text(encoding="utf-8")
            if ("firebase deploy " not in source and
                    "node functions/backfill_member_directory.js" not in source):
                continue
            with self.subTest(workflow=path.name):
                if _automatic(_trigger(source)):
                    self.assertIn(
                        path, KNOWN_UNSAFE_AUTO_DEPLOY,
                        "NEW UNSAFE deployment trigger outside frozen exceptions",
                    )

    def test_frozen_deploy_workflow_byte_integrity(self):
        protected = json.loads(MANIFEST.read_text(encoding="utf-8"))[
            "protected_sha256"
        ]
        for path in sorted(KNOWN_UNSAFE_AUTO_DEPLOY):
            relative = str(path.relative_to(ROOT))
            with self.subTest(path=relative):
                self.assertIn(relative, protected)
                self.assertEqual(
                    hashlib.sha256(path.read_bytes()).hexdigest(),
                    protected[relative],
                    "Do not bypass freeze pins to fix deployment risk",
                )

    def test_legacy_risk_and_manual_oidc_are_expressly_characterized(self):
        # These checks prove the risky commands exist, not that they are safe.
        hosting = PUBLISH.read_text(encoding="utf-8")
        restore = RESTORE.read_text(encoding="utf-8")
        self.assertIn("firebase deploy --only hosting", hosting)
        self.assertIn("firebase deploy --only firestore:rules", restore)
        self.assertIn("firebase deploy --only functions:syncMemberDirectory",
                      restore)
        self.assertIn("node functions/backfill_member_directory.js", restore)
        for content in (hosting, restore):
            self.assertIn("environment: firebase-production", content)
            self.assertIn("id-token: write", content)
        oidc = OIDC.read_text(encoding="utf-8")
        self.assertRegex(_trigger(oidc),
                         r"(?m)^\s{2}workflow_dispatch\s*:")
        self.assertFalse(_automatic(_trigger(oidc)))
        self.assertIn("github.ref == 'refs/heads/main'", oidc)
        self.assertIn("inputs.confirm_production == 'DEPLOY'", oidc)
        self.assertIn("environment: firebase-production", oidc)

    def test_source_importers_are_manual_only_but_can_push_main(self):
        # These workflows have contents:write and git push. They are not a
        # direct Firebase deploy, but still merit separate release review.
        for path in (IMPORT, SETUP):
            with self.subTest(path=path.name):
                source = path.read_text(encoding="utf-8")
                trigger = _trigger(source)
                self.assertRegex(trigger, r"(?m)^\s{2}workflow_dispatch\s*:")
                self.assertFalse(_automatic(trigger))
                self.assertIn("contents: write", source)
                self.assertRegex(source, r"(?m)^\s*git push\s*$")
                self.assertIn(str(path.relative_to(ROOT)),
                              json.loads(MANIFEST.read_text(encoding="utf-8"))[
                                  "protected_sha256"
                              ])

    def test_no_auto_release_admission_via_repo_tests(self):
        # A future workflow may write to main without containing Firebase
        # commands; require any git-push actor to remain manual at minimum.
        for path in sorted(WORKFLOWS.glob("*.yml")):
            source = path.read_text(encoding="utf-8")
            if not re.search(r"(?m)^\s*git push(?:\s|$)", source):
                continue
            with self.subTest(path=path.name):
                self.assertFalse(
                    _automatic(_trigger(source)),
                    "Git push actor in automatic workflow needs separate review",
                )


if __name__ == "__main__":
    unittest.main()
