"""Static upper-bound model; never reads Firebase or enables billing."""
from dataclasses import dataclass
import json


@dataclass(frozen=True)
class Scenario:
    operations_per_day: int
    reconciliations_per_day: int = 0
    attempts: int = 3
    days: int = 365
    marker_bytes_with_indexes: int = 2048
    # Conservative scenario assumes every operation also appends a receipt.
    # Both byte inputs are assumptions, NOT measured maximums.
    target_entry_bytes_with_indexes: int = 1024
    # UNKNOWN usage cannot produce a production readiness result.
    existing_daily_reads: int | None = None
    existing_daily_writes: int | None = None
    existing_storage_bytes: int | None = None
    # Separate single-document scenario: index bytes do not occupy the target
    # document. Unknown concentration/current size must stay unknown.
    busiest_target_receipts_per_day: int | None = None
    current_target_document_bytes: int | None = None
    receipt_document_bytes: int = 1024
    # Each successful UI completion also reads the authoritative target.
    # Unknown count conservatively allows one after every operation/check.
    confirmation_refreshes_per_day: int | None = None

    def estimate(self):
        if min(self.operations_per_day, self.reconciliations_per_day, self.days,
               self.marker_bytes_with_indexes, self.target_entry_bytes_with_indexes,
               self.receipt_document_bytes) < 0 or not 1 <= self.attempts <= 3:
            raise ValueError('Invalid scenario or unbounded transaction attempts')
        optional = [self.existing_daily_reads, self.existing_daily_writes,
                    self.existing_storage_bytes, self.busiest_target_receipts_per_day,
                    self.current_target_document_bytes, self.confirmation_refreshes_per_day]
        if any(v is not None and (not isinstance(v, int) or isinstance(v, bool) or v < 0)
               for v in optional):
            raise ValueError('Invalid baseline or target concentration')
        if self.busiest_target_receipts_per_day is not None and self.busiest_target_receipts_per_day > self.operations_per_day:
            raise ValueError('Target receipts cannot exceed total operations')
        # 2 client document reads and worst-case 20 rules access calls per
        # transaction attempt. No assumption that repeated accesses are cached.
        reads = self.operations_per_day * self.attempts * 22 + self.reconciliations_per_day * 11
        refreshes = self.confirmation_refreshes_per_day
        if refreshes is None:
            refreshes = self.operations_per_day + self.reconciliations_per_day
        # One server document read plus up to ten rules access calls per read.
        refresh_reads = refreshes * 11
        reads += refresh_reads
        writes = self.operations_per_day * 2
        storage = self.operations_per_day * self.days * self.marker_bytes_with_indexes
        history_storage = self.operations_per_day * self.days * self.target_entry_bytes_with_indexes
        total_storage = storage + history_storage
        target_known = self.busiest_target_receipts_per_day is not None and self.current_target_document_bytes is not None
        target_bytes = None
        target_fits = None
        target_days = None
        # Internal 512 KiB scenario reserve, not a measured SDK size or new
        # financial limit. Actual Firestore document limit is 1 MiB.
        if target_known:
            growth = self.busiest_target_receipts_per_day * self.receipt_document_bytes
            target_bytes = self.current_target_document_bytes + growth * self.days
            target_fits = target_bytes <= 512 * 1024
            if growth > 0:
                target_days = max(0, (512 * 1024 - self.current_target_document_bytes) // growth)
        known = all(v is not None and v >= 0 for v in [self.existing_daily_reads,
                    self.existing_daily_writes, self.existing_storage_bytes])
        fits = known and reads + self.existing_daily_reads <= 25000 and \
            writes + self.existing_daily_writes <= 10000 and \
            total_storage + self.existing_storage_bytes <= 256 * 1024**2
        return dict(additional_reads_per_day_upper=reads, additional_writes_per_day=writes,
                    confirmation_refresh_reads_per_day_upper=refresh_reads,
                    marker_storage_upper_bytes=storage,
                    target_history_storage_estimate_bytes=history_storage,
                    total_additional_storage_estimate_bytes=total_storage,
                    storage_is_assumption_not_measured_bound=True,
                    target_document_capacity_verified=False, egress_verified=False,
                    target_document_scenario_known=target_known,
                    target_document_estimate_bytes=target_bytes,
                    within_target_document_scenario=target_fits,
                    target_full_days_within_internal_reserve=target_days,
                    new_deletes=0, new_listeners=0,
                    new_polling=0, usage_known=known, within_internal_reserve=bool(fits),
                    production_ready=False)


if __name__ == '__main__':
    print(json.dumps({str(n): Scenario(n, n).estimate() for n in [40, 200, 1000]}, indent=2))
