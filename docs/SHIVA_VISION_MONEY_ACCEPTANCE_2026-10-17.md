# Shiva review contract additions: Vision privacy and monetary precision

The standalone `test_shiva_vision_privacy_contract.py` models a strictly enumerated diagnostic sink. It deliberately discards unknown strings, raw exceptions and private context (UID, operation ID, amount). It does **not** establish that the actual Vision integration uses this sink; source-level mapping and real Flutter tests remain required.

The standalone `test_shiva_money_precision_contract.py` models exact decimal-string-to-minor-unit conversion. It rejects binary floats, non-finite numbers and sub-cent values; verifies `0.10 + 0.20 + 0.30 = 60` minor units and large integers above the IEEE-754 exact range. This is a proposed compatibility acceptance criterion, **not** a migration of existing financial data. Existing XI floating-point historical records remain blocked until a separately approved and tested conversion policy exists.

Neither model accesses SDKs, Firebase, production data or protected app sources. The release gate remains `production_ready=false`. Native financial durability belongs to Luna Misiunea XIII; Shiva's branch remains a review-only acceptance suite.
