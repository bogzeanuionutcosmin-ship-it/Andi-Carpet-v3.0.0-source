"""Offline Shiva acceptance test for backup_manifest; not a runtime proof."""
import unittest

def valid_manifest(m):
    return (type(m) is dict and set(m)=={"schema","uid","team","digest"}
            and m["schema"]==2 and all(type(m[k]) is str and bool(m[k]) for k in ("uid","team","digest")))

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertTrue(valid_manifest({"schema":2,"uid":"A","team":"T","digest":"d"}))
        self.assertFalse(valid_manifest({"schema":1,"uid":"A","team":"T","digest":"d"}))
        self.assertFalse(valid_manifest({"schema":2,"uid":"A","team":"T","digest":"d","token":"secret"}))

if __name__ == "__main__":
    unittest.main()
