"""Evidence classification: process kill is not a hardware power-cut proof."""
import unittest


def evidence_level(platform, failure):
    if platform in ("Linux", "Windows", "macOS") and failure == "process_kill":
        return "host_process_only"
    if platform in ("Android", "iOS") and failure == "hardware_power_cut":
        return "requires_device_measurement"
    return "unproven"


class PowerLossClaimsTest(unittest.TestCase):
    def test_host_sigkill_not_power_loss(self):
        for platform in ("Linux", "Windows", "macOS"):
            self.assertEqual(evidence_level(platform, "process_kill"), "host_process_only")

    def test_mobile_power_loss_requires_measurement(self):
        for platform in ("Android", "iOS"):
            self.assertEqual(evidence_level(platform, "hardware_power_cut"),
                             "requires_device_measurement")

    def test_unknown_probes_are_unproven(self):
        self.assertEqual(evidence_level("Android", "process_kill"), "unproven")


if __name__ == "__main__":
    unittest.main()
