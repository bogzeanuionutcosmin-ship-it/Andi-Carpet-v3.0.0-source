"""Fail closed when native emulator evidence is missing or incomplete.

Run after scripts/run_xix_native.sh; no production backend access.
"""
import json
from pathlib import Path


def verify(root: Path) -> None:
    pdf = root / "native-flow.pdf"
    observations = root / "observations.json"
    if not pdf.is_file() or not observations.is_file():
        raise AssertionError("Native PDF and observations are both required")
    data = pdf.read_bytes()
    if not data.startswith(b"%PDF-") or b"%%EOF" not in data[-1024:]:
        raise AssertionError("Native output is not a complete PDF")
    result = json.loads(observations.read_text(encoding="utf-8"))
    if not isinstance(result, dict) or result.get("completed") is not True:
        raise AssertionError("Native scenario did not reach its completion marker")

    required = (
        "connectedFlow", "sameAttemptRetry", "twoNativeClients",
        "unauthorizedTeam", "legacyAndDeletion", "offlineBeforeStart",
        "revokedProfile", "restore", "pdf",
    )
    missing = [key for key in required if key not in result]
    if missing:
        raise AssertionError(f"Missing native assertions: {missing}")

    connected = result["connectedFlow"]
    if not isinstance(connected, dict):
        raise AssertionError("Connected flow evidence must be an object")
    if connected.get("expected") != "one completed record after double taps and server reload":
        raise AssertionError("Connected flow did not declare its expected server-reload assertion")
    if type(connected.get("observed")) is not int or connected["observed"] != 1:
        raise AssertionError("Connected flow did not persist exactly one record")
    if not isinstance(connected.get("id"), str) or not connected["id"].strip():
        raise AssertionError("Connected flow is missing the persisted record ID")

    if result["sameAttemptRetry"] != "one document, identical payload accepted":
        raise AssertionError("Same-attempt retry evidence was not demonstrated")

    race = result["twoNativeClients"]
    accepted = race.get("accepted") if isinstance(race, dict) else None
    if (
        not isinstance(accepted, list)
        or len(accepted) != 2
        or any(type(value) is not bool for value in accepted)
        or sum(accepted) != 1
    ):
        raise AssertionError("Cross-client CAS did not select exactly one boolean winner")
    if race.get("loser") != "StateError stale baseline":
        raise AssertionError("Cross-client stale-baseline rejection was not demonstrated")
    if race.get("serverWinner") != f"race-{accepted.index(True)}":
        raise AssertionError("Cross-client server winner does not match the accepted client")
    if type(race.get("documentCount")) is not int or race["documentCount"] < 1:
        raise AssertionError("Cross-client document count is missing or invalid")

    if result["unauthorizedTeam"] != "permission-denied":
        raise AssertionError("Unauthorized team write was not denied")
    if result["legacyAndDeletion"] != "legacy update passed; deleted baseline rejected":
        raise AssertionError("Legacy update and deleted-document rejection were not demonstrated")
    if result["offlineBeforeStart"] != "native transaction rejected; reconnect has no queued record":
        raise AssertionError("Offline fail-closed write was not demonstrated")
    if result["revokedProfile"] != "cached Auth identity cannot write after server profile deactivation":
        raise AssertionError("Revoked profile rejection was not demonstrated")
    if result["restore"] != "admin complete/repeat passed; readable inventory followed by denied mixed batch rolled back allowed update and deletions; oversized restore changed no records":
        raise AssertionError("Atomic restore rollback evidence was not demonstrated")
    if result["pdf"] != "real builder with data reloaded from native Firestore; missing registry retained":
        raise AssertionError("Native Firestore data was not shown in the generated PDF")


if __name__ == "__main__":
    verify(Path("xix-evidence"))
    print("Native PDF and completed scenario evidence: PASS")
