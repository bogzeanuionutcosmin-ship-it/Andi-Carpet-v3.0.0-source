const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { collection, doc, getDoc, getDocs, query, runTransaction, setDoc, Timestamp, updateDoc, where } = require('firebase/firestore');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const recordRef = (firestore, id) => doc(firestore, 'records', id);
const millis = (day, hour, minute = 0) => Date.UTC(2026, 9, day, hour, minute);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const thursday = Timestamp.fromMillis(millis(15, 8));
    const friday = Timestamp.fromMillis(millis(16, 8));
    await Promise.all([
      setDoc(doc(adminDb, 'users/editor'), { active: true, role: 'worker', effectivePermissions: ['editCentralizer'] }),
      setDoc(doc(adminDb, 'users/outsider'), { active: true, role: 'worker', effectivePermissions: ['editCentralizer'] }),
      setDoc(doc(adminDb, 'teams/craiova'), { active: true, members: ['editor'] }),
      setDoc(doc(adminDb, 'teams/other'), { active: true, members: ['outsider'] }),
      ...Array.from({ length: 11 }, (_, index) => {
        const day = index < 5 ? 15 : 16;
        const start = day === 15 ? thursday : friday;
        const locationId = `sala-${index + 1}`;
        return setDoc(doc(adminDb, 'records', `exec-${index + 1}`), {
          teamId: 'craiova', locationId, type: 'million',
          locationNameSnapshot: `Sala ${index + 1}`, addressSnapshot: 'Craiova',
          startedAt: start, finishedAt: Timestamp.fromMillis(start.toMillis() + 3600000),
          status: 'completed', keptForLearning: true,
        });
      }),
      setDoc(doc(adminDb, 'schedules/thu'), { teamId: 'craiova', items: Array.from({ length: 5 }, (_, i) => `sala-${i + 1}`) }),
      setDoc(doc(adminDb, 'schedules/fri'), { teamId: 'craiova', items: Array.from({ length: 6 }, (_, i) => `sala-${i + 6}`) }),
    ]);
  });
});

after(async () => { if (env) await env.cleanup(); });

test('Craiova correction changes one execution date in place and leaves the plan intact', async () => {
  const editorDb = db('editor');
  const ref = recordRef(editorDb, 'exec-6');
  const before = await assertSucceeds(getDoc(ref));
  const expectedStart = before.data().startedAt.toMillis();

  await assertSucceeds(runTransaction(editorDb, async (transaction) => {
    const current = await transaction.get(ref);
    assert.equal(current.exists(), true);
    assert.equal(current.data().teamId, 'craiova');
    assert.equal(current.data().locationId, 'sala-6');
    assert.equal(current.data().startedAt.toMillis(), expectedStart);
    transaction.update(ref, {
      startedAt: Timestamp.fromMillis(millis(15, 12)),
      finishedAt: Timestamp.fromMillis(millis(15, 13)),
      facadeDone: true,
      facadePlanned: true,
    });
  }));

  const records = await assertSucceeds(getDocs(query(collection(editorDb, 'records'), where('teamId', '==', 'craiova'))));
  assert.equal(records.size, 11, 'correction must not create another execution');
  const byDay = records.docs.reduce((counts, snapshot) => {
    const day = new Date(snapshot.data().startedAt.toMillis()).getUTCDate();
    counts[day] = (counts[day] || 0) + 1;
    return counts;
  }, {});
  assert.equal(byDay[15], 6);
  assert.equal(byDay[16], 5);

  const corrected = await assertSucceeds(getDoc(ref));
  assert.equal(corrected.id, 'exec-6');
  assert.equal(corrected.data().facadeDone, true);
  assert.equal((await assertSucceeds(getDoc(doc(editorDb, 'schedules/thu')))).data().items.length, 5);
  assert.equal((await assertSucceeds(getDoc(doc(editorDb, 'schedules/fri')))).data().items.length, 6);
});

test('a deleted or stale record is not resurrected by correction and unauthorized teams are denied', async () => {
  const editorDb = db('editor');
  const deleted = recordRef(editorDb, 'exec-11');
  const stale = recordRef(editorDb, 'exec-10');
  const staleBefore = await assertSucceeds(getDoc(stale));
  await env.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await updateDoc(recordRef(adminDb, 'exec-10'), { facadeDone: true });
    const { deleteDoc } = require('firebase/firestore');
    await deleteDoc(recordRef(adminDb, 'exec-11'));
  });

  await assert.rejects(runTransaction(editorDb, async (transaction) => {
    const snapshot = await transaction.get(deleted);
    if (!snapshot.exists()) throw new Error('record deleted');
    transaction.update(deleted, { facadeDone: false });
  }), /record deleted/);
  await assert.rejects(runTransaction(editorDb, async (transaction) => {
    const snapshot = await transaction.get(stale);
    if (snapshot.data().facadeDone !== staleBefore.data().facadeDone) {
      throw new Error('stale record');
    }
    transaction.update(stale, { facadeDone: false });
  }), /stale record/);
  await assertFails(updateDoc(recordRef(db('outsider'), 'exec-1'), { facadeDone: true }));

  const remaining = await assertSucceeds(getDocs(query(collection(editorDb, 'records'), where('teamId', '==', 'craiova'))));
  assert.equal(remaining.size, 10, 'failed correction must not recreate deleted data');
  assert.equal((await assertSucceeds(getDoc(recordRef(editorDb, 'exec-10')))).data().facadeDone, true);
});
