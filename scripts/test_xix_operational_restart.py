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


def dismiss_system_ui_anr(root):
    """Tap Android's Wait action only for its exact System UI ANR dialog."""
    system_dialog = any(
        node.get('package') == 'android'
        and node.get('text', '').strip() == "System UI isn't responding"
        for node in root.iter('node'))
    if not system_dialog:
        return False
    for node in root.iter('node'):
        if (node.get('package') != 'android' or node.get('text', '').strip() != 'Wait'
                or node.get('clickable') != 'true'):
            continue
        bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
            adb('shell', 'input', 'tap', str((bounds[0] + bounds[2]) // 2),
                str((bounds[1] + bounds[3]) // 2))
            return True
    return False


def wait_screen(stem, title, alternatives, required=(), attempts=30):
    found = False
    system_ui_recoveries = 0
    for _ in range(attempts):
        try:
            root, raw = state()
            (OUT / f'{stem}.xml').write_bytes(raw)
            if app_screen_matches(root, title, alternatives, required):
                found = True
                break
            if dismiss_system_ui_anr(root):
                system_ui_recoveries += 1
                with (OUT / f'{stem}-system-ui-anr.txt').open('a', encoding='utf-8') as evidence:
                    evidence.write('Dismissed Android System UI ANR using Wait; app screen must still pass validation.\n')
                time.sleep(2)
                continue
        except (subprocess.CalledProcessError, ET.ParseError, subprocess.TimeoutExpired):
            pass
        time.sleep(1)
    (OUT / f'{stem}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    if not found:
        visible = sorted(labels(root)) if 'root' in locals() else []
        try:
            in_foreground = foreground()
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
            in_foreground = f'unavailable: {exc}'
        (OUT / f'{stem}-diagnostic.txt').write_text(
            f'Expected: {title}\nForeground: {in_foreground}\nVisible labels: {visible!r}\n',
            encoding='utf-8')
        print((OUT / f'{stem}-diagnostic.txt').read_text(encoding='utf-8'), flush=True)
        for command in [('shell', 'dumpsys', 'activity', 'activities'), ('shell', 'dumpsys', 'window', 'windows')]:
            try:
                dump = adb(*command).decode(errors='replace')
                selected = [line.strip() for line in dump.splitlines() if any(token in line for token in ('mResumedActivity', 'topResumedActivity', 'mCurrentFocus', 'mFocusedApp', 'com.example.andi_carpeta'))]
                print(f'Diagnostic {command[-2]}: {selected[:20]}', flush=True)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                print(f'Diagnostic command unavailable: {exc}', flush=True)
        raise AssertionError(f'Expected loaded main-entry screen absent: {title}; '
                             f'System UI recovery attempts: {system_ui_recoveries}; '
                             f'inspect {stem}-diagnostic.txt and screenshot')
    if system_ui_recoveries:
        print(f'{stem}: recovered transient System UI ANR {system_ui_recoveries} time(s); app screen verified')


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


def login_synthetic_editor():
    """Authenticate through the actual UI against the seeded demo emulator."""
    root, _ = state()
    if 'Intră în cont' not in labels(root):
        return
    edits = [node for node in root.iter('node')
             if node.get('class', '').endswith('EditText')]
    assert len(edits) >= 2, f'Login form missing two editable fields: {len(edits)}'
    for node, value in zip(edits[:2], ('editor@andi.test', 'synthetic-only-123')):
        bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        assert len(bounds) == 4
        adb('shell', 'input', 'tap', str((bounds[0]+bounds[2])//2),
            str((bounds[1]+bounds[3])//2))
        adb('shell', 'input', 'text', value)
    tap_label(('Intră în cont',))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    marker = 'XIX_RESTART_BEGIN_' + str(time.time_ns())
    adb('shell', 'log', '-t', 'XIX_RESTART', marker)
    try:
        for cycle in range(2):
            adb('shell', 'am', 'force-stop', PACKAGE)
            result = adb('shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/.MainActivity').decode()
            assert 'Error' not in result, result
            if cycle == 0:
                login_synthetic_editor()
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
