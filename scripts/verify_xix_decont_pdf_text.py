"""Assert the settlement PDF contains the server-reloaded corrected receipt."""
from pathlib import Path


def verify(text: str) -> None:
    required = ("DECONT", "Decont E2E", "12345", "150.25 lei", "Bon fiscal")
    missing = [marker for marker in required if marker.casefold() not in text.casefold()]
    if missing:
        raise AssertionError(f"Decont PDF is missing server-backed expense markers: {missing}")


if __name__ == "__main__":
    verify(Path("xix-evidence/decont-flow.txt").read_text(encoding="utf-8"))
    print("Server-backed decont PDF expense markers: PASS")
