'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc } = require('firebase/firestore');
const serverRequire = require('node:module').createRequire(require('node:path').resolve(__dirname, '../../functions/package.json'));
const { initializeApp, deleteApp } = serverRequire('firebase-admin/app');
const { getFirestore, Timestamp } = serverRequire('firebase-admin/firestore');
const { closeGraph } = require('../../functions/graph_closure');
let env, app, db, sequence = 0;
before(async () => {
  env = await initializeTestEnvironment({ projectId:'demo-andi-carpet',
    firestore:{rules:fs.readFileSync('firestore.rules','utf8')} });
  app = initializeApp({projectId:'demo-andi-carpet'}, 'closure-tests'); db = getFirestore(app);
});
after(async () => { await db.terminate(); await deleteApp(app); await env.cleanup(); });
const at = n => Timestamp.fromMillis(1792550000000 + n);
const invoke = (fixture, overrides = {}, uid = fixture.uid) => closeGraph(db, uid,
  {...fixture.input, ...overrides}, {timestamp:Timestamp.now});
async function fixture({days = 2} = {}) {
  const key = `closure-${++sequence}`, uid = `${key}-editor`, teamId = key, graphId = `${key}-graph`;
  await db.doc(`users/${uid}`).set({active:true,role:'worker',effectivePermissions:['editProgram']});
  await db.doc(`teams/${teamId}`).set({members:[uid]});
  const schedules = [], records = [];
  for (let i=0;i<days;i++) {
    const id=`${key}-day-${i}`, interventionId=`${key}-visit-${i}`, locationId=`room-${i}`;
    const schedule = db.doc(`schedules/${id}`), record = db.doc(`records/${key}-record-${i}`);
    await schedule.set({teamId,graphId,started:true,closed:false,active:true,paused:false,
      writeToken:`v${i}`,interventionLocations:{[interventionId]:locationId},
      items:[{interventionId,locationId,locationNameSnapshot:locationId}]});
    await record.set({teamId,graphId,scheduleId:id,interventionId,locationId,type:'magic',
      status:'completed',startedAt:at(100),finishedAt:at(200)});
    schedules.push(schedule); records.push(record);
  }
  return {uid,teamId,graphId,schedules,records,
    input:{teamId,graphId,requestId:`${key}-request`,days:schedules.map((d,i)=>({id:d.id,writeToken:`v${i}`}))}};
}

test('server STOP persists every day and one immutable receipt; identical retry preserves timestamps', async () => {
  const f=await fixture(); const first=await invoke(f);
  const before=await Promise.all(f.schedules.map(d=>d.get()));
  for (const d of before) { assert.equal(d.data().closed,true); assert.equal(d.data().active,false); assert.equal(d.data().writeToken,first.receiptId); }
  const receipt=await db.doc(`graphClosures/${first.receiptId}`).get(); assert.equal(receipt.data().actorId,f.uid);
  assert.equal(receipt.data().interventionCount,2);
  const replay=await invoke(f); assert.equal(replay.replay,true); assert.equal(replay.receiptId,first.receiptId);
  const after=await Promise.all(f.schedules.map(d=>d.get()));
  assert.deepEqual(after.map(d=>d.data().updatedAt),before.map(d=>d.data().updatedAt));
  await assert.rejects(invoke(f,{graphId:'different'}),e=>e.code==='conflict');
  const client=env.authenticatedContext(f.uid).firestore();
  await assertFails(setDoc(doc(client,`graphClosures/${first.receiptId}`),{actorId:f.uid}));
  await assertFails(setDoc(doc(client,`schedules/${f.teamId}-late-day`),{teamId:f.teamId,graphId:f.graphId,closed:false,items:[]}));
  const original=(await f.records[0].get()).data();
  await assertFails(setDoc(doc(client,`records/${f.teamId}-late-attempt`),{...original,startedAt:original.startedAt.toDate(),finishedAt:original.finishedAt.toDate(),status:'notCompleted',refusalReason:'retry'}));
  await assertSucceeds(updateDoc(doc(client,f.records[0].path),{facadeDone:true}));
});

test('stale revisions, changed graph membership and missing days cause no partial closure', async () => {
  const f=await fixture(); await f.schedules[1].update({writeToken:'concurrent'});
  await assert.rejects(invoke(f),e=>e.code==='conflict');
  assert.equal((await f.schedules[0].get()).data().closed,false);
  await assert.rejects(invoke(f,{days:[f.input.days[0]]}),e=>e.code==='conflict');
  assert.equal((await f.schedules[1].get()).data().closed,false);
});

