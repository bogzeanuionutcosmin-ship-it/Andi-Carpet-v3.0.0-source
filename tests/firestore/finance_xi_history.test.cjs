// Genuine Firebase JS SDK + rules emulator. No live project, no data logging.
const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDocFromServer,writeBatch,runTransaction,serverTimestamp,Timestamp,collection,query,orderBy,where,limit,getDocsFromServer}=require('firebase/firestore');
let strict,legacy;
const stamp=new Timestamp(1790812800,123456789);
const payload=(n,{base=0,team='team',target='trip',actor='a'}={})=>{
 const id=n.toString(16).padStart(32,'0');
 const fields={protocol:2,operationId:id,actorUid:actor,teamId:team,targetPath:`settlements/${target}`,
 baseRevision:base,revision:base+1,kind:'departure',amount:200,method:'Cash',fromName:'Synthetic',date:stamp};
 return {id,target,team,path:`financeHistoryXi/s_${target}`,row:{...fields,digest:crypto.createHash('sha256').update(JSON.stringify(fields)).digest('hex')}};
};
async function seed(env){await env.withSecurityRulesDisabled(async c=>{
 const db=c.firestore();
 for(const [uid,role,fn,permissions] of [['a','member','worker',['viewOwnDecont']],['b','member','worker',['viewOwnDecont']],['admin','admin','worker',[]],['worker','member','worker',['viewOwnDecont']],['director','member','director',['viewOwnDecont','viewOtherDecont']]])
  await setDoc(doc(db,`users/${uid}`),{active:true,role,function:fn,effectivePermissions:permissions});
 await setDoc(doc(db,'teams/team'),{members:['a','worker'],financialManagerId:'a'});
 await setDoc(doc(db,'teams/second'),{members:['b'],financialManagerId:'b'});
 for(const [target,team] of [['trip','team'],['second','second']])await setDoc(doc(db,`settlements/${target}`),{teamId:team,closed:false,receivedDeparture:0,receivedDuring:0,receivedEntries:[]});
 });}
