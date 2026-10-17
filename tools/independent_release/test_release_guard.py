import tempfile
import unittest
from pathlib import Path
from release_guard import inspect


class ReleaseGuardTest(unittest.TestCase):
    def fixture(self, workflow, gradle, backfill):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        for name, content in {".github/workflows/restore-member-directory.yml": workflow, "android/app/build.gradle.kts": gradle, "functions/backfill_member_directory.js": backfill}.items():
            file = root / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(content)
        return {x["id"]: x["status"] for x in inspect(root)}

    def test_main_risks_blocked(self):
        f = self.fixture("on:\n  push:\n    branches: [main]\njobs:\n  deploy:\n    steps:\n      - run: firebase deploy --only firestore:rules\n", 'release {\n signingConfig = signingConfigs.getByName("debug")\n}\n}', "initializeApp({ projectId: 'andicarpet-e777e' });")
        self.assertEqual(list(f.values()), ["BLOCK", "BLOCK", "BLOCK"])

    def test_manual_candidate_not_auto(self):
        f = self.fixture("on:\n  workflow_dispatch:\njobs:\n  deploy:\n    steps:\n      - run: firebase deploy --only firestore:rules\n", 'release {\n signingConfig = signingConfigs.getByName("release")\n}\n}', "initializeApp({ projectId: process.env.STAGING_PROJECT });")
        self.assertEqual(list(f.values()), ["REVIEW", "REVIEW", "REVIEW"])

    def test_missing_files_unknown(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual([x["status"] for x in inspect(Path(t))], ["UNKNOWN"] * 3)

    def test_comments_not_triggers(self):
        f = self.fixture("on:\n  workflow_dispatch:\n# push: disabled\njobs:\n  deploy:\n    steps:\n      - run: firebase deploy\n", "", "")
        self.assertEqual(f["PRODUCTION_AUTO_DEPLOY"], "REVIEW")


if __name__ == "__main__":
    unittest.main()
