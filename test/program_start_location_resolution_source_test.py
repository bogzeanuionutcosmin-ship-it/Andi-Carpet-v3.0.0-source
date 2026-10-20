import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProgramStartLocationResolutionSourceContract(unittest.TestCase):
    def test_program_page_delegates_endpoint_resolution(self):
        page = (ROOT / "lib/schedule/program_page.dart").read_text(encoding="utf-8")
        self.assertIn("resolveProgramStartLocations(", page)
        self.assertIn("geocode:_geocodeTripPoint", page)
        self.assertNotIn("departureText.toLowerCase()==returnText.toLowerCase()", page)

    def test_resolver_is_registered_as_a_program_part(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        resolver = (ROOT / "lib/schedule/program_start_location_resolution.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(
            main.count("part 'schedule/program_start_location_resolution.dart';"), 1
        )
        self.assertIn("Future<ProgramStartLocations?> resolveProgramStartLocations(", resolver)
        self.assertIn("departurePoint = await geocode(departure)", resolver)


if __name__ == "__main__":
    unittest.main()
