// Genuine Firebase JS SDK + Firestore emulator. Authority changes are synthetic
// withSecurityRulesDisabled fixtures, not a production session service.
const {test,before,beforeEach,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const {initializeTestEnvironment,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDocFromServer,runTransaction,writeBatch,serverTimestamp}=require('firebase/firestore');
let env;
const fence=(epoch=1,teamId='team',enabled=true)=>({ownerUid:'a',epoch,teamId,enabled});
// Mock SIGNED claim fixture: a client may select it here only because this is
// rules-unit-testing. Production issuance/refresh is deliberately BLOCKED.
const context=(uid,epoch=1)=>env.authenticatedContext(uid,{financeEpoch:epoch}).firestore();
const intent=(n,{epoch=1,base=0,team='team',actor='a',target='trip'}={})=>{
 const id=n.toString(16).padStart(32,'0'),path=`financeHistoryXi/s_${target}`;
 const row={protocol:2,operationId:id,actorUid:actor,teamId:team,targetPath:`settlements/${target}`,
 baseRevision:base,revision:base+1,kind:'departure',amount:200,method:'Cash',fromName:'Synthetic',date:{seconds:1790812800,nanoseconds:123456789}};
 row.digest=crypto.createHash('sha256').update(JSON.stringify(row)).digest('hex');
 return {id,path,row,epoch,permitPath:`financeSessionXiii/s_${target}/permits/${id}`,
 permit:{version:1,ownerUid:actor,teamId:team,epoch,operationId:id,historyDigest:row.digest,summaryPath:path,rowPath:`${path}/receipts/${id}`}};
};
async function authority(change){return env.withSecurityRulesDisabled(async c=>change(c.firestore()));}
async function advance(next){await authority(db=>setDoc(doc(db,'financeSessionEpochXiii/a'),next));}
async function append(db,i,{pause,loseAck=false,bypassClient=false,counters}={}){
 if(counters)counters.calls++;
 const result=await runTransaction(db,async tx=>{
  const f=await tx.get(doc(db,`financeSessionEpochXiii/${i.row.actorUid}`));
  if(!bypassClient && (!f.exists()||f.data().epoch!==i.epoch||f.data().teamId!==i.row.teamId||!f.data().enabled))throw Error('fenced');
  const permit=await tx.get(doc(db,i.permitPath));
  const row=await tx.get(doc(db,`${i.path}/receipts/${i.id}`));
  const summary=await tx.get(doc(db,i.path));
  if(row.exists()){
   assert.deepEqual(permit.data(),i.permit);assert.equal(row.data().digest,i.row.digest);
   assert.ok(summary.data().revision>=i.row.revision);return 'replay';
  }
  const old=summary.exists()?summary.data():{revision:0,receivedDeparture:0,receivedDuring:0};
  if(old.revision!==i.row.baseRevision)throw Error('revision_conflict');
  if(pause)await pause();
  tx.set(doc(db,i.path),{protocol:2,teamId:i.row.teamId,sourceCollection:'settlements',sourceId:i.row.targetPath.split('/')[1],
   revision:i.row.revision,lastOperationId:i.id,receivedDeparture:old.receivedDeparture+i.row.amount,receivedDuring:old.receivedDuring,updatedAt:serverTimestamp()});
  tx.set(doc(db,`${i.path}/receipts/${i.id}`),{...i.row,createdAt:serverTimestamp()});
  tx.set(doc(db,i.permitPath),i.permit);if(counters)counters.writes+=3;return 'applied';
 },{maxAttempts:3});
 if(loseAck)throw Error('lost_ack_after_server_commit');
 return result;
}
async function blindBatch(db,i){
 // Malicious client bypasses all local checks and ALL transaction reads.
 const b=writeBatch(db);
 b.set(doc(db,i.path),{protocol:2,teamId:i.row.teamId,sourceCollection:'settlements',
  sourceId:i.row.targetPath.split('/')[1],revision:i.row.revision,lastOperationId:i.id,
  receivedDeparture:i.row.amount,receivedDuring:0,updatedAt:serverTimestamp()});
 b.set(doc(db,`${i.path}/receipts/${i.id}`),{...i.row,createdAt:serverTimestamp()});
 b.set(doc(db,i.permitPath),i.permit);return b.commit();
}
async function reconcile(db,i){
 // Evidence-only: do not require the old epoch to remain current.
 const p=await getDocFromServer(doc(db,i.permitPath));
 const r=await getDocFromServer(doc(db,`${i.path}/receipts/${i.id}`));
 const s=await getDocFromServer(doc(db,i.path));
 assert.deepEqual(p.data(),i.permit);assert.equal(r.data().digest,i.row.digest);
 assert.ok(s.data().revision>=i.row.revision);return 'confirmed';
}
before(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('loopback_emulator_required');
 env=await initializeTestEnvironment({projectId:'demo-session-xiii',firestore:{rules:fs.readFileSync('tests/firestore/finance_xiii_session.rules','utf8')}});
});
beforeEach(async()=>{await env.clearFirestore();await authority(async db=>{
 for(const uid of ['a','b','admin'])await setDoc(doc(db,`users/${uid}`),{active:true,role:uid==='admin'?'admin':'member',function:'worker',effectivePermissions:['viewOwnDecont']});
 await setDoc(doc(db,'teams/team'),{members:['a'],financialManagerId:'a'});
 await setDoc(doc(db,'teams/other'),{members:['b'],financialManagerId:'b'});
 await setDoc(doc(db,'settlements/trip'),{teamId:'team',closed:false,receivedDeparture:0,receivedDuring:0,receivedEntries:[]});
 await setDoc(doc(db,'financeSessionEpochXiii/a'),fence());
 });});
