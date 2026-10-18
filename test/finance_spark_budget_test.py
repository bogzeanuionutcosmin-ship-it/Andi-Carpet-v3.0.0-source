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
        self.assertEqual(report['additional_reads_per_day_upper'], 3960)
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

    def test_single_target_can_overflow_even_when_total_storage_fits(self):
        report = budget.Scenario(40, existing_daily_reads=0, existing_daily_writes=0,
                                 existing_storage_bytes=0, busiest_target_receipts_per_day=20,
                                 current_target_document_bytes=4096).estimate()
        self.assertTrue(report['within_internal_reserve'])
        self.assertFalse(report['within_target_document_scenario'])
        self.assertEqual(report['target_full_days_within_internal_reserve'], 25)
        self.assertFalse(report['target_document_capacity_verified'])
        self.assertFalse(report['production_ready'])

    def test_unknown_target_distribution_is_never_reported_as_capacity_pass(self):
        report = budget.Scenario(40).estimate()
        self.assertFalse(report['target_document_scenario_known'])
        self.assertIsNone(report['within_target_document_scenario'])
        self.assertIsNone(report['target_document_estimate_bytes'])

    def test_multiyear_retention_is_not_silently_reset_each_year(self):
        one = budget.Scenario(200, days=365).estimate()
        five = budget.Scenario(200, days=365 * 5, existing_daily_reads=0,
                               existing_daily_writes=0, existing_storage_bytes=0).estimate()
        self.assertEqual(five['total_additional_storage_estimate_bytes'],
                         one['total_additional_storage_estimate_bytes'] * 5)
        self.assertFalse(five['within_internal_reserve'])

    def test_zero_growth_and_exact_capacity_boundary_are_explicit(self):
        for days, expected in [(25, True), (26, False)]:
            report = budget.Scenario(20, days=days, busiest_target_receipts_per_day=20,
                                     current_target_document_bytes=4096).estimate()
            self.assertEqual(report['within_target_document_scenario'], expected)
        report = budget.Scenario(0, busiest_target_receipts_per_day=0,
                                 current_target_document_bytes=4096).estimate()
        self.assertTrue(report['within_target_document_scenario'])
        self.assertIsNone(report['target_full_days_within_internal_reserve'])

    def test_invalid_baseline_or_target_concentration_fails_closed(self):
        for kwargs in [{'existing_daily_reads': -1}, {'existing_storage_bytes': True},
                       {'busiest_target_receipts_per_day': 2},
                       {'current_target_document_bytes': -1}, {'receipt_document_bytes': -1}]:
            with self.assertRaises(ValueError):
                budget.Scenario(1, **kwargs).estimate()

    def test_ui_refresh_cost_cannot_disappear_after_a_successful_marker_check(self):
        report = budget.Scenario(40, 40).estimate()
        self.assertEqual(report['confirmation_refresh_reads_per_day_upper'], 880)
        explicit = budget.Scenario(40, 40, confirmation_refreshes_per_day=3).estimate()
        self.assertEqual(explicit['confirmation_refresh_reads_per_day_upper'], 33)
        self.assertEqual(explicit['additional_reads_per_day_upper'], 3113)

    def test_invalid_refresh_counts_fail_closed(self):
        for value in [-1, True, 1.5]:
            with self.assertRaises(ValueError):
                budget.Scenario(1, confirmation_refreshes_per_day=value).estimate()

    def test_explicit_ledger_pages_include_rows_rules_and_first_page_target_read(self):
        report = budget.Scenario(0, ledger_first_pages_per_day=2, ledger_next_pages_per_day=3).estimate()
        self.assertEqual(report['ledger_document_and_rules_reads_per_day_upper'], 1122)
        self.assertEqual(report['additional_reads_per_day_upper'], 1122)
        self.assertEqual(report['additional_writes_per_day'], 0)
        self.assertFalse(report['ledger_index_reads_verified'])

    def test_ledger_page_and_frequency_limits_fail_closed(self):
        for kwargs in [{'ledger_page_size': 0}, {'ledger_page_size': 21},
                       {'ledger_page_size': True}, {'ledger_first_pages_per_day': -1},
                       {'ledger_next_pages_per_day': 1.5}]:
            with self.assertRaises(ValueError):
                budget.Scenario(0, **kwargs).estimate()

    def test_ledger_reads_can_exceed_daily_reserve_without_enabling_writes(self):
        report = budget.Scenario(0, ledger_first_pages_per_day=200, existing_daily_reads=0,
                                 existing_daily_writes=0, existing_storage_bytes=0).estimate()
        self.assertFalse(report['within_internal_reserve'])
        self.assertEqual(report['additional_writes_per_day'], 0)
        self.assertFalse(report['production_ready'])

    def test_malformed_primary_counts_cannot_produce_a_budget_certificate(self):
        fields = ['operations_per_day', 'reconciliations_per_day', 'attempts', 'days',
                  'marker_bytes_with_indexes', 'target_entry_bytes_with_indexes',
                  'receipt_document_bytes']
        for field in fields:
            for value in [True, False, 0.5, float('nan'), float('inf'), '1', None]:
                with self.subTest(field=field, value=value):
                    kwargs = {'operations_per_day': 1, field: value}
                    with self.assertRaises(ValueError):
                        budget.Scenario(**kwargs).estimate()

    def test_zero_retention_or_storage_assumptions_cannot_hide_active_growth(self):
        for field in ['days', 'marker_bytes_with_indexes',
                      'target_entry_bytes_with_indexes', 'receipt_document_bytes']:
            with self.subTest(field=field):
                with self.assertRaises(ValueError):
                    budget.Scenario(40, **{field: 0}, existing_daily_reads=0,
                                    existing_daily_writes=0, existing_storage_bytes=0).estimate()
        # An idle workload remains valid and does not invent financial writes.
        idle = budget.Scenario(0, reconciliations_per_day=0).estimate()
        self.assertEqual(idle['additional_writes_per_day'], 0)
        self.assertEqual(idle['total_additional_storage_estimate_bytes'], 0)
