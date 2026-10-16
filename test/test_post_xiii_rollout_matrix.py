"""Review-only version gate for legacy and V2 financial writes.

The production V1 writer gate remains unimplemented.
"""
import unittest


def accept_write(client_protocol, server_mode, has_receipt, has_permit,
                 has_current_signed_epoch):
    if server_mode != "exclusive_v2":
        return False
    return (type(client_protocol) is int and client_protocol == 2
            and has_receipt is True and has_permit is True
            and has_current_signed_epoch is True)


class ExclusiveVersionGateTest(unittest.TestCase):
    def test_old_apk_cannot_write_after_exclusive_gate(self):
        for protocol in (None, 0, 1, "2", True):
            self.assertFalse(accept_write(protocol, "exclusive_v2",
                                          True, True, True))

    def test_partial_three_document_write_rejected(self):
        for receipt, permit in ((False, True), (True, False), (False, False)):
            self.assertFalse(accept_write(2, "exclusive_v2",
                                          receipt, permit, True))

    def test_signed_current_epoch_required(self):
        self.assertFalse(accept_write(2, "exclusive_v2", True, True, False))

    def test_nonexclusive_mode_cannot_claim_safety(self):
        self.assertFalse(accept_write(2, "legacy_or_v2", True, True, True))

    def test_full_synthetic_contract_passes(self):
        self.assertTrue(accept_write(2, "exclusive_v2", True, True, True))


if __name__ == "__main__":
    unittest.main()
