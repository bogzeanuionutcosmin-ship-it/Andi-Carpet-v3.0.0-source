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

    if result.get("graphCreatedThroughUi") is not True:
        raise AssertionError("Graph creation through UI and server reload were not demonstrated")

    if result.get("correctionThroughUi") is not True:
        raise AssertionError("Centralizator correction through UI was not demonstrated")

    if result.get("productionCorrectionWriter") != 'UI adapter uses HomePage persistence; stale, deleted, unauthorized and offline corrections rejected':
        raise AssertionError("Production correction writer probes were not demonstrated")

    required = (
        "connectedFlow", "craiova11", "sameAttemptRetry", "twoNativeClients",
        "unauthorizedTeam", "legacyAndDeletion", "offlineBeforeStart",
        "revokedProfile", "restore", "pdf",
    )
    missing = [key for key in required if key not in result]
    if missing:
        raise AssertionError(f"Missing native assertions: {missing}")

    connected = result["connectedFlow"]
    if not isinstance(connected, dict):
        raise AssertionError("Connected flow evidence must be an object")
    if connected.get("expected") != "11 completed Craiova Dashboard records after double taps and server reload":
        raise AssertionError("Connected flow did not declare the 11-record Dashboard/server-reload assertion")
    if type(connected.get("observed")) is not int or connected["observed"] != 11:
        raise AssertionError("Connected flow did not persist exactly 11 records")
    if not isinstance(connected.get("id"), str) or not connected["id"].strip():
        raise AssertionError("Connected flow is missing the persisted record ID")

    scenario = result["craiova11"]
    if not isinstance(scenario, dict):
        raise AssertionError("Craiova 11 evidence must be an object")
    for key, expected in (("observed", 11), ("day15", 6), ("day16", 5),
                          ("uniqueIds", 11), ("centralizerCount", 11),
                          ("dashboardScheduleItems", 11), ("pdfMatchedScheduleItems", 11),
                          ("plannedRowRecordCount", 0)):
        if type(scenario.get(key)) is not int or scenario[key] != expected:
            raise AssertionError(f"Craiova 11 evidence {key} must be {expected}")
    markers = scenario.get("pdfMarkers")
    if (
        not isinstance(markers, list)
        or len(markers) != 11
        or any(not isinstance(marker, str) or not marker.strip() for marker in markers)
        or len(set(markers)) != 11
    ):
        raise AssertionError("Craiova PDF must declare 11 unique non-empty location markers")
    if scenario.get("plannedRowName") != "Craiova planificată":
        raise AssertionError("Craiova PDF planned-row marker is missing")
    if scenario.get("scheduleDatesMatchExecutions") is not True:
        raise AssertionError("Craiova schedule dates do not match reloaded execution event dates")

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
    if result["pdf"] != "11 Firestore-reloaded Craiova records rendered; planned row retained":
        raise AssertionError("11 reloaded Craiova records were not rendered into the PDF")


if __name__ == "__main__":
    verify(Path("xix-evidence"))
    print("Native PDF and completed scenario evidence: PASS")
