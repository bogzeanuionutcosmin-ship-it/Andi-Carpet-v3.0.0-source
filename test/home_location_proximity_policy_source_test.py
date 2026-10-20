import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class HomeLocationProximityPolicySourceContract(unittest.TestCase):
    def test_home_delegates_precision_hysteresis_decision(self):
        page = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        self.assertIn("homeLocationProximityAction(", page)
        self.assertNotIn("nearest <= 3000", page)
        self.assertNotIn("nearest > 5000", page)
        self.assertIn("_startNativeBackgroundLocationStream()", page)

    def test_policy_is_registered_as_a_home_part(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        policy = (ROOT / "lib/home/home_location_proximity_policy.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(
            main.count("part 'home/home_location_proximity_policy.dart';"), 1
        )
        self.assertIn("enum HomeLocationProximityAction", policy)
        self.assertIn("nearestMeters <= 3000", policy)
        self.assertIn("nearestMeters > 5000", policy)


if __name__ == "__main__":
    unittest.main()
