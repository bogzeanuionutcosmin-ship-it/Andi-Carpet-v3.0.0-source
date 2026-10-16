#!/usr/bin/env python3
"""Offline release-evidence gate. No GitHub/Firebase/network access or side effects."""
import argparse
import json
import sys

REQUIRED = (
    "exact_sha_ci", "protected_hashes", "freeze_pins",
    "single_finance_authority", "legacy_client_server_gate",
    "journal_cross_process_cas", "journal_crash_durability",
    "uncertain_manual_reconciliation", "finance_writer_inventory",
    "vision_enum_only", "auth_epoch_revocation",
    "money_exactness", "history_bounded", "backup_restore_consistency",
    "staging_acl", "hardware_android", "hardware_ios",
    "hardware_windows", "quota_measured", "explicit_release_approval",
)
ALLOWED = frozenset(("pass", "blocked", "unknown", "fail"))


def evaluate(evidence):
    if not isinstance(evidence, dict):
        raise ValueError("evidence must be a JSON object")
    if set(evidence) != set(REQUIRED):
        raise ValueError("evidence keys must match the frozen release contract")
    for key, item in evidence.items():
        if not isinstance(item, dict) or set(item) != {"status", "reference"}:
            raise ValueError("invalid evidence object: " + key)
        if item["status"] not in ALLOWED:
            raise ValueError("invalid evidence status: " + key)
        if not isinstance(item["reference"], str):
            raise ValueError("invalid reference: " + key)
        if item["status"] == "pass" and not item["reference"].strip():
            raise ValueError("pass requires a verifiable reference: " + key)
    blockers = [key for key in REQUIRED if evidence[key]["status"] != "pass"]
    return {"production_ready": not blockers, "blockers": blockers,
            "passed": len(REQUIRED) - len(blockers), "total": len(REQUIRED)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", help="JSON evidence file; offline only")
    args = parser.parse_args(argv)
    try:
        with open(args.evidence, encoding="utf-8") as handle:
            report = evaluate(json.load(handle))
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as error:
        print("INVALID EVIDENCE: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, sort_keys=True, indent=2))
    return 0 if report["production_ready"] else 1


if __name__ == "__main__":
    sys.exit(main())