after(async()=>env?.cleanup());
test('XIII two independent device SDK instances: one same-revision commit; immutable matching permit',async()=>{
 const a=context('a'),b=context('a');assert.notEqual(a,b);
 const outcomes=await Promise.allSettled([append(a,intent(1)),append(b,intent(2))]);
 assert.equal(outcomes.filter(o=>o.status==='fulfilled').length,1);
 assert.equal((await getDocFromServer(doc(a,'financeHistoryXi/s_trip'))).data().receivedDeparture,200);
 const winner=outcomes[0].status==='fulfilled'?intent(1):intent(2);
 assert.equal(await reconcile(b,winner),'confirmed');
 await assertFails(setDoc(doc(a,winner.permitPath),{...winner.permit,epoch:2}));
});
test('XIII stale device rejected after authoritative logout-all even when local check is bypassed',async()=>{
 await advance(fence(2,'team',false));
 await assert.rejects(append(context('a'),intent(1),{bypassClient:true}));
 await authority(async db=>assert.equal((await getDocFromServer(doc(db,'financeHistoryXi/s_trip'))).exists(),false));
});
test('XIII revocation during in-flight transaction rejects retry and commits no partial pair',async()=>{
 let entered,release;const ready=new Promise(r=>entered=r),gate=new Promise(r=>release=r);
 let paused=false;
 const p=append(context('a'),intent(1),{pause:async()=>{if(!paused){paused=true;entered();await gate;}}});
 await ready;await advance(fence(2,'team',false));release();await assert.rejects(p);
 await authority(async db=>{assert.equal((await getDocFromServer(doc(db,intent(1).permitPath))).exists(),false);
 assert.equal((await getDocFromServer(doc(db,intent(1).path))).exists(),false);});
});
test('XIII A→B→A2 never revives epoch1; explicit new epoch2 intent accepted',async()=>{
 await advance(fence(2));await assert.rejects(append(context('a'),intent(1),{bypassClient:true}));
 await assert.rejects(append(context('b'),intent(2,{epoch:2}),{bypassClient:true}));
 assert.equal(await append(context('a',2),intent(3,{epoch:2})),'applied');
});
test('XIII commit before logout is not retroactively cancelled; lost ACK reconciles old epoch with same ID',async()=>{
 const i=intent(1),db=context('a');await assert.rejects(append(db,i,{loseAck:true}),/lost_ack/);
 await advance(fence(2));await assert.rejects(reconcile(context('a'),i));
 assert.equal(await reconcile(context('a',2),i),'confirmed');
 await assert.rejects(append(context('a'),i));
 assert.equal((await getDocFromServer(doc(context('a',2),i.path))).data().revision,1);
});
test('XIII team transfer keeps historic commit but denies former-team reconciliation',async()=>{
 const i=intent(1);await append(context('a'),i);
 await authority(async db=>{
 await setDoc(doc(db,'financeSessionEpochXiii/a'),fence(2,'other'));
 await setDoc(doc(db,'teams/team'),{members:[],financialManagerId:'b'});
 await setDoc(doc(db,'teams/other'),{members:['a'],financialManagerId:'a'});
 });
 await assert.rejects(reconcile(context('a',2),i));await assert.rejects(append(context('a',2),intent(2,{base:1}),{bypassClient:true}));
 await authority(async db=>assert.equal((await getDocFromServer(doc(db,i.path))).data().revision,1));
});
test('XIII revoked permissions block latest epoch too; role admin cannot bypass missing own fence',async()=>{
 await authority(db=>setDoc(doc(db,'users/a'),{active:false,role:'member',function:'worker',effectivePermissions:[]}));
 await assert.rejects(append(context('a'),intent(1),{bypassClient:true}));
 await assert.rejects(append(context('admin'),intent(2,{actor:'admin'}),{bypassClient:true}));
});
test('XIII clients including admin cannot create, decrease, advance or delete authoritative epochs',async()=>{
 for(const actor of ['a','b','admin']){
 const db=context(actor);await assertFails(setDoc(doc(db,'financeSessionEpochXiii/a'),fence(99)));
 await assertFails(setDoc(doc(db,`financeSessionEpochXiii/${actor}`),{...fence(),ownerUid:actor}));
 const batch=writeBatch(db);batch.delete(doc(db,'financeSessionEpochXiii/a'));await assertFails(batch.commit());
 }
});
test('XIII forged permit, orphan permit and historical permit rewrite are rejected atomically',async()=>{
 const db=context('a'),i=intent(1);await assertFails(setDoc(doc(db,i.permitPath),i.permit));
 const forged={...i,permit:{...i.permit,epoch:2}};await assert.rejects(append(db,forged));
 assert.equal((await getDocFromServer(doc(db,i.path))).exists(),false);
 await append(db,i);await assertFails(setDoc(doc(db,i.permitPath),{...i.permit,historyDigest:'f'.repeat(64)}));
});
for(const invalid of [0,1.5,9007199254740992])test(`XIII invalid epoch ${invalid} fails closed server-side`,async()=>{
 await advance(fence(invalid));await assert.rejects(append(context('a',invalid),intent(1,{epoch:invalid}),{bypassClient:true}));
});
test('XIII other UID including admin cannot read or substitute another owner permit',async()=>{
 const i=intent(1);await append(context('a'),i);
 for(const actor of ['b','admin'])await assertFails(getDocFromServer(doc(context(actor),i.permitPath)));
 await authority(db=>setDoc(doc(db,'financeSessionEpochXiii/admin'),{...fence(2),ownerUid:'admin'}));
 await assert.rejects(append(context('admin'),intent(2,{actor:'admin',base:1,epoch:1}),{bypassClient:true}));
 assert.equal((await getDocFromServer(doc(context('a'),i.path))).data().revision,1);
});
test('XIII exact replay has zero new writes; changed epoch never retags accepted permit',async()=>{
 const i=intent(1),db=context('a');await append(db,i);
 assert.equal(await append(context('a'),i),'replay');
 await advance(fence(2));
 await assert.rejects(append(context('a'),intent(1,{epoch:2})));
 assert.deepEqual((await getDocFromServer(doc(context('a',2),i.permitPath))).data(),i.permit);
 assert.equal((await getDocFromServer(doc(context('a',2),i.path))).data().revision,1);
});
test('XIII all incomplete pairs and malformed receipt reject after bounded-rules optimization',async()=>{
 const db=context('a'),i=intent(1);
 const summary={protocol:2,teamId:'team',sourceCollection:'settlements',sourceId:'trip',revision:1,lastOperationId:i.id,
 receivedDeparture:200,receivedDuring:0,updatedAt:serverTimestamp()};
 for(const paths of [['summary'],['row'],['permit'],['summary','row'],['summary','permit'],['row','permit']]){
 const b=writeBatch(db);
 if(paths.includes('summary'))b.set(doc(db,i.path),summary);
 if(paths.includes('row'))b.set(doc(db,`${i.path}/receipts/${i.id}`),{...i.row,createdAt:serverTimestamp()});
 if(paths.includes('permit'))b.set(doc(db,i.permitPath),i.permit);
 await assertFails(b.commit());
 }
 const b=writeBatch(db);b.set(doc(db,i.path),summary);
 b.set(doc(db,`${i.path}/receipts/${i.id}`),{...i.row,amount:201,createdAt:serverTimestamp()});
 b.set(doc(db,i.permitPath),i.permit);await assertFails(b.commit());
 assert.equal((await getDocFromServer(doc(db,i.path))).exists(),false);
 await append(db,i);
});


