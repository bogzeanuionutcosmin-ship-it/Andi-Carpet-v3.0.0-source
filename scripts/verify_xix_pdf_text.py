"""Validate intervention rows, allowing names to recur in address lines."""
import json
from pathlib import Path
import re


def verify(text, scenario):
    markers = scenario['pdfMarkers']
    assert len(markers) == 11 and len(set(markers)) == 11, markers
    lines = text.splitlines()
    for marker in markers:
        rows = [line for line in lines if re.match(
            r'^\s*' + re.escape(marker) + r'\s+\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}\s+\d{2}:\d{2}\s+', line)]
        assert len(rows) == 1, (marker, rows)
    planned = scenario['plannedRowName']
    planned_lines = [i for i, line in enumerate(lines) if planned in line]
    assert len(planned_lines) == 1, planned_lines
    assert any('Neexecutată' in line for line in lines[planned_lines[0]:planned_lines[0]+4]), text
    for expected in ['15.10.2026', '16.10.2026', '23:55', '00:20']:
        assert expected in text, expected


if __name__ == '__main__':
    verify(Path('xix-evidence/native-flow.txt').read_text(),
           json.loads(Path('xix-evidence/observations.json').read_text())['craiova11'])
    print('Native PDF intervention rows: PASS')
