"""Inspect the actual main entry point with persisted emulator Auth state."""
import pathlib
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
