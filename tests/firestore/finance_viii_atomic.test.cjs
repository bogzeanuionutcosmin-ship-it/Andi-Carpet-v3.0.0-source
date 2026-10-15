// Actual Firestore Emulator acceptance. No real project, money or billing.
const {test,before,beforeEach,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,writeBatch,runTransaction,Timestamp,serverTimestamp}=require('firebase/firestore');
let env;
const db=uid=>env.authenticatedContext(uid).firestore();
const stamp=()=>Timestamp.fromDate(new Date('2026-10-15T00:00:00Z'));
const id=n=>n.toString(16).padStart(32,'0');
const history=()=>({teamId:'team',managerId:'manager',closed:false,name:'Synthetic trip',startDate:stamp(),endDate:null,perDiemRate:50,createdAt:stamp(),receivedDeparture:25,receivedDuring:10,receivedEntries:[]});
const intent=(n,{collection='settlements',base=0,actor='manager',kind='receipt',amount=200}={})=>({id:id(n),collection,target:collection==='finance'?'team':'trip',base,actor,kind,amount,digest:id(n).repeat(2)});
const target=i=>`${i.collection}/${i.target}`;
const markerPath=i=>`${target(i)}/financialIntents/${i.id}`;
function marker(i){return {operationId:i.id,actorUid:i.actor,teamId:'team',targetPath:target(i),baseRevision:i.base,revision:i.base+1,kind:i.kind,digest:i.digest,createdAt:serverTimestamp()};}
function transition(i,old){
 const next={...old,revision:i.base+1,lastOperationId:i.id,updatedAt:serverTimestamp()};
 if(i.kind==='receipt'){
  const entries=old.receivedEntries??[];
  next.receivedEntries=[...entries,{id:i.id,kind:'departure',amount:i.amount,method:'Cash',fromName:'Synthetic payer',date:stamp()}];
  next.receivedDeparture=old.receivedDeparture+i.amount;
  next.receivedOpeningDeparture=old.receivedOpeningDeparture??(entries.length===0?old.receivedDeparture:0);
  next.receivedOpeningDuring=old.receivedOpeningDuring??(entries.length===0?old.receivedDuring:0);
 }else if(i.kind==='edit'){next.name='Revised';}
 else if(i.kind==='close'){next.closed=true;next.endDate=stamp();}
 return next;
}
async function submit(d,i){return runTransaction(d,async tx=>{
 const m=await tx.get(doc(d,markerPath(i)));
 if(m.exists()){assert.equal(m.data().digest,i.digest);return 'replayed';}
 const old=await tx.get(doc(d,target(i)));
 if((old.data().revision??0)!==i.base)throw new Error('synthetic_revision_conflict');
 tx.set(doc(d,target(i)),transition(i,old.data()));tx.set(doc(d,markerPath(i)),marker(i));return 'applied';
},{maxAttempts:3});}
async function malicious(i,patch,{uid='manager',onlyTarget=false,onlyMarker=false}={}){
 const d=db(uid),old=(await getDoc(doc(d,target(i)))).data();const batch=writeBatch(d);
 if(!onlyMarker)batch.set(doc(d,target(i)),{...transition(i,old),...patch});
 if(!onlyTarget)batch.set(doc(d,markerPath(i)),marker(i));
 return batch.commit();
}
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-andi-carpet',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
 const d=c.firestore();
 for(const [uid,extra] of Object.entries({admin:{role:'admin'},manager:{},worker:{},outsider:{},director:{function:'director'},multiDirector:{functionIds:['worker','director']},developer:{function:'developer'},inactive:{active:false}}))await setDoc(doc(d,'users',uid),{active:true,role:'member',function:'worker',effectivePermissions:['viewOwnDecont','viewOtherDecont'],...extra});
 await setDoc(doc(d,'teams/team'),{members:['manager','worker','director','multiDirector','developer','inactive'],financialManagerId:'manager'});
 await setDoc(doc(d,'finance/team'),history());await setDoc(doc(d,'settlements/trip'),history());
 await setDoc(doc(d,'expenses/bill'),{teamId:'team',settlementId:'trip',createdBy:'worker',amount:50,confirmed:false});
 });});