test('XIII combined real SQLite process restart + genuine server commit with injected lost ACK reconciles exact frozen ID without retransmission',
 {skip:!process.env.XIII_NATIVE_PROBE},async()=>{
 const {spawn}=require('node:child_process');
 const os=require('node:os'),path=require('node:path');
 const binary=process.env.XIII_NATIVE_PROBE;
 assert.ok(path.isAbsolute(binary),'compiled native probe must use absolute path');
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'andi-xiii-sdk-native-'));
 const command=action=>new Promise((resolve,reject)=>{
  const child=spawn(binary,[],{stdio:['pipe','pipe','pipe']});
  let stdout='',stderr='',settled=false;
  const timer=setTimeout(()=>{child.kill('SIGKILL');finish(Error('native_probe_timeout'));},20000);
  function finish(error,result){if(settled)return;settled=true;clearTimeout(timer);error?reject(error):resolve(result);}
  child.on('error',error=>finish(error));
  child.stdout.on('data',chunk=>{stdout+=chunk; if(stdout.length>262144){child.kill('SIGKILL');finish(Error('native_probe_output_bound'));}});
  child.stderr.on('data',chunk=>{stderr+=chunk;if(stderr.length>16384){child.kill('SIGKILL');finish(Error('native_probe_stderr_bound'));}});
  child.on('close',code=>{
   try{
    assert.equal(code,0,'native subprocess exit');
    const lines=stdout.trim().split('\n');assert.equal(lines.length,1,'one JSON result line');
    const result=JSON.parse(lines[0]);assert.equal(result.ok,true,'native probe action failed');
    assert.ok(Number.isInteger(result.pid)&&result.pid>0);finish(null,result);
   }catch(error){finish(error);}
  });
  child.stdin.on('error',error=>finish(error));
  child.stdin.end(JSON.stringify({directory,uid:'a',team:'team',epoch:1,id:9901,target:'trip',...action})+'\n');
 });
 try{
  const initial=await command({action:'init'});assert.equal(initial.result,true);
  assert.equal((await command({action:'prepare'})).result,true);
  const first=await command({action:'pending'});assert.notEqual(first.pid,initial.pid);
  assert.equal(first.result.length,1);
  const frozen=first.result[0],wrapper=JSON.parse(frozen),raw=wrapper.history;
  assert.deepEqual(wrapper.binding,{ownerUid:'a',teamId:'team',epoch:1});
  assert.equal(wrapper.format,'AndiSessionXiii');assert.equal(wrapper.version,1);
  const h=JSON.parse(raw);assert.equal(h.protocol,2);const r=h.receipt,c=r.changes;
  const exactDate=c.date['@timestamp'];assert.deepEqual(exactDate,[1790812800,123456789]);
  const summaryPath=`financeHistoryXi/s_${r.documentId}`,rowPath=`${summaryPath}/receipts/${r.operationId}`;
  const digest=crypto.createHash('sha256').update(raw,'utf8').digest('hex');
  const i={id:r.operationId,path:summaryPath,epoch:wrapper.binding.epoch,
   row:{protocol:2,operationId:r.operationId,digest,actorUid:r.actorUid,teamId:r.teamId,
    targetPath:`${r.collection}/${r.documentId}`,baseRevision:r.baseRevision,revision:r.baseRevision+1,
    kind:c.kind,amount:c.amount,method:c.method,fromName:c.fromName,
    date:{seconds:exactDate[0],nanoseconds:exactDate[1]}},
   permitPath:`financeSessionXiii/s_${r.documentId}/permits/${r.operationId}`,
   permit:{version:1,...wrapper.binding,operationId:r.operationId,historyDigest:digest,summaryPath,rowPath}};
  const db=context('a'),counters={calls:0,writes:0};
  await assert.rejects(append(db,i,{loseAck:true,counters}),/lost_ack_after_server_commit/);
  // A new executable process opens the same real SQLite DB after actual server
  // commit. No in-memory journal fixture or graceful object recreation is used.
  const restarted=await command({action:'pending'});assert.notEqual(restarted.pid,first.pid);
  assert.deepEqual(restarted.result,[frozen]);
  assert.equal((await command({action:'prepare'})).result,false,'existing intent grants no resend permission');
  assert.deepEqual((await command({action:'pending'})).result,[frozen]);
  assert.equal(await reconcile(context('a'),i),'confirmed');
  assert.deepEqual(counters,{calls:1,writes:3});
  assert.equal((await getDocFromServer(doc(db,summaryPath))).data().revision,1);
  assert.equal((await getDocFromServer(doc(db,summaryPath))).data().receivedDeparture,200);
  assert.deepEqual((await getDocFromServer(doc(db,i.permitPath))).data(),i.permit);
  assert.equal((await command({action:'confirm'})).result,true);
  assert.deepEqual((await command({action:'pending'})).result,[]);
  assert.deepEqual(counters,{calls:1,writes:3});
 }finally{fs.rmSync(directory,{recursive:true,force:true});}
 });


