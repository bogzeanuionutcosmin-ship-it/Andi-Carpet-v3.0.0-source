import json
import unittest
from pathlib import Path
from pr_collision_guard import analyze


def pr(number, path, sha="a" * 40):
    return {"number": number, "head_sha": sha, "files": path}


class CollisionGuardTests(unittest.TestCase):
    def test_overlap_detected(self):
        result = analyze({"prs": [pr(99, ["firestore.rules", "a"]), pr(100, ["firestore.rules", "b"])]})
        self.assertEqual(result["overlap_count"], 1)
        self.assertEqual(result["overlap_pairs"][0]["shared_files"], ["firestore.rules"])
        self.assertFalse(result["integration_approved"])

    def test_disjoint(self):
        self.assertEqual(analyze({"prs": [pr(103, ["a"]), pr(104, ["b"])]})["overlap_count"], 0)

    def test_duplicate_pr_rejected(self):
        with self.assertRaises(ValueError):
            analyze({"prs": [pr(99, ["a"]), pr(99, ["b"])]})

    def test_invalid_sha_rejected(self):
        with self.assertRaises(ValueError):
            analyze({"prs": [pr(99, ["a"], "not-a-sha")]})

    def test_invalid_file_list_rejected(self):
        with self.assertRaises(ValueError):
            analyze({"prs": [pr(99, [None])]})

    def test_recorded_github_snapshot_has_five_collision_pairs(self):
        fixture = Path(__file__).resolve().parents[2] / "docs" / "independent" / "pr_collision_snapshot_20261018.json"
        result = analyze(json.loads(fixture.read_text(encoding="utf-8")))
        self.assertEqual(result["overlap_count"], 5)
        self.assertTrue(any(pair["prs"] == [99, 100] and pair["shared_count"] == 25
                            for pair in result["overlap_pairs"]))
        self.assertFalse(result["integration_approved"])

    def test_empty_snapshot(self):
        self.assertFalse(analyze({"prs": []})["integration_approved"])


if __name__ == "__main__":
    unittest.main()
