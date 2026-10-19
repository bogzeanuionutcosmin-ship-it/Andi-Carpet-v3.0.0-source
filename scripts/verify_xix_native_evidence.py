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
    if not isinstance(result["connectedFlow"], dict):
        raise AssertionError("Connected flow evidence must be an object")
    if not isinstance(result["twoNativeClients"], dict):
        raise AssertionError("Cross-client evidence must be an object")
    if result["connectedFlow"].get("observed") != 1:
        raise AssertionError("Connected flow did not persist exactly one record")
    exact_witnesses = {
        "sameAttemptRetry": "one document, identical payload accepted",
        "legacyAndDeletion": "legacy update passed; deleted baseline rejected",
        "pdf": "real builder with data reloaded from native Firestore; missing registry retained",
    }
    for key, expected in exact_witnesses.items():
        if result[key] != expected:
            raise AssertionError(f"Native evidence witness mismatch: {key}")
    if result["twoNativeClients"].get("accepted") not in ([True, False], [False, True]):
        raise AssertionError("Cross-client CAS did not select exactly one winner")
    if result["unauthorizedTeam"] != "permission-denied":
        raise AssertionError("Unauthorized team write was not denied")
    if result["revokedProfile"] != "cached Auth identity cannot write after server profile deactivation":
        raise AssertionError("Revoked profile rejection was not demonstrated")
    if result["offlineBeforeStart"] != "native transaction rejected; reconnect has no queued record":
        raise AssertionError("Offline fail-closed write was not demonstrated")
    if result["restore"] != "admin complete/repeat passed; readable inventory followed by denied mixed batch rolled back allowed update and deletions; oversized restore changed no records":
        raise AssertionError("Atomic restore rollback evidence was not demonstrated")


if __name__ == "__main__":
    verify(Path("xix-evidence"))
    print("Native PDF and completed scenario evidence: PASS")