after(async()=>{if(env)await env.cleanup();});
for(const collection of ['settlements','finance']){
 test(`real atomic receipt and same ID replay ${collection}`,async()=>{const i=intent(1,{collection}),d=db('manager');assert.equal(await submit(d,i),'applied');assert.equal(await submit(d,i),'replayed');const final=(await getDoc(doc(d,target(i)))).data();assert.equal(final.receivedDeparture,225);assert.equal(final.receivedDuring,10);assert.equal(final.receivedOpeningDeparture,25);assert.equal(final.receivedEntries.length,1);assert.equal(final.revision,1);});
 test(`two devices same revision conflict ${collection}`,async()=>{const a=db('manager'),b=db('manager');const results=await Promise.allSettled([submit(a,intent(1,{collection})),submit(b,intent(2,{collection}))]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);const losing=results.find(r=>r.status==='rejected').reason;
 // permission-denied is NOT proof of no commit and must not trigger a new intent.
 assert.doesNotMatch(losing.message,/maximum of 1000/);
 assert.ok(losing.message.includes('synthetic_revision_conflict') || losing.code==='permission-denied');
 const markers=await Promise.all([getDoc(doc(a,markerPath(intent(1,{collection})))),getDoc(doc(a,markerPath(intent(2,{collection}))))]);
 assert.equal(markers.filter(m=>m.exists()).length,1);
 for(const m of markers)assert.equal(m.metadata.fromCache,false);assert.equal((await getDoc(doc(a,`${collection}/${collection==='finance'?'team':'trip'}`))).data().receivedEntries.length,1);});
 test(`two legitimate equal receipts survive ${collection}`,async()=>{const d=db('manager');await submit(d,intent(1,{collection}));await submit(d,intent(2,{collection,base:1}));const final=(await getDoc(doc(d,`${collection}/${collection==='finance'?'team':'trip'}`))).data();assert.equal(final.receivedDeparture,425);assert.equal(final.receivedEntries.length,2);});
}
test('20 copies of the same durable ID cannot double apply',async()=>{const i=intent(1);const results=await Promise.allSettled(Array.from({length:20},()=>submit(db('manager'),i)));
 assert.equal(results.filter(r=>r.status==='fulfilled' && r.value==='applied').length,1);
 for(const r of results)if(r.status==='rejected'){assert.equal(r.reason.code,'permission-denied');assert.doesNotMatch(r.reason.message,/maximum of 1000/);}
 // Explicit read-only evidence check for every uncertain client; no financial retry.
 for(const r of results)if(r.status==='rejected'){const m=await getDoc(doc(db('manager'),markerPath(i)));assert.equal(m.metadata.fromCache,false);assert.equal(m.metadata.hasPendingWrites,false);assert.equal(m.data().digest,i.digest);}
 assert.equal((await getDoc(doc(db('manager'),target(i)))).data().receivedEntries.length,1);});
