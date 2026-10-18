import unittest
from verify_ci_suite_union import inspect, REQUIRED


class SuiteUnionTests(unittest.TestCase):
    def test_all_suites_in_one_command(self):
        command = "run: npx firebase emulators:exec --only firestore 'node --test " + " ".join(REQUIRED) + "'"
        result = inspect(command)
        self.assertEqual(result["status"], "REVIEW")
        self.assertFalse(result["certified"])

    def test_finance_missing(self):
        command = "run: npx firebase emulators:exec 'node --test " + " ".join(REQUIRED[:-1]) + "'"
        self.assertEqual(inspect(command)["missing"], [REQUIRED[-1]])

    def test_split_commands_do_not_count(self):
        commands = "\n".join("run: firebase emulators:exec 'node --test " + x + "'" for x in REQUIRED)
        self.assertEqual(inspect(commands)["status"], "BLOCK")

    def test_comment_is_not_command(self):
        command = "# firebase emulators:exec 'node --test " + " ".join(REQUIRED) + "'"
        self.assertEqual(inspect(command)["status"], "BLOCK")

    def test_no_command(self):
        self.assertEqual(inspect("name: empty")["status"], "BLOCK")


if __name__ == "__main__":
    unittest.main()
