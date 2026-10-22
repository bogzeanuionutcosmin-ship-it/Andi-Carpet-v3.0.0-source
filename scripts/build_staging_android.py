"""Build an isolated debug staging APK; never deploy or use production signing."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

PACKAGE = 'com.example.andi_carpeta.staging'
PRODUCTION = 'andicarpet-e777e'
PRODUCTION_API_KEYS = frozenset(re.findall(
    r"apiKey:\s*['\"]([^'\"]+)['\"]",
    (Path(__file__).resolve().parents[1] / 'lib/firebase_options.dart').read_text()))


def validate_config(config):
    project = config['project_info']['project_id']
    sender = str(config['project_info']['project_number'])
    bucket = config['project_info']['storage_bucket']
    if (not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project)
            or 'staging' not in project or project == PRODUCTION
            or not sender.isdigit() or sender == '141489733149'
            or bucket not in (f'{project}.firebasestorage.app', f'{project}.appspot.com')):
        raise ValueError('A separate staging Firebase project is required')
    clients = [c for c in config['client'] if c['client_info']['android_client_info']['package_name'] == PACKAGE]
    if len(clients) != 1:
        raise ValueError('Exactly one staging Android client is required')
    client = clients[0]
    app_id = client['client_info']['mobilesdk_app_id']
    if not app_id.startswith(f'1:{sender}:android:'):
        raise ValueError('Staging app and project number differ')
    api_key = client['api_key'][0]['current_key']
    if not isinstance(api_key, str) or not api_key or api_key in PRODUCTION_API_KEYS:
        raise ValueError('A separate staging API key is required')
    options = dict(projectId=project, messagingSenderId=sender, appId=app_id,
                   storageBucket=bucket, apiKey=api_key)
    native = dict(project_info=config['project_info'], client=[client], configuration_version='1')
    return options, native


def build(config, root, output, run=subprocess.run):
    options, native = validate_config(config)  # Validate before touching any source.
    root, output = Path(root).resolve(), Path(output).resolve()
    native_path = root / 'android/app/google-services.json'
    manifest_path = root / 'android/app/src/main/AndroidManifest.xml'
    originals = {p: p.read_bytes() for p in (native_path, manifest_path)}
    try:
        with tempfile.TemporaryDirectory(prefix='andi-staging-') as temp:
            defines = Path(temp) / 'defines.json'
            defines.write_text(json.dumps({'ANDICARPET_ENVIRONMENT':'staging',
                'ANDICARPET_STAGING_OPTIONS':json.dumps(options)}))
            native_path.write_text(json.dumps(native))
            manifest_path.write_text(originals[manifest_path].decode().replace(
                'android:label="Andi Carpetă"', 'android:label="AndiCarpet Staging"'))
            env = os.environ.copy()
            env.pop('ANDICARPET_EMULATOR_HOST', None)
            env['ANDICARPET_STAGING_BUILD'] = 'true'
            run(['flutter','build','apk','--debug',f'--dart-define-from-file={defines}'],
                cwd=root,env=env,check=True)
            apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
            if not apk.is_file() or not apk.stat().st_size:
                raise RuntimeError('No staging APK was produced')
            sdk = Path(env.get('ANDROID_HOME') or env.get('ANDROID_SDK_ROOT') or '')
            build_tools = sorted((sdk/'build-tools').glob('*'), key=lambda p:tuple(int(n) for n in re.findall(r'\d+',p.name)))
            if not build_tools:
                raise RuntimeError('Android tools required for artifact verification')
            tools = build_tools[-1]
            badging = run([str(tools/'aapt'),'dump','badging',str(apk)],check=True,capture_output=True,text=True).stdout
            if f"package: name='{PACKAGE}'" not in badging:
                raise RuntimeError('APK package is not isolated staging')
            signing = run([str(tools/'apksigner'),'verify','--print-certs',str(apk)],check=True,capture_output=True,text=True).stdout
            cert = re.search(r'certificate SHA-256 digest:\s*([a-fA-F0-9:]+)',signing)
            if not cert:
                raise RuntimeError('APK signing certificate could not be inspected')
            sha = run(['git','rev-parse','HEAD'],cwd=root,check=True,capture_output=True,text=True).stdout.strip()
            output.mkdir(parents=True,exist_ok=True)
            target = output/'AndiCarpet-staging-debug.apk'
            shutil.copyfile(apk,target)
            evidence = dict(source_sha=sha,project_id=options['projectId'],package_id=PACKAGE,
                apk_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                certificate_sha256=cert.group(1).replace(':','').lower(),
                signing='debug-test-only',physical_validation='NOT RUN',backend_deployed='NOT VERIFIED')
            (output/'staging-build.json').write_text(json.dumps(evidence,indent=2)+'\n')
            return evidence
    finally:
        for path, data in originals.items():
            path.write_bytes(data)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    evidence=build(json.loads(args.config.read_text()),Path(__file__).resolve().parents[1],args.output)
    print(json.dumps(evidence,indent=2))

if __name__=='__main__':
    main()
