# Refuse a receipt whose positive increment disappears

IEEE double arithmetic can satisfy1e20 +1 ==1e20. A finite/positive receipt and
finite aggregate are therefore insufficient: the prototype could append an entry
without increasing the selected aggregate.

The pure transition and emulator Rules now additionally require the selected
aggregate to increase. An unrepresentable increment is refused before client writes;
there is no rounding, money cap, fabricated transfer, rollback or financial retry.
The server enforces the same property for clients bypassing the repository.

One deterministic Dart case and one real emulator denial check the pathological
snapshot and require unchanged history/no writes. Existing ordinary and fractional
receipt controls remain. This guard addresses a disappearing increment only; it
does not certify all floating point arithmetic or replace the remaining numeric
representation/capacity review for production.

Rules pin:a59b0a27d5e58b2e7e3c9e4936addeeff52c71dce29901e340795842b8060cf4
->19ae6d121e2ef13272c368aed0df9c27b485af9c99ec3f6ef9159f15a92ae193.
All other115 protected manifest entries remain unchanged. Actual CI required.

Follow-up profile compatibility: effective-permission managers no longer construct
a legacy function-definition path when that optional field is absent. A null
optional functionIds list is handled without losing role/function Director checks.
Two emulator controls cover these profiles, retaining empty-permission denial
and legacy fallback tests. Final combined rules pin 4b744fd1ce9826041513e680affbdbdc2713deb9d87e1cf5677ea1bfc50833e7.