test('same-day historical work cannot satisfy a stable intervention; legacy needs reconciliation', async () => {
  const f=await fixture({days:1}); await f.records[0].update({interventionId:'another-graph-visit'});
  await assert.rejects(invoke(f),e=>e.code==='failed-precondition');
  const data=(await f.schedules[0].get()).data(); delete data.items[0].interventionId;
  await f.schedules[0].set(data); await assert.rejects(invoke(f),e=>e.code==='failed-precondition');
  assert.equal((await f.schedules[0].get()).data().closed,false);
});

test('refused, running, unexplained and invalid timed results block STOP; explained noncompletion is final', async () => {
  const f=await fixture({days:1});
  for (const change of [
    {status:'refused',refusalReason:'No access'}, {status:'running',finishedAt:null},
    {status:'notCompleted',finishedAt:at(200),refusalReason:' '},
    {status:'completed',startedAt:at(300),finishedAt:at(200)},
  ]) {
    await f.records[0].update(change); await assert.rejects(invoke(f),e=>e.code==='failed-precondition');
    assert.equal((await f.schedules[0].get()).data().closed,false);
  }
  await f.records[0].update({status:'notCompleted',finishedAt:at(400),refusalReason:'Building closed'});
  assert.equal((await invoke(f)).closed,true);
});

test('authorization is checked transactionally, including on receipt replay', async () => {
  const f=await fixture(); await assert.rejects(invoke(f,{},'outsider'),e=>e.code==='permission-denied');
  await invoke(f); await db.doc(`users/${f.uid}`).update({active:false});
  await assert.rejects(invoke(f),e=>e.code==='permission-denied');
});

test('a team START reservation blocks STOP and direct member or admin closure is denied', async () => {
  const f=await fixture(); await db.doc(`activeRecordLocks/${f.teamId}`).set({recordId:'busy'});
  await assert.rejects(invoke(f),e=>e.code==='failed-precondition');
  for(const uid of [f.uid,`${f.teamId}-admin`]) {
    if(uid!==f.uid) await db.doc(`users/${uid}`).set({active:true,role:'admin'});
    const client=env.authenticatedContext(uid).firestore();
    await assertFails(updateDoc(doc(client,f.schedules[0].path),{closed:true}));
    assert.equal((await getDoc(doc(client,f.schedules[0].path))).data().closed,false);
  }
});

test('linked record identity cannot be retargeted and forged reservations cannot change its scope', async () => {
  const f=await fixture({days:1}); const client=env.authenticatedContext(f.uid).firestore();
  const ref=doc(client,f.records[0].path);
  for(const change of [{interventionId:'wrong'},{graphId:'wrong'},{scheduleId:'wrong'},{locationId:'wrong'},{teamId:'wrong'}]) {
    await assertFails(updateDoc(ref,change));
  }
  assert.equal((await getDoc(ref)).data().interventionId,`${f.teamId}-visit-0`);
});

test('concurrent outcome correction and graph STOP cannot both commit an unresolved closed graph', async () => {
  const f=await fixture({days:1}); const client=env.authenticatedContext(f.uid).firestore();
  const [stop,edit]=await Promise.allSettled([
    invoke(f), updateDoc(doc(client,f.records[0].path),{status:'refused',refusalReason:'Concurrent refusal'}),
  ]);
  const schedule=(await f.schedules[0].get()).data(), record=(await f.records[0].get()).data();
  assert.ok(!(schedule.closed && record.status==='refused'));
  assert.ok(stop.status==='rejected' || edit.status==='rejected');
});

test('concurrent new day and STOP cannot leave a partially closed graph', async () => {
  const f=await fixture({days:1}); const client=env.authenticatedContext(f.uid).firestore();
  const late=doc(client,`schedules/${f.teamId}-concurrent-day`);
  const [stop,add]=await Promise.allSettled([invoke(f),setDoc(late,{teamId:f.teamId,graphId:f.graphId,closed:false,items:[]})]);
  const closed=(await f.schedules[0].get()).data().closed, exists=(await getDoc(late)).exists();
  assert.ok(!(closed && exists)); assert.ok(stop.status==='rejected' || add.status==='rejected');
});

test('Dashboard program STOP does not prevent official closure of fully resolved visits', async () => {
  const f=await fixture();
  await f.schedules[0].update({started:false});
  const result=await invoke(f);
  assert.equal(result.closed,true);
  for(const day of f.schedules)assert.equal((await day.get()).data().closed,true);
});
