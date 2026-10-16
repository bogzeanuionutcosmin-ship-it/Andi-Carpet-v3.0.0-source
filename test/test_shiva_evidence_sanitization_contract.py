"""Offline Shiva acceptance test for evidence_sanitization; not a runtime proof."""
import unittest

SENSITIVE=("uid","amount","token","operation_id")
def safe_metadata(meta):
    if type(meta) is not dict: return None
    if any(k in meta for k in SENSITIVE): return None
    if set(meta)!={"gate","status"}: return None
    return meta if meta["status"] in ("pass","blocked","unknown","fail") else None

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertEqual(safe_metadata({"gate":"ci","status":"blocked"}),{"gate":"ci","status":"blocked"})
        self.assertIsNone(safe_metadata({"gate":"ci","status":"pass","uid":"A"}))
        self.assertIsNone(safe_metadata({"gate":"ci","status":"maybe"}))

if __name__ == "__main__":
    unittest.main()
