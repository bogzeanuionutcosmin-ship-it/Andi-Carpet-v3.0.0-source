const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, runTransaction, setDoc, deleteDoc, writeBatch } = require('firebase/firestore');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const recordRef = (firestore, id) => doc(firestore, 'records', id);
const lockRef = (firestore, teamId) => doc(firestore, 'activeRecordLocks', teamId);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const adminDb = ctx.firestore();
    await Promise.all([
      setDoc(doc(adminDb, 'users/editor-a'), { active: true, role: 'worker', effectivePermissions: ['editProgram'] }),
      setDoc(doc(adminDb, 'users/editor-b'), { active: true, role: 'worker', effectivePermissions: ['editProgram'] }),
      setDoc(doc(adminDb, 'teams/team-a'), { members: ['editor-a', 'editor-b'] }),
      setDoc(doc(adminDb, 'teams/team-empty'), { members: ['editor-a'] }),
    ]);
  });
});

after(async () => { if (env) await env.cleanup(); });

function startRecord(firestore, id, locationId) {
  const reference = recordRef(firestore, id);
  const lock = lockRef(firestore, 'team-a');
  return runTransaction(firestore, async (transaction) => {
    const currentLock = await transaction.get(lock);
    if (currentLock.exists()) throw new Error('team already has a running intervention');
    transaction.set(reference, {
      teamId: 'team-a', locationId, status: 'running',
      startedAt: new Date(), finishedAt: null,
    });
    transaction.set(lock, { teamId: 'team-a', recordId: id, locationId });
  });
}

test('two clients cannot reserve separate START records for one team; finish releases lock', async () => {
  const outcomes = await Promise.allSettled([
    startRecord(db('editor-a'), 'record-a', 'location-a'),
    startRecord(db('editor-b'), 'record-b', 'location-b'),
  ]);
  assert.equal(outcomes.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(outcomes.filter((result) => result.status === 'rejected').length, 1);

  const acceptedDb = outcomes[0].status === 'fulfilled' ? db('editor-a') : db('editor-b');
  const acceptedId = outcomes[0].status === 'fulfilled' ? 'record-a' : 'record-b';
  const acceptedRecord = recordRef(acceptedDb, acceptedId);
  const lock = lockRef(acceptedDb, 'team-a');
  assert.equal((await assertSucceeds(getDoc(lock))).data().recordId, acceptedId);

  // An authorized client cannot remove the serialization point while its
  // work is running, including before a second device attempts another START.
  await assertFails(deleteDoc(lockRef(db('editor-b'), 'team-a')));
  assert.equal((await assertSucceeds(getDoc(lock))).data().recordId, acceptedId);
  assert.equal((await assertSucceeds(getDoc(acceptedRecord))).data().status, 'running');

  await assertSucceeds(runTransaction(acceptedDb, async (transaction) => {
    const record = await transaction.get(acceptedRecord);
    const currentLock = await transaction.get(lock);
    assert.equal(currentLock.data().recordId, acceptedId);
    transaction.update(acceptedRecord, { status: 'completed', finishedAt: new Date() });
    transaction.delete(lock);
  }));
  assert.equal((await assertSucceeds(getDoc(lock))).exists(), false);

  // The rules reject direct running-record writes that omit the matching lock.
  await assertFails(setDoc(recordRef(acceptedDb, 'bypass'), {
    teamId: 'team-a', locationId: 'bypass', status: 'running',
    startedAt: new Date(), finishedAt: null,
  }));

  const secondId = acceptedId === 'record-a' ? 'record-b' : 'record-a';
  await assertSucceeds(startRecord(acceptedDb, secondId, 'location-after-finish'));
  assert.equal((await assertSucceeds(getDoc(lock))).data().recordId, secondId);
});


test('an authorized member cannot forge a reservation for a missing or finished record', async () => {
  const editor = db('editor-a');
  const lock = lockRef(editor, 'team-empty');
  await assertFails(setDoc(lock, {
    teamId: 'team-empty', recordId: 'missing-reservation-target', locationId: 'room',
  }));
  await assertSucceeds(setDoc(recordRef(editor, 'finished-reservation-target'), {
    teamId: 'team-empty', locationId: 'room', status: 'completed',
    startedAt: new Date(), finishedAt: new Date(),
  }));
  await assertFails(setDoc(lock, {
    teamId: 'team-empty', recordId: 'finished-reservation-target', locationId: 'room',
  }));
  assert.equal((await assertSucceeds(getDoc(lock))).exists(), false);
});

test('linked START revalidates graph started, paused and postponed state on server', async () => {
  const editor=db('editor-a');
  const scheduleId='scope-start-day', graphId='scope-graph', interventionId='scope-visit';
  const record=recordRef(editor,'scoped-start');
  const lock=lockRef(editor,'team-empty');
  const attempt=()=>{
    const batch=writeBatch(editor);
    batch.set(record,{teamId:'team-empty',graphId,scheduleId,interventionId,locationId:'room',type:'magic',
      status:'running',startedAt:new Date(),finishedAt:null});
    batch.set(lock,{teamId:'team-empty',graphId,scheduleId,interventionId,recordId:'scoped-start',locationId:'room'});
    return batch.commit();
  };
  for(const flags of [{started:false},{started:true,paused:true},{started:true,postponed:true}]){
    await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),`schedules/${scheduleId}`),{
      teamId:'team-empty',graphId,closed:false,paused:false,postponed:false,
      interventionLocations:{[interventionId]:'room'},...flags}));
    await assertFails(attempt());
    assert.equal((await getDoc(record)).exists(),false);assert.equal((await getDoc(lock)).exists(),false);
  }
  await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),`schedules/${scheduleId}`),{
    teamId:'team-empty',graphId,closed:false,started:true,paused:false,postponed:false,
    interventionLocations:{[interventionId]:'room'}}));
  await assertSucceeds(attempt());
  assert.equal((await getDoc(record)).data().interventionId,interventionId);
  await assertSucceeds(runTransaction(editor,async tx=>{
    await tx.get(record);await tx.get(lock);
    tx.update(record,{status:'completed',finishedAt:new Date()});tx.delete(lock);
  }));
});
