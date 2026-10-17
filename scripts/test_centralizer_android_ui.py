"""Basic emulator UI validation of the pinned synthetic, network-disabled APK."""
from pathlib import Path
import hashlib
import os
import re
import subprocess
import time
import xml.etree.ElementTree as ET

PACKAGE='com.example.andi_carpeta.centralizersmoke'
ACTIVITY=f'{PACKAGE}/com.example.andi_carpeta.MainActivity'
APK=Path('smoke-apk/app-debug.apk')
EXPECTED='2b90d512fa65ddeb7f768b8f83409b7e50719ec14e7ed11cff88df34893b0291'
OUT=Path('android-ui-evidence');OUT.mkdir(exist_ok=True)
def adb(*args):
    return subprocess.check_output(['adb',*args],timeout=45)
def snapshot(name):
    adb('shell','uiautomator','dump','/sdcard/andi-window.xml')
    data=adb('exec-out','cat','/sdcard/andi-window.xml')
    (OUT/f'{name}.xml').write_bytes(data)
    return ET.fromstring(data)
def matches(root,text):
    return [n for n in root.iter('node') if text in (n.get('text','')+' '+n.get('content-desc',''))]
def wait_for(text,name):
    for _ in range(12):
        try:
            root=snapshot(name)
            if matches(root,text):return root
        except (ET.ParseError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            (OUT/'automation-retries.txt').open('a').write(type(error).__name__+'\n')
        time.sleep(1)
    raise AssertionError(f'Expected UI label absent: {text}')
def tap(root,text):
    candidates=matches(root,text)
    assert candidates,f'Missing clickable label: {text}'
    for n in candidates:
        bounds=list(map(int,re.findall(r'\d+',n.get('bounds',''))))
        if len(bounds)==4 and bounds[2]>bounds[0] and bounds[3]>bounds[1]:
            adb('shell','input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2));return
    raise AssertionError(f'No visible bounds: {text}')
def capture(name):
    (OUT/f'{name}.png').write_bytes(adb('exec-out','screencap','-p'))

def main():
    assert hashlib.sha256(APK.read_bytes()).hexdigest()==EXPECTED,'Unexpected APK bytes'
    aapt=sorted(Path(os.environ['ANDROID_HOME']).glob('build-tools/*/aapt'))[-1]
    badging=subprocess.check_output([str(aapt),'dump','badging',str(APK)],text=True)
    assert f"package: name='{PACKAGE}'" in badging
    permissions=subprocess.check_output([str(aapt),'dump','permissions',str(APK)],text=True)
    for name in ['INTERNET','CAMERA','SEND_SMS','ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION']:
        assert f'android.permission.{name}' not in permissions
    adb('shell','svc','wifi','disable');adb('shell','svc','data','disable')
    print(adb('install',str(APK)).decode())
    adb('shell','input','keyevent','224')
    adb('shell','wm','dismiss-keyguard')
    launch=adb('shell','am','start','-W','-n',ACTIVITY).decode()
    print(launch);assert 'Error' not in launch,launch
    time.sleep(5)
    capture('launched')
    assert adb('shell','pidof',PACKAGE).decode().strip().isdigit(),'App process exited during startup'
    root=wait_for('TEST Centralizator','home');capture('home')
    for attempt in [1,2]:
        root=wait_for('Adaugă execuție','before-add')
        tap(root,'Adaugă execuție')
        dialog=wait_for('Adaugă execuție în Centralizator',f'dialog-{attempt}')
        capture(f'dialog-{attempt}')
        tap(dialog,'Anulează')
        wait_for('TEST Centralizator',f'cancelled-{attempt}')
        print(f'Android dialog open/cancel cycle {attempt}: PASS')
    adb('shell','am','force-stop',PACKAGE)
    adb('shell','am','start','-n',ACTIVITY)
    wait_for('TEST Centralizator','restart');capture('restart')
    pid=adb('shell','pidof',PACKAGE).decode().strip();assert pid.isdigit(),pid
    log=adb('logcat','-d',f'--pid={pid}').decode(errors='replace')
    (OUT/'app-log.txt').write_text(log)
    assert 'FATAL EXCEPTION' not in log,log
    print('Android synthetic launch, two dialog/cancel gestures and cold restart: PASS')
    print('No authentication, native Firestore, real roles or durable-data assertions are made.')

if __name__=='__main__':
    try:
        main()
    finally:
        try:
            capture('last-state')
            log=adb('logcat','-d','-s','AndroidRuntime:E','flutter:I').decode(errors='replace')
            (OUT/'startup-log.txt').write_text(log[-150000:])
        except Exception as error:
            (OUT/'diagnostic-error.txt').write_text(str(error))