test('XIII old signed A1 token cannot adopt readable epoch2; only newly authorized A2 claim may append',async()=>{
 const old=context('a',1);await advance(fence(2));
 assert.equal((await getDocFromServer(doc(old,'financeSessionEpochXiii/a'))).data().epoch,2);
 const forged=intent(991,{epoch:2});
 await assert.rejects(append(old,forged,{bypassClient:true}));
 await assertFails(blindBatch(old,forged));
 await assertFails(getDocFromServer(doc(old,forged.path)));
 await authority(async db=>assert.equal((await getDocFromServer(doc(db,forged.path))).exists(),false));
 assert.equal(await append(context('a',2),forged),'applied');
 await assertFails(getDocFromServer(doc(old,forged.path)));
 assert.equal((await getDocFromServer(doc(context('a',2),forged.path))).data().revision,1);
});
test('XIII admin old signed epoch cannot forge current epoch; missing signed capability also denied',async()=>{
 await authority(db=>setDoc(doc(db,'financeSessionEpochXiii/admin'),{...fence(2),ownerUid:'admin'}));
 const adminForged=intent(992,{actor:'admin',epoch:2});
 await assert.rejects(append(context('admin',1),adminForged,{bypassClient:true}));
 await assertFails(blindBatch(context('admin',1),adminForged));
 const noCapability=env.authenticatedContext('a').firestore();
 await assert.rejects(append(noCapability,intent(993),{bypassClient:true}));
 await assertFails(blindBatch(noCapability,intent(993)));
 assert.equal((await getDocFromServer(doc(context('a'),'financeHistoryXi/s_trip'))).exists(),false);
});


test('XIII read fencing rejects old A1 and disabled current capability, while A2 reviews historic epoch1 evidence',async()=>{
 const old=context('a',1),i=intent(994);await append(old,i);
 await advance(fence(2));
 for(const p of [i.permitPath,i.path,`${i.path}/receipts/${i.id}`])await assertFails(getDocFromServer(doc(old,p)));
 await assert.rejects(reconcile(old,i));
 const fresh=context('a',2);assert.equal(await reconcile(fresh,i),'confirmed');
 assert.equal((await getDocFromServer(doc(fresh,i.permitPath))).data().epoch,1);
 await advance(fence(2,'team',false));
 for(const p of [i.permitPath,i.path,`${i.path}/receipts/${i.id}`])await assertFails(getDocFromServer(doc(fresh,p)));
 await assert.rejects(reconcile(fresh,i));
 // Accepted money remains. Authority inspection is evidence of no retro-cancel.
 await authority(async db=>assert.equal((await getDocFromServer(doc(db,i.path))).data().receivedDeparture,200));
});
