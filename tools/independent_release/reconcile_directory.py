#!/usr/bin/env python3
"""Offline synthetic directory reconciliation. Never connects to Firebase."""
import argparse
import json
from pathlib import Path

FIELDS = ("name", "nickname", "useNickname", "function", "functionIds", "teamId",
          "active", "role", "photoBase64", "phone", "city", "county", "contractFunction")


def project_member(profile):
    if profile is None or profile.get("hiddenFromMembers") is True or profile.get("role") == "admin":
        return None
    projected = {key: profile[key] for key in FIELDS if key in profile}
    projected["active"] = profile.get("active") is True
    projected["role"] = "member"
    return projected


def reconcile(users, directory):
    if not isinstance(users, dict) or not isinstance(directory, dict):
        raise ValueError("users and directory must be JSON objects keyed by synthetic IDs")
    if any(not isinstance(uid, str) or not isinstance(profile, dict) for uid, profile in users.items()):
        raise ValueError("Every user must have a string ID and an object profile")
    if any(not isinstance(uid, str) or not isinstance(profile, dict) for uid, profile in directory.items()):
        raise ValueError("Every directory entry must have a string ID and an object value")
    expected = {uid: value for uid, profile in users.items()
                if (value := project_member(profile)) is not None}
    source_ids, actual_ids = set(expected), set(directory)
    changed = sorted(uid for uid in source_ids & actual_ids if expected[uid] != directory[uid])
    return {"eligible": len(expected), "missing": sorted(source_ids - actual_ids),
            "extra": sorted(actual_ids - source_ids), "changed": changed,
            "identical": len(source_ids & actual_ids) - len(changed),
            "matches": not (source_ids ^ actual_ids) and not changed}


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key in directory fixture")
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", type=Path, help="Synthetic JSON with users and memberDirectory objects")
    args = parser.parse_args()
    try:
        data = json.loads(args.fixture.read_text(encoding="utf-8"), object_pairs_hook=_unique_keys)
        result = reconcile(data["users"], data["memberDirectory"])
    except (OSError, ValueError, KeyError, TypeError, AttributeError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc), "matches": False}))
        return 3
    print(json.dumps(result, indent=2))
    return 0 if result["matches"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
