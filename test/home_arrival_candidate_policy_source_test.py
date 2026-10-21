import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class HomeArrivalCandidatePolicySourceContract(unittest.TestCase):
    def test_home_delegates_radius_and_nearest_candidate_selection(self):
        page = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        self.assertIn("nearestEligibleHomeArrivalCandidate<", page)
        self.assertNotIn("meters + p.accuracy <= 250", page)
        self.assertNotIn("candidates.sort((a, b) => a.$3.compareTo(b.$3))", page)

    def test_candidate_policy_is_registered_and_owns_the_boundary(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        policy = (ROOT / "lib/home/home_arrival_candidate_policy.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(
            main.count("part 'home/home_arrival_candidate_policy.dart';"), 1
        )
        self.assertIn("nearestEligibleHomeArrivalCandidate", policy)
        self.assertIn("candidate.meters + accuracyMeters <= radiusMeters", policy)


if __name__ == "__main__":
    unittest.main()
