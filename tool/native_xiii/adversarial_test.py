"""Real compiled Dart FFI+SQLite OS subprocesses. No Python storage replacement."""
import json, os, pathlib, queue, subprocess, sys, tempfile, threading, unittest
EXE=os.environ.get('XIII_NATIVE_PROBE')
if not EXE: raise RuntimeError('XIII_NATIVE_PROBE required')

class Child:
 def __init__(self,request):
  self.p=subprocess.Popen([EXE],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
  self.lines=queue.Queue()
  def reader():
   for line in self.p.stdout:
    try:self.lines.put(json.loads(line))
    except Exception:self.lines.put({'invalid':True})
   self.lines.put(None)
  threading.Thread(target=reader,daemon=True).start()
  self.p.stdin.write(json.dumps(request,ensure_ascii=False)+'\n');self.p.stdin.flush()
 def line(self):
  value=self.lines.get(timeout=20)
  if value is None:raise AssertionError('native child exited without result')
  return value
 def release(self):self.p.stdin.write('release\n');self.p.stdin.flush()
 def finish(self):
  result=self.line();self.p.stdin.close();self.p.wait(timeout=20)
  if self.p.returncode:raise AssertionError('native executable failed')
  self.p.stdout.close();self.p.stderr.close();return result
 def kill(self):
  self.p.kill();self.p.wait(timeout=20)
  self.p.stdin.close();self.p.stdout.close();self.p.stderr.close()

class Native(unittest.TestCase):
 def setUp(self):self.temp=tempfile.TemporaryDirectory();self.root=self.temp.name;self.assertTrue(self.call('init')['ok'],'synthetic native storage initialization must succeed')
 def tearDown(self):self.temp.cleanup()
 def start(self,action,**kw):return Child(dict(action=action,directory=self.root,**kw))
 def call(self,action,**kw):return self.start(action,**kw).finish()
 def records(self,**kw):
  r=self.call('pending',**kw);self.assertTrue(r['ok'],r);return [json.loads(s) for s in r['result']]
 def ids(self):return {json.loads(r['history'])['receipt']['operationId'] for r in self.records()}
 def test_restart_and_exact_identity(self):
  self.assertTrue(self.call('prepare',id=1)['result']);self.assertFalse(self.call('prepare',id=1)['result'])
  self.assertEqual(self.call('prepare',id=1,amount=201)['code'],'native_v2_identity_reuse')
  self.assertEqual(self.call('prepare',id=2,target='trip-1')['code'],'native_v2_unresolved_target')
  info=self.call('inspect')['result'];self.assertEqual(info['journalMode'],'delete');self.assertEqual(info['userVersion'],2)
  print('Native engine',sys.platform,info['sqliteVersion'],'DELETE/EXTRA/EXCLUSIVE',flush=True)
 def test_two_real_processes_block_stale_read(self):
  a=self.start('prepare',id=1,holdStage='afterRead');stage=a.line();self.assertEqual(stage['stage'],'afterRead')
  b=self.call('prepare',id=2);self.assertNotEqual(stage['pid'],b['pid']);self.assertFalse(b['ok']);self.assertIn(b['code'],['native_v2_sqlite_5','native_v2_sqlite_6'])
  print('Independent native PIDs',stage['pid'],b['pid'],flush=True)
  a.release();self.assertTrue(a.finish()['result']);self.assertTrue(self.call('prepare',id=2)['result']);self.assertEqual(len(self.ids()),2)
 def test_commit_readback_lock_is_still_exclusive(self):
  a=self.start('prepare',id=1,holdStage='afterCommit');self.assertEqual(a.line()['stage'],'afterCommit')
  b=self.call('prepare',id=2);self.assertFalse(b['ok']);self.assertIn(b['code'],['native_v2_sqlite_5','native_v2_sqlite_6'])
  a.release();self.assertTrue(a.finish()['result']);self.assertTrue(self.call('prepare',id=2)['result']);self.assertEqual(len(self.ids()),2)
 def crash(self,stage,committed):
  self.call('prepare',id=1)
  a=self.start('prepare',id=2,holdStage=stage);self.assertEqual(a.line()['stage'],stage);a.kill()
  expected=2 if committed else 1;self.assertEqual(len(self.ids()),expected)
  if committed:self.assertFalse(self.call('prepare',id=2)['result'])
  else:self.assertTrue(self.call('prepare',id=2)['result'])
  self.assertEqual(len(self.ids()),2)
 def test_kill_after_begin(self):self.crash('afterBegin',False)
 def test_kill_after_read(self):self.crash('afterRead',False)
 def test_kill_after_validate(self):self.crash('afterValidate',False)
 def test_kill_after_write(self):self.crash('afterWrite',False)
 def test_kill_before_commit(self):self.crash('beforeCommit',False)
 def test_kill_after_commit(self):self.crash('afterCommit',True)
 def test_kill_before_readback(self):self.crash('beforeReadback',True)
 def test_kill_after_readback(self):self.crash('afterReadback',True)
 def test_crash_cleanup_cannot_remove_unrelated_pending(self):
  self.call('prepare',id=1);self.call('prepare',id=2)
  a=self.start('confirm',id=1,holdStage='afterWrite');a.line();a.kill();self.assertEqual(len(self.ids()),2)
  a=self.start('confirm',id=1,holdStage='afterCommit');a.line();a.kill();self.assertEqual(len(self.ids()),1)
  self.assertTrue(next(iter(self.ids())).endswith('2'))
 def test_revocation_before_commit_rolls_back(self):
  self.call('prepare',id=1);r=self.call('prepare',id=2,revokeStage='afterWrite');self.assertFalse(r['ok']);self.assertEqual(len(self.ids()),1)
 def test_revocation_after_commit_retains_uncertain_evidence(self):
  self.call('prepare',id=1);r=self.call('prepare',id=2,revokeStage='afterCommit');self.assertFalse(r['ok']);self.assertEqual(len(self.ids()),2)
 def test_epoch_frozen_not_rebound_on_A_B_A2(self):
  self.call('prepare',id=1,epoch=1);self.call('init',uid='B');self.call('prepare',id=2,uid='B',epoch=2)
  self.assertFalse(self.call('prepare',id=1,epoch=3)['result']);self.assertEqual(self.records(epoch=3)[0]['binding']['epoch'],1)
  self.assertEqual(len(self.records(uid='B')),1);self.assertEqual(len(self.records()),1)
 def test_team_transfer_retains_old_scope(self):
  self.call('prepare',id=1);self.call('init',team='other');self.call('prepare',id=2,team='other',epoch=2)
  self.assertEqual(self.records()[0]['binding']['teamId'],'team');self.assertEqual(self.records(team='other')[0]['binding']['teamId'],'other')
 def test_cross_uid_and_team_intents_denied(self):
  self.assertFalse(self.call('prepare',intentUid='foreign')['ok']);self.assertFalse(self.call('prepare',intentTeam='foreign')['ok']);self.assertEqual(self.records(),[])
 def test_corrupt_and_incompatible_not_reset(self):
  self.call('prepare',id=1);self.call('inject',fault='corrupt');before=self.call('inspect')['result']['envelope']
  self.assertEqual(self.call('pending')['code'],'native_v2_corrupt');self.assertFalse(self.call('init')['ok']);self.assertFalse(self.call('prepare',id=2)['ok'])
  self.assertEqual(self.call('inspect')['result']['envelope'],before)
 def test_incompatible_version_retained(self):
  self.call('prepare',id=1);self.call('inject',fault='version');self.assertFalse(self.call('pending')['ok']);self.assertFalse(self.call('init')['ok']);self.assertEqual(self.call('inspect')['result']['userVersion'],999)
 def test_wal_database_is_rejected_without_reset(self):
  self.call('prepare',id=1);before=self.call('inspect')['result']['envelope'];self.call('inject',fault='wal')
  self.assertFalse(self.call('pending')['ok']);self.assertFalse(self.call('init')['ok'])
  info=self.call('inspect')['result'];self.assertEqual(info['journalMode'],'wal');self.assertEqual(info['envelope'],before)
 def test_missing_storage_fails_closed(self):
  for p in pathlib.Path(self.root).iterdir():p.unlink()
  self.assertEqual(self.call('pending')['code'],'native_v2_storage_unavailable');self.assertEqual(list(pathlib.Path(self.root).iterdir()),[])
 def test_capacity_preserves_every_accepted_intent(self):
  for n in range(1,33):self.assertTrue(self.call('prepare',id=n)['result'])
  before=self.call('inspect')['result']['envelope'];self.assertEqual(self.call('prepare',id=33)['code'],'native_v2_full');self.assertEqual(self.call('inspect')['result']['envelope'],before)
 def test_real_sqlite_full_rolls_back(self):
  self.call('prepare',id=1);before=self.call('inspect')['result']['envelope']
  r=self.call('prepare',id=2,payer='Z'*12000,pageLimit=2);self.assertFalse(r['ok']);self.assertEqual(r['code'],'native_v2_sqlite_13');self.assertEqual(self.call('inspect')['result']['envelope'],before)
  self.assertTrue(self.call('prepare',id=2)['result'])
 def test_transaction_exception_rolls_back(self):
  self.call('prepare',id=1);self.assertFalse(self.call('prepare',id=2,failStage='afterWrite')['ok']);self.assertEqual(len(self.ids()),1)
 def test_unicode_utf8_capacity_preserves_previous_envelope(self):
  accepted=0;previous=self.call('inspect')['result']['envelope']
  for n in range(1,33):
   r=self.call('prepare',id=n,payer='漢'*4000)
   if not r['ok']:
    self.assertEqual(r['code'],'native_v2_full');self.assertEqual(self.call('inspect')['result']['envelope'],previous);break
   accepted+=1;previous=self.call('inspect')['result']['envelope']
  self.assertGreater(accepted,0);self.assertLess(accepted,32);self.assertEqual(len(self.records()),accepted)
  print('UTF8 native bound accepted',accepted,'large synthetic records',flush=True)
 def test_malformed_sqlite_file_retained(self):
  db=next(pathlib.Path(self.root).glob('*.sqlite3'));db.write_bytes(b'not-a-sqlite-database-retained')
  before=db.read_bytes();self.assertFalse(self.call('pending')['ok']);self.assertFalse(self.call('init')['ok']);self.assertEqual(db.read_bytes(),before)
 def test_foreign_scope_database_copy_cannot_be_adopted(self):
  import shutil
  self.call('prepare',id=1);source=next(pathlib.Path(self.root).glob('*.sqlite3'))
  self.call('init',uid='B');other=next(p for p in pathlib.Path(self.root).glob('*.sqlite3') if p!=source)
  shutil.copyfile(source,other)
  self.assertEqual(self.call('pending',uid='B')['code'],'native_v2_corrupt');self.assertFalse(self.call('init',uid='B')['ok']);self.assertEqual(len(self.records()),1)
 def test_native_persistence_with_model_server_ack_loss(self):
  r=self.call('model-flow');self.assertTrue(r['ok'],r)
  self.assertEqual(r['result'],dict(first='uncertain',repeat='uncertain',reconciled='confirmed',storedEpoch=1,transactions=1,writes=3,serverReads=4,pending=0))

if __name__=='__main__':unittest.main(verbosity=2)
