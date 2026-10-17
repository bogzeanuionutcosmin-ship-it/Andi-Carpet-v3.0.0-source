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

    def test_invalid_user_profile_is_rejected(self):
        with self.assertRaises(ValueError):
            reconcile({"one": None}, {})

    def test_invalid_directory_entry_is_rejected(self):
        with self.assertRaises(ValueError):
            reconcile({}, {"one": None})

    def test_missing_extra_changed(self):
        users = {"one": {"name": "One"}, "two": {"name": "Two"}, "hidden": {"role": "admin"}}
        directory = {"one": {"name": "Old"}, "hidden": {"name": "Admin"}}
        result = reconcile(users, directory)
        self.assertEqual(result["missing"], ["two"])
        self.assertEqual(result["extra"], ["hidden"])
        self.assertEqual(result["changed"], ["one"])
        self.assertFalse(result["matches"])


    def test_duplicate_fixture_keys_rejected(self):
        import json
        from reconcile_directory import _unique_keys
        with self.assertRaises(ValueError):
            json.loads('{"users":{},"users":{}}', object_pairs_hook=_unique_keys)

    def test_private_fields_are_not_projected(self):
        profile = {"name": "Synthetic", "active": True, "email": "private@example.invalid",
                   "passwordHash": "not-real", "permissions": ["admin"]}
        result = project_member(profile)
        self.assertEqual(result, {"name": "Synthetic", "active": True, "role": "member"})

    def test_mismatch_output_contains_only_ids(self):
        result = reconcile({"synthetic-1": {"name": "Sensitive Synthetic Name"}},
                           {"synthetic-1": {"name": "Outdated Synthetic Name"}})
        self.assertEqual(result["changed"], ["synthetic-1"])
        self.assertNotIn("Sensitive Synthetic Name", str(result))
        self.assertNotIn("Outdated Synthetic Name", str(result))

if __name__ == "__main__":
    unittest.main()
