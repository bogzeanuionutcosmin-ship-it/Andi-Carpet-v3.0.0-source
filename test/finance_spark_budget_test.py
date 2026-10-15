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
