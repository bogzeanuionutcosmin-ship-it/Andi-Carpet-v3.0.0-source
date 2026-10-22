import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('staging_build',ROOT/'scripts/build_staging_android.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def config():
    return {'project_info':{'project_id':'andi-staging-test','project_number':'123456','storage_bucket':'andi-staging-test.firebasestorage.app'},
      'client':[{'client_info':{'mobilesdk_app_id':'1:123456:android:test','android_client_info':{'package_name':m.PACKAGE}},'api_key':[{'current_key':'test-key'}]}]}

class StagingBuildTest(unittest.TestCase):
    def test_separate_config_is_retained_and_other_clients_removed(self):
        c=config();c['client'].append({'client_info':{'android_client_info':{'package_name':'unrelated'}}})
        options,native=m.validate_config(c)
        self.assertEqual(options['projectId'],'andi-staging-test');self.assertEqual(len(native['client']),1)

    def test_production_and_inconsistent_identity_are_rejected(self):
        for mutate in [lambda c:c['project_info'].update(project_id=m.PRODUCTION),
                       lambda c:c['project_info'].update(project_number='141489733149'),
                       lambda c:c['project_info'].update(storage_bucket='andicarpet-e777e.firebasestorage.app'),
                       lambda c:c['client'][0]['client_info'].update(mobilesdk_app_id='1:other:android:test'),
                       lambda c:c['client'][0]['client_info']['android_client_info'].update(package_name='com.example.andi_carpeta')]:
            c=config();mutate(c)
            with self.assertRaises(ValueError):m.validate_config(c)

    def test_build_failure_restores_exact_native_config_and_manifest(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);native=root/'android/app/google-services.json';manifest=root/'android/app/src/main/AndroidManifest.xml'
            native.parent.mkdir(parents=True);manifest.parent.mkdir(parents=True)
            originals={native:b'original config\n',manifest:'<application android:label="Andi Carpetă"/>'.encode()}
            for path,data in originals.items():path.write_bytes(data)
            def failed_run(args,**kwargs):
                self.assertEqual(json.loads(native.read_text())['project_info']['project_id'],'andi-staging-test')
                self.assertIn('Staging',manifest.read_text());self.assertIn('--debug',args)
                self.assertEqual(kwargs['env']['ANDICARPET_STAGING_BUILD'],'true')
                raise RuntimeError('simulated build failure')
            with self.assertRaisesRegex(RuntimeError,'simulated'):m.build(config(),root,root/'out',run=failed_run)
            for path,data in originals.items():self.assertEqual(path.read_bytes(),data)

    def test_relabelled_staging_config_cannot_retain_known_production_api_key(self):
        self.assertTrue(m.PRODUCTION_API_KEYS)
        for key in m.PRODUCTION_API_KEYS:
            c=config();c['client'][0]['api_key'][0]['current_key']=key
            with self.assertRaises(ValueError):m.validate_config(c)
