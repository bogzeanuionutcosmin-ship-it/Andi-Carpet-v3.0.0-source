"""Offline Shiva acceptance test for offline_queue; not a runtime proof."""
import unittest

def may_autosend(state):
    return state=="new_authorized" and type(state) is str
def recovery(state):
    return "manual" if state in ("uncertain","prepared","sent") else "blocked"

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertFalse(may_autosend("uncertain"))
        self.assertFalse(may_autosend("prepared"))
        self.assertTrue(may_autosend("new_authorized"))
        self.assertEqual(recovery("uncertain"),"manual")

if __name__ == "__main__":
    unittest.main()
