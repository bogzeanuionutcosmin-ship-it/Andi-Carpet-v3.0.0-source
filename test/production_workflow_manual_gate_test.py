"""Prevent accidental production deploys from normal source pushes.

Scope: GitHub Actions source-level deployment admission. Passing this test
does not authorize an actual deploy, prove GitHub environment protections are
configured, or certify production Firebase/Google Cloud IAM settings.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"

PUBLISH = WORKFLOWS / "publish-authorized-release.yml"
RESTORE = WORKFLOWS / "restore-member-directory.yml"
OIDC = WORKFLOWS / "firebase-oidc-deploy.yml"

EXPECTED = {
    PUBLISH: ("DEPLOY_HOSTING", "hosting"),
    RESTORE: ("RESTORE_MEMBER_DIRECTORY", "restore"),
}


def _trigger(source: str) -> str:
    """Extract top-level trigger section, not a step name or comment."""
    match = re.search(r"(?ms)^on:\s*\n(.*?)(?=^[a-z][a-z_-]*:\s*|\Z)",
                      source)
    if match is None:
        raise AssertionError("No top-level GitHub Actions 'on' trigger")
    return match.group(1)


class ProductionWorkflowAdmission(unittest.TestCase):
    def test_no_automatic_production_deploy_on_main_push(self):
        # Include future workflow files too: a new push-triggered deployment
        # must fail before anyone considers merging its Draft PR.
        for workflow in sorted(WORKFLOWS.glob("*.yml")):
            content = workflow.read_text(encoding="utf-8")
            if ("firebase deploy " not in content and
                    "node functions/backfill_member_directory.js" not in content):
                continue
            with self.subTest(workflow=workflow.name):
                triggers = _trigger(content)
                self.assertNotRegex(triggers, r"(?m)^\s{2}push\s*:",
                                    "Production-capable workflows cannot deploy on push")
                self.assertNotRegex(triggers, r"(?m)^\s{2}pull_request\s*:",
                                    "A PR must never trigger a production deploy")

    def test_production_operators_require_manual_main_and_exact_confirmation(self):
        for workflow, (phrase, job) in EXPECTED.items():
            content = workflow.read_text(encoding="utf-8")
            with self.subTest(workflow=workflow.name):
                triggers = _trigger(content)
                self.assertRegex(triggers, r"(?m)^\s{2}workflow_dispatch\s*:")
                self.assertIn("confirm_production:", triggers)
                self.assertIn("required: true", triggers)
                self.assertIn("type: string", triggers)
                self.assertIn(f"inputs.confirm_production == '{phrase}'",
                              content)
                self.assertIn("github.event_name == 'workflow_dispatch'",
                              content)
                self.assertIn("github.ref == 'refs/heads/main'", content)
                # Scope the gate to the job that can actually deploy.
                job_section = content.split(f"  {job}:\n", 1)[1]
                before_steps = job_section.split("    steps:", 1)[0]
                self.assertIn("    if:", before_steps)
                self.assertIn(f"inputs.confirm_production == '{phrase}'",
                              before_steps)
                self.assertIn("environment: firebase-production", before_steps)

    def test_existing_deploy_operations_remain_manual_reviewable(self):
        hosting = PUBLISH.read_text(encoding="utf-8")
        restore = RESTORE.read_text(encoding="utf-8")
        self.assertIn("firebase deploy --only hosting", hosting)
        for command in (
            "firebase deploy --only firestore:rules",
            "firebase deploy --only functions:syncMemberDirectory",
            "node functions/backfill_member_directory.js",
        ):
            self.assertIn(command, restore)
        # Source hardening is not permission to run these commands in CI.
        self.assertIn("id-token: write", hosting)
        self.assertIn("id-token: write", restore)

    def test_oidc_manual_deploy_gate_must_remain_protected(self):
        content = OIDC.read_text(encoding="utf-8")
        triggers = _trigger(content)
        self.assertRegex(triggers, r"(?m)^\s{2}workflow_dispatch\s*:")
        self.assertNotRegex(triggers, r"(?m)^\s{2}push\s*:")
        self.assertIn("github.ref == 'refs/heads/main'", content)
        self.assertIn("inputs.confirm_production == 'DEPLOY'", content)
        self.assertIn("environment: firebase-production", content)


if __name__ == "__main__":
    unittest.main()
