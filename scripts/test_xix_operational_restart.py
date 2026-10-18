"""Inspect actual main-entry navigation and persisted emulator Auth state."""
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

OUT = pathlib.Path('xix-evidence')
PACKAGE = 'com.example.andi_carpeta'


def adb(*args):
    return subprocess.check_output(['adb', *args], timeout=45)


def labels(root):
    """Exact semantic lines, without accepting words embedded in warning prose."""
    return {line.strip() for node in root.iter('node')
            for field in ('text', 'content-desc')
            for line in node.get(field, '').splitlines() if line.strip()}


def navigation_selected(root, alternatives):
    nodes = [node for node in root.iter('node')
             if node.get('selected') == 'true'
             and any(label in labels(node) for label in
                     ('Acasă', 'Grafic', 'Central.', 'Centralizator', 'Hartă',
                      'Decont', 'Contacte', 'Mesaje', 'Doc.', 'Documente', 'Setări'))]
    # Some Flutter/Android combinations omit selection from accessibility XML.
    return not nodes or any(labels(node).intersection(alternatives) for node in nodes)


def screen_matches(root, title, alternatives, required=()):
    visible = labels(root)
    return (title in visible and set(required).issubset(visible)
            and navigation_selected(root, alternatives))


def foreground_is_package(dump):
    return any(re.search(r'\b' + re.escape(PACKAGE) + r'/', line)
               for line in dump.splitlines()
               if 'mCurrentFocus=' in line or 'mFocusedApp=' in line)


def own_crash(log):
    for block in re.split(r'(?=^.*FATAL EXCEPTION:)', log, flags=re.M):
        if 'FATAL EXCEPTION:' in block and re.search(
                r'Process:\s*' + re.escape(PACKAGE) + r'(?:,|\s|$)', block):
            return True
    return False


def state():
    adb('shell', 'rm', '-f', '/sdcard/xix-window.xml')
    adb('shell', 'uiautomator', 'dump', '/sdcard/xix-window.xml')
    raw = adb('exec-out', 'cat', '/sdcard/xix-window.xml')
    return ET.fromstring(raw), raw


def foreground():
    return foreground_is_package(adb('shell', 'dumpsys', 'window', 'windows').decode())


def app_screen_matches(root, title, alternatives, required=()):
    # Android 16 emulator window-focus dumps do not always expose the focused
    # Flutter package in the older mCurrentFocus format. UIAutomator's active
    # accessibility tree is the stronger screen witness: require both the
    # exact expected content/navigation and nodes owned by this application.
    packages = {node.get('package') for node in root.iter('node')}
    return PACKAGE in packages and screen_matches(root, title, alternatives, required)


def wait_screen(stem, title, alternatives, required=(), attempts=30):
    found = False
    for _ in range(attempts):
        try:
            root, raw = state()
            (OUT / f'{stem}.xml').write_bytes(raw)
            if app_screen_matches(root, title, alternatives, required):
                found = True
                break
        except (subprocess.CalledProcessError, ET.ParseError, subprocess.TimeoutExpired):
            pass
        time.sleep(1)
    (OUT / f'{stem}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    assert found, f'Expected loaded main-entry screen absent: {title}'


def tap_label(alternatives):
    for _ in range(20):
        try:
            root, _ = state()
            candidates = [node for node in root.iter('node')
                          if labels(node).intersection(alternatives)
                          and (node.get('text', '') in alternatives
                               or node.get('content-desc', '').split('\n')[0] in alternatives)]
            candidates.sort(key=lambda node: node.get('clickable') != 'true')
            for node in candidates:
                bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
                if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
                    adb('shell', 'input', 'tap', str((bounds[0] + bounds[2]) // 2),
                        str((bounds[1] + bounds[3]) // 2))
                    return
        except (subprocess.CalledProcessError, ET.ParseError, subprocess.TimeoutExpired):
            pass
        time.sleep(1)
    raise AssertionError(f'Missing navigation: {alternatives}')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    marker = 'XIX_RESTART_BEGIN_' + str(time.time_ns())
    adb('shell', 'log', '-t', 'XIX_RESTART', marker)
    try:
        for cycle in range(2):
            adb('shell', 'am', 'force-stop', PACKAGE)
            result = adb('shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/.MainActivity').decode()
            assert 'Error' not in result, result
            wait_screen(f'operational-restart-{cycle}', 'Echipe acum', ('Acasă',),
                        required=('Craiova XIX',))
        print('Actual main entry, loaded synthetic team and two authenticated cold restarts: PASS')
        for stem, alternatives, title, required in [
                ('Grafic', ('Grafic',), 'Grafic de lucru', ()),
                ('Central', ('Central.', 'Centralizator'), 'Centralizator',
                 ('Comun tuturor echipelor · MAGIC / Million',)),
                ('Acasa', ('Acasă',), 'Echipe acum', ('Craiova XIX',))]:
            tap_label(alternatives)
            wait_screen(f'navigation-{stem}', title, alternatives, required)
        print('Actual main-entry navigation: Grafic / Centralizator / Acasa PASS')
    finally:
        log = adb('logcat', '-d', '-v', 'threadtime').decode(errors='replace')
        assert marker in log, 'Restart logcat start marker missing; crash evidence unavailable'
        log = log.split(marker, 1)[1]
        (OUT / 'operational-restart-logcat.txt').write_text(log)
        assert not own_crash(log), 'Operational main-entry process crashed; inspect restart logcat'


if __name__ == '__main__':
    main()