test('synthetic lost ack after real commit reconciles by immutable evidence',async()=>{const d=db('manager'),i=intent(1);await assert.rejects((async()=>{await submit(d,i);throw new Error('synthetic_lost_ack');})(),/synthetic_lost_ack/);const evidence=await getDoc(doc(d,markerPath(i)));assert.equal(evidence.metadata.fromCache,false);assert.equal(evidence.metadata.hasPendingWrites,false);assert.equal(evidence.data().digest,i.digest);assert.equal(await submit(d,i),'replayed');});
for(const uid of ['worker','director','multiDirector','developer','outsider','inactive'])test(`unauthorised ${uid} cannot append even with matching evidence`,async()=>{await assertFails(malicious(intent(1,{actor:uid}),{}, {uid}));});
test('target alone denied atomically',()=>assertFails(malicious(intent(1),{},{onlyTarget:true})));
test('marker alone denied atomically',()=>assertFails(malicious(intent(1),{},{onlyMarker:true})));
test('wrong receipt delta cannot be covered by marker',()=>assertFails(malicious(intent(1),{receivedDeparture:999})));
test('rewriting historic entry is denied',async()=>{await submit(db('manager'),intent(1));const i=intent(2,{base:1});const old=(await getDoc(doc(db('manager'),target(i)))).data();const next=transition(i,old);next.receivedEntries[0]={...next.receivedEntries[0],amount:1};await assertFails(malicious(i,{receivedEntries:next.receivedEntries}));});
test('opening history cannot be erased',()=>assertFails(malicious(intent(1),{receivedOpeningDeparture:0})));
test('manager binding cannot be replaced even with evidence',()=>assertFails(malicious(intent(1),{managerId:'worker'})));
for(const amount of [NaN,Infinity,-1])test(`invalid amount ${amount} denied by server`,()=>assertFails(malicious(intent(1,{amount}),{})));
test('closed settlement cannot receive funds',async()=>{await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'settlements/trip'),{closed:true}));await assertFails(malicious(intent(1),{}));});
for(const kind of ['edit','close'])test(`authorised ${kind} preserves history and evidence`,async()=>{const i=intent(1,{kind}),d=db('manager');await assertSucceeds(submit(d,i));assert.equal((await getDoc(doc(d,target(i)))).data().receivedDeparture,25);});
test('fresh settlement creation requires atomic marker',async()=>{const d=db('manager'),i=intent(1,{kind:'create'});i.target='new';const batch=writeBatch(d);batch.set(doc(d,target(i)),{...history(),receivedDeparture:0,receivedDuring:0,receivedOpeningDeparture:0,receivedOpeningDuring:0,revision:1,lastOperationId:i.id,updatedAt:serverTimestamp()});batch.set(doc(d,markerPath(i)),marker(i));await assertSucceeds(batch.commit());});
test('Admin Restore cannot overwrite or delete protected targets or markers',async()=>{const d=db('admin'),i=intent(1);await submit(db('manager'),i);await assertFails(setDoc(doc(d,target(i)),history()));await assertFails(deleteDoc(doc(d,target(i))));await assertFails(deleteDoc(doc(d,markerPath(i))));await assertFails(updateDoc(doc(d,markerPath(i)),{digest:'0'.repeat(64)}));assert.equal((await getDoc(doc(d,target(i)))).data().revision,1);});
test('manager and Admin still may commit legitimate atomic receipts',async()=>{await submit(db('manager'),intent(1));await assertSucceeds(submit(db('admin'),intent(2,{base:1,actor:'admin'})));});
test('expense creator can submit unconfirmed; only manager can change amount and confirm',async()=>{const worker=db('worker');await assertSucceeds(setDoc(doc(worker,'expenses/new'),{teamId:'team',settlementId:'trip',createdBy:'worker',amount:20,confirmed:false}));await assertFails(updateDoc(doc(worker,'expenses/new'),{amount:1,confirmed:true}));await assertSucceeds(updateDoc(doc(db('manager'),'expenses/new'),{amount:21,confirmed:true}));});
test('expense cannot move between teams or forge creator',async()=>{await assertFails(updateDoc(doc(db('manager'),'expenses/bill'),{teamId:'other'}));await assertFails(updateDoc(doc(db('manager'),'expenses/bill'),{createdBy:'manager'}));});
test('revoked user cannot reuse previously prepared request',async()=>{await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/manager'),{active:false}));await assertFails(submit(db('manager'),intent(1)));});

test('stale envelope rejects before rules expression exhaustion',async()=>{
 await submit(db('manager'),intent(1));
 const error=await assertFails(malicious(intent(2),{}));
 assert.equal(error.code,'permission-denied');
 assert.doesNotMatch(error.message,/maximum of 1000/);
});

test('view-own-only manager can create with real marker-first transaction reads',async()=>{
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/manager'),{effectivePermissions:['viewOwnDecont']}));
 const d=db('manager'),i=intent(3,{kind:'create'});i.target='fresh';
 await assertSucceeds(runTransaction(d,async tx=>{
  assert.equal((await tx.get(doc(d,markerPath(i)))).exists(),false);
  assert.equal((await tx.get(doc(d,target(i)))).exists(),false);
  tx.set(doc(d,target(i)),{...history(),receivedDeparture:0,receivedDuring:0,receivedOpeningDeparture:0,receivedOpeningDuring:0,revision:1,lastOperationId:i.id,updatedAt:serverTimestamp()});
  tx.set(doc(d,markerPath(i)),marker(i));
 },{maxAttempts:3}));
});
test('legacy worker permission fallback still allows the existing manager',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();const u=(await getDoc(doc(d,'users/manager'))).data();delete u.effectivePermissions;await setDoc(doc(d,'users/manager'),u);
 });
 await assertSucceeds(submit(db('manager'),intent(1)));
});
test('explicit empty permissions do not acquire legacy manager permission',async()=>{
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/manager'),{effectivePermissions:[]}));
 await assertFails(submit(db('manager'),intent(1)));
});

test('server rejects positive receipt invisible at aggregate precision',async()=>{
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'settlements/trip'),{receivedDeparture:1e20}));
 const before=(await getDoc(doc(db('manager'),'settlements/trip'))).data();
 assert.equal(before.receivedDeparture+1,before.receivedDeparture);
 await assertFails(malicious(intent(1,{amount:1}),{}));
 const after=(await getDoc(doc(db('manager'),'settlements/trip'))).data();assert.deepEqual(after,before);
});

test('effective-permission manager does not require legacy function field',async()=>{
 await env.withSecurityRulesDisabled(async c=>{const d=c.firestore();const ref=doc(d,'users/manager');const data=(await getDoc(ref)).data();delete data.function;await setDoc(ref,data);});
 await assertSucceeds(submit(db('manager'),intent(1)));
});
test('null optional functionIds do not break worker manager profile',async()=>{
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/manager'),{functionIds:null}));
 await assertSucceeds(submit(db('manager'),intent(1)));
});