const db=uid=>strict.authenticatedContext(uid).firestore();
async function append(database,i,counters={calls:0,callbacks:0,reads:0,writes:0},{loseAck=false}={}){
 counters.calls++;
 const result=await runTransaction(database,async tx=>{
  counters.callbacks++;
  const row=await tx.get(doc(database,`${i.path}/receipts/${i.id}`));counters.reads++;
  const snap=await tx.get(doc(database,i.path));counters.reads++;
  if(row.exists()){
   if(row.data().digest!==i.row.digest||!snap.exists()||snap.data().revision<i.row.revision)throw Error('history_conflict');
   return 'replay';
  }
  const old=snap.exists()?snap.data():{revision:0,receivedDeparture:0,receivedDuring:0};
  if(old.revision!==i.row.baseRevision)throw Error('history_conflict');
  if(!snap.exists()){const source=await tx.get(doc(database,`settlements/${i.target}`));counters.reads++;
   if(!source.exists()||source.data().teamId!==i.team||source.data().receivedDeparture!==0)throw Error('legacy_requires_migration');}
  tx.set(doc(database,i.path),{protocol:2,teamId:i.team,sourceCollection:'settlements',sourceId:i.target,
   revision:i.row.revision,lastOperationId:i.id,receivedDeparture:old.receivedDeparture+i.row.amount,
   receivedDuring:old.receivedDuring,updatedAt:serverTimestamp()});
  tx.set(doc(database,`${i.path}/receipts/${i.id}`),{...i.row,createdAt:serverTimestamp()});counters.writes+=2;
  return 'applied';
 },{maxAttempts:3});
 if(loseAck)throw Error('synthetic_lost_ack_after_commit');
 return result;
}
before(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('local_emulator_required');
 strict=await initializeTestEnvironment({projectId:'demo-history-xi',firestore:{rules:fs.readFileSync('tests/firestore/finance_xi.rules','utf8')}});
 legacy=await initializeTestEnvironment({projectId:'demo-history-xi-main',firestore:{rules:fs.readFileSync('tests/firestore/fixtures/finance_ix_main.rules','utf8')}});
});
beforeEach(async()=>{await strict.clearFirestore();await legacy.clearFirestore();await seed(strict);await seed(legacy);});
after(async()=>{await strict?.cleanup();await legacy?.cleanup();});
test('XI SDK two teams retain separate immutable rows and constant-size summary',async()=>{
 await append(db('a'),payload(1));await append(db('b'),payload(2,{team:'second',target:'second',actor:'b'}));
 const a=(await getDocFromServer(doc(db('a'),'financeHistoryXi/s_trip'))).data();
 assert.equal(a.receivedDeparture,200);assert.equal(a.receivedEntries,undefined);assert.equal(a.revision,1);
 await assertFails(getDocFromServer(doc(db('a'),'financeHistoryXi/s_second')));
});
test('XI SDK replay exact identity uses zero new writes; changed digest refuses',async()=>{
 const i=payload(1),c={calls:0,callbacks:0,reads:0,writes:0};
 await append(db('a'),i,c);assert.equal(c.reads,3);assert.equal(c.writes,2);
 assert.equal(await append(db('a'),i,c),'replay');assert.equal(c.calls,2);assert.equal(c.writes,2);
 await assert.rejects(append(db('a'),{...i,row:{...i.row,digest:'b'.repeat(64)}}));assert.equal(c.writes,2);
});
test('XI SDK distinct equal intents sum twice and genuine bounded pinned query remains stable',async()=>{
 const first=payload(1);await append(db('a'),first);await append(db('a'),payload(2,{base:1}));
 const upper=(await getDocFromServer(doc(db('a'),first.path))).data();
 await append(db('a'),payload(3,{base:2}));
 const page=await getDocsFromServer(query(collection(db('a'),`${first.path}/receipts`),where('revision','<=',upper.revision),orderBy('revision','desc'),limit(20)));
 assert.deepEqual(page.docs.map(d=>d.data().revision),[2,1]);assert.equal(upper.receivedDeparture,400);
 assert.equal(page.metadata.fromCache,false);
 await assertFails(getDocsFromServer(query(collection(db('a'),`${first.path}/receipts`),limit(21))));
});
test('XI SDK parallel same-revision devices have exactly one accepted receipt',async()=>{
 const outcomes=await Promise.allSettled([append(db('a'),payload(1)),append(db('a'),payload(2))]);
 assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
 const summary=(await getDocFromServer(doc(db('a'),'financeHistoryXi/s_trip'))).data();
 assert.equal(summary.revision,1);assert.equal(summary.receivedDeparture,200);
 const rows=await getDocsFromServer(query(collection(db('a'),'financeHistoryXi/s_trip/receipts'),limit(20)));assert.equal(rows.size,1);
});
test('XI SDK lost ack reconciles same row and summary with no second transaction',async()=>{
 const i=payload(1),c={calls:0,callbacks:0,reads:0,writes:0};
 await assert.rejects(append(db('a'),i,c,{loseAck:true}),/synthetic_lost_ack_after_commit/);
 const row=await getDocFromServer(doc(db('a'),`${i.path}/receipts/${i.id}`));
 const summary=await getDocFromServer(doc(db('a'),i.path));
 assert.equal(row.data().digest,i.row.digest);assert.equal(summary.data().revision,1);
 assert.equal(c.calls,1);assert.equal(c.writes,2);
});
for(const actor of ['a','admin'])test(`XI rules ${actor} cannot orphan receipt/summary or rewrite/delete accepted history`,async()=>{
 const i=payload(1);await append(db('a'),i);
 await assertFails(setDoc(doc(db(actor),`${i.path}/receipts/${i.id}`),{...i.row,amount:1},{merge:true}));
 const next=payload(2,{base:1,actor});
 await assertFails(setDoc(doc(db(actor),`${next.path}/receipts/${next.id}`),{...next.row,createdAt:serverTimestamp()}));
 await assertFails(setDoc(doc(db(actor),i.path),{receivedDeparture:400,revision:2,lastOperationId:next.id,updatedAt:serverTimestamp()},{merge:true}));
 const batch=writeBatch(db(actor));batch.delete(doc(db(actor),`${i.path}/receipts/${i.id}`));await assertFails(batch.commit());
 assert.equal((await getDocFromServer(doc(db('a'),i.path))).data().revision,1);
});
for(const actor of ['worker','director','b'])test(`XI rules ${actor} cannot mint a receipt through a batch`,async()=>{
 const i=payload(1,{actor});const batch=writeBatch(db(actor));
 batch.set(doc(db(actor),i.path),{protocol:2,teamId:i.team,sourceCollection:'settlements',sourceId:'trip',revision:1,lastOperationId:i.id,receivedDeparture:200,receivedDuring:0,updatedAt:serverTimestamp()});
 batch.set(doc(db(actor),`${i.path}/receipts/${i.id}`),{...i.row,createdAt:serverTimestamp()});await assertFails(batch.commit());
});
test('XI SDK revocation after receipt commit denies later writes and preserves committed history',async()=>{
 await append(db('a'),payload(1));
 await strict.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users/a'),{active:false},{merge:true}));
 await assert.rejects(append(db('a'),payload(2,{base:1})));
 assert.equal((await getDocFromServer(doc(db('admin'),'financeHistoryXi/s_trip'))).data().revision,1);
});
for(const mode of ['main','candidate'])test(`XI legacy ${mode}: old payload cannot transparently share new ledger`,async()=>{
 const env=mode==='main'?legacy:strict;
 const manager=env.authenticatedContext('a').firestore(),admin=env.authenticatedContext('admin').firestore();
 const i=payload(1);await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),i.path),{protocol:2,teamId:'team',sourceCollection:'settlements',sourceId:'trip',revision:1,lastOperationId:i.id,receivedDeparture:200,receivedDuring:0});
  await setDoc(doc(c.firestore(),`${i.path}/receipts/${i.id}`),i.row);
 });
 const old=setDoc(doc(manager,'settlements/trip'),{teamId:'team',receivedDeparture:25,receivedEntries:[]},{merge:true});
 if(mode==='main'){
  await assertSucceeds(old);
  await assertFails(getDocFromServer(doc(manager,i.path)));
  await assertSucceeds(setDoc(doc(admin,`${i.path}/receipts/${i.id}`),{amount:1},{merge:true}));
 }else{
  await assertFails(old);
  await assertFails(setDoc(doc(admin,`${i.path}/receipts/${i.id}`),{amount:1},{merge:true}));
  assert.equal((await getDocFromServer(doc(manager,i.path))).data().receivedDeparture,200);
 }
});
