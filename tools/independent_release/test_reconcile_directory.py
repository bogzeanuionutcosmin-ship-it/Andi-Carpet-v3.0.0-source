import unittest
from reconcile_directory import project_member, reconcile


class DirectoryReconciliationTests(unittest.TestCase):
    def test_hidden_and_admin_excluded(self):
        self.assertIsNone(project_member({"hiddenFromMembers": True, "name": "H"}))
        self.assertIsNone(project_member({"role": "admin", "name": "A"}))

    def test_inactive_member_is_projected(self):
        self.assertEqual(project_member({"name": "M", "active": False}),
                         {"name": "M", "active": False, "role": "member"})

    def test_clean_directory(self):
        users = {"one": {"name": "One", "active": True}, "hidden": {"hiddenFromMembers": True}}
        directory = {"one": {"name": "One", "active": True, "role": "member"}}
        self.assertTrue(reconcile(users, directory)["matches"])

    def test_missing_extra_changed(self):
        users = {"one": {"name": "One"}, "two": {"name": "Two"}, "hidden": {"role": "admin"}}
        directory = {"one": {"name": "Old"}, "hidden": {"name": "Admin"}}
        result = reconcile(users, directory)
        self.assertEqual(result["missing"], ["two"])
        self.assertEqual(result["extra"], ["hidden"])
        self.assertEqual(result["changed"], ["one"])
        self.assertFalse(result["matches"])


if __name__ == "__main__":
    unittest.main()
