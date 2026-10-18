"""Inspect the actual main entry point with persisted emulator Auth state."""
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET
OUT=pathlib.Path('xix-evidence')
PACKAGE='com.example.andi_carpeta'
def adb(*args):return subprocess.check_output(['adb',*args],timeout=45)
for cycle in range(2):
    adb('shell','am','force-stop',PACKAGE)
    result=adb('shell','am','start','-W','-n',f'{PACKAGE}/.MainActivity').decode()
    assert 'Error' not in result,result
    found=False
    for _ in range(30):
        try:
            adb('shell','rm','-f','/sdcard/xix-window.xml')
            adb('shell','uiautomator','dump','/sdcard/xix-window.xml')
            raw=adb('exec-out','cat','/sdcard/xix-window.xml')
            root=ET.fromstring(raw)
            text=' '.join(n.get('text','')+' '+n.get('content-desc','') for n in root.iter('node'))
            if 'Acasă' in text or 'Grafic de lucru' in text:
                (OUT/f'operational-restart-{cycle}.xml').write_bytes(raw)
                found=True;break
        except (subprocess.CalledProcessError,ET.ParseError):pass
        time.sleep(1)
    (OUT/f'operational-restart-{cycle}.png').write_bytes(adb('exec-out','screencap','-p'))
    assert found,'Operational app did not restore authenticated home'
print('Actual main entry point, persisted emulator Auth and two cold restarts: PASS')

# Navigate real main-entry screens using persisted emulator authentication.
def state():
    adb('shell','rm','-f','/sdcard/xix-window.xml')
    adb('shell','uiautomator','dump','/sdcard/xix-window.xml')
    return ET.fromstring(adb('exec-out','cat','/sdcard/xix-window.xml'))

def tap_label(label):
    root=state()
    candidates=[n for n in root.iter('node') if n.get('text','')==label or n.get('content-desc','').split('\n')[0]==label]
    candidates.sort(key=lambda n:n.get('clickable')!='true')
    for node in candidates:
        b=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
        if len(b)==4 and b[2]>b[0] and b[3]>b[1]:
            adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));return
    raise AssertionError(f'Missing navigation: {label}')

for label,title in [('Grafic','Grafic de lucru'),('Central.','Comun tuturor echipelor'),('Acasă','Echipe acum')]:
    tap_label(label)
    found=False
    for _ in range(20):
        try:
            root=state()
            text=' '.join(n.get('text','')+' '+n.get('content-desc','') for n in root.iter('node'))
            if title in text: found=True;break
        except (subprocess.CalledProcessError,ET.ParseError):pass
        time.sleep(1)
    (OUT/f'navigation-{label.rstrip(".")}.png').write_bytes(adb('exec-out','screencap','-p'))
    assert found,f'Expected screen absent: {title}'
print('Actual main entry point navigation: Grafic / Centralizator / Acasa PASS')
