import importlib.util
from pathlib import Path
import sys
import unittest

spec = importlib.util.spec_from_file_location('spark_budget', Path(__file__).resolve().parents[1] / 'scripts/finance_spark_budget.py')
budget = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = budget
spec.loader.exec_module(budget)


class SparkBudgetTest(unittest.TestCase):
    def test_two_teams_with_twenty_daily_intents_include_rules_and_reconciliation(self):
        report = budget.Scenario(40, 40).estimate()
        self.assertEqual(report['additional_reads_per_day_upper'], 3080)
        self.assertEqual(report['additional_writes_per_day'], 80)
        self.assertEqual(report['marker_storage_upper_bytes'], 29900800)

    def test_receipt_history_growth_is_included_in_reserve(self):
        report = budget.Scenario(40, 40).estimate()
        self.assertEqual(report['target_history_storage_estimate_bytes'], 14950400)
        self.assertEqual(report['total_additional_storage_estimate_bytes'], 44851200)
        self.assertTrue(report['storage_is_assumption_not_measured_bound'])
        self.assertFalse(report['target_document_capacity_verified'])
        self.assertFalse(report['egress_verified'])

    def test_marker_only_fit_does_not_hide_large_history_growth(self):
        report = budget.Scenario(300, existing_daily_reads=0, existing_daily_writes=0,
                                 existing_storage_bytes=0).estimate()
        self.assertLess(report['marker_storage_upper_bytes'], 256 * 1024**2)
        self.assertGreater(report['total_additional_storage_estimate_bytes'], 256 * 1024**2)
        self.assertFalse(report['within_internal_reserve'])

    def test_negative_history_size_assumption_is_rejected(self):
        with self.assertRaises(ValueError):
            budget.Scenario(1, target_entry_bytes_with_indexes=-1).estimate()

    def test_unknown_usage_fails_closed(self):
        self.assertFalse(budget.Scenario(1).estimate()['within_internal_reserve'])

    def test_known_small_baseline_fits_conservative_reserve(self):
        report = budget.Scenario(40, existing_daily_reads=1000, existing_daily_writes=100,
                                 existing_storage_bytes=1000).estimate()
        self.assertTrue(report['within_internal_reserve'])
        self.assertFalse(report['production_ready'])

    def test_high_rate_exceeds_reserve(self):
        report = budget.Scenario(1000, existing_daily_reads=0, existing_daily_writes=0,
                                 existing_storage_bytes=0).estimate()
        self.assertFalse(report['within_internal_reserve'])

    def test_unbounded_retry_is_rejected(self):
        with self.assertRaises(ValueError):
            budget.Scenario(1, attempts=4).estimate()

    def test_negative_rate_is_rejected(self):
        with self.assertRaises(ValueError):
            budget.Scenario(-1).estimate()

    def test_no_cleanup_listener_or_polling_is_assumed(self):
        report = budget.Scenario(40).estimate()
        for key in ['new_deletes', 'new_listeners', 'new_polling']:
            self.assertEqual(report[key], 0)
