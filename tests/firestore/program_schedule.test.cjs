const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, serverTimestamp, writeBatch, runTransaction } = require('firebase/firestore');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const schedulePath = (id) => `schedules/${id}`;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const adminDb = ctx.firestore();
    await Promise.all([
      setDoc(doc(adminDb, 'users/editor'), { active: true, role: 'worker', effectivePermissions: ['editProgram'] }),
      setDoc(doc(adminDb, 'users/viewer'), { active: true, role: 'worker', effectivePermissions: ['viewProgram'] }),
      setDoc(doc(adminDb, 'users/outsider'), { active: true, role: 'worker', effectivePermissions: ['editProgram'] }),
      setDoc(doc(adminDb, 'users/admin'), { active: true, role: 'admin' }),
      setDoc(doc(adminDb, 'teams/team-a'), { active: true, members: ['editor', 'viewer', 'admin'] }),
      setDoc(doc(adminDb, 'teams/team-b'), { active: true, members: ['outsider', 'admin'] }),
      setDoc(doc(adminDb, schedulePath('open')), {
        teamId: 'team-a', graphId: 'graph-1', graphName: 'Grafic test', closed: false,
        items: [
          { locationId: 'loc-a', order: 1, locationNameSnapshot: 'A' },
          { locationId: 'loc-b', order: 2, locationNameSnapshot: 'B' },
        ],
      }),
      setDoc(doc(adminDb, schedulePath('closed')), {
        teamId: 'team-a', graphId: 'graph-1', graphName: 'Grafic închis', closed: true,
        items: [{ locationId: 'loc-a', order: 1, locationNameSnapshot: 'A' }],
      }),
    ]);
  });
});

after(async () => { if (env) await env.cleanup(); });

test('authorized team editor adds, reorders, removes, and rereads locations from Firestore', async () => {
  const reference = doc(db('editor'), schedulePath('open'));
  await assertSucceeds(updateDoc(reference, {
    items: [
      { locationId: 'loc-b', order: 1, locationNameSnapshot: 'B' },
      { locationId: 'loc-a', order: 2, locationNameSnapshot: 'A' },
      { locationId: 'loc-c', order: 3, locationNameSnapshot: 'C nou' },
    ],
    updatedAt: serverTimestamp(),
  }));

  // A fresh read models app reload and proves the accepted order was persisted.
  const reloaded = await assertSucceeds(getDoc(doc(db('editor'), schedulePath('open'))));
  assert.deepEqual(reloaded.data().items.map((item) => [item.locationId, item.order]), [
    ['loc-b', 1], ['loc-a', 2], ['loc-c', 3],
  ]);

  await assertSucceeds(updateDoc(doc(db('editor'), schedulePath('open')), {
    items: [
      { locationId: 'loc-b', order: 1, locationNameSnapshot: 'B' },
      { locationId: 'loc-c', order: 2, locationNameSnapshot: 'C nou' },
    ],
    updatedAt: serverTimestamp(),
  }));
  const afterRemoval = await assertSucceeds(getDoc(doc(db('editor'), schedulePath('open'))));
  assert.deepEqual(afterRemoval.data().items.map((item) => item.locationId), ['loc-b', 'loc-c']);
});

test('authorized team editor creates a schedule that survives an independent read', async () => {
  const reference = doc(db('editor'), schedulePath('created-by-editor'));
  await assertSucceeds(setDoc(reference, {
    teamId: 'team-a', graphId: 'graph-created', graphName: 'Grafic nou', closed: false,
    date: '2026-10-17T00:00:00.000',
    items: [{ locationId: 'loc-c', order: 1, locationNameSnapshot: 'C nou' }],
  }));
  const reread = await assertSucceeds(getDoc(doc(db('editor'), schedulePath('created-by-editor'))));
  assert.equal(reread.data().graphName, 'Grafic nou');
  assert.equal(reread.data().items[0].locationId, 'loc-c');
});

test('whole-graph changes commit atomically and a denied day leaves every day unchanged', async () => {
  const editorDb = db('editor');
  const first = doc(editorDb, schedulePath('open'));
  const second = doc(editorDb, schedulePath('batch-second'));

  const accepted = writeBatch(editorDb);
  accepted.update(first, { paused: true, updatedAt: serverTimestamp() });
  accepted.set(second, {
    teamId: 'team-a', graphId: 'graph-1', graphName: 'Grafic test', closed: false,
    paused: true, items: [], updatedAt: serverTimestamp(),
  });
  await assertSucceeds(accepted.commit());
  assert.equal((await getDoc(first)).data().paused, true);
  assert.equal((await getDoc(second)).data().paused, true);

  const rejected = writeBatch(editorDb);
  rejected.update(first, { paused: false, updatedAt: serverTimestamp() });
  rejected.update(doc(editorDb, schedulePath('closed')), {
    paused: true, updatedAt: serverTimestamp(),
  });
  await assertFails(rejected.commit());
  assert.equal((await getDoc(first)).data().paused, true,
    'Firestore must roll back every write if any day in the graph is denied');
});

test('two concurrent schedule editors cannot both save from the same updatedAt version', async () => {
  const editorDb = db('editor');
  const reference = doc(editorDb, schedulePath('open'));
  const initial = await getDoc(reference);
  const expectedUpdatedAt = initial.data().updatedAt ?? null;
  const expectedWriteToken = initial.data().writeToken ?? null;
  let readers = 0;
  let releaseReaders;
  const bothRead = new Promise((resolve) => { releaseReaders = resolve; });

  const saveAgainstLoadedVersion = (paused, writeToken) => runTransaction(editorDb, async (transaction) => {
    const current = await transaction.get(reference);
    const actualUpdatedAt = current.data().updatedAt ?? null;
    const actualWriteToken = current.data().writeToken ?? null;
    readers += 1;
    if (readers === 2) releaseReaders();
    await bothRead;
    const stale = expectedUpdatedAt == null
      ? actualUpdatedAt != null
      : actualUpdatedAt == null || actualUpdatedAt.toMillis() !== expectedUpdatedAt.toMillis();
    const tokenStale = actualWriteToken !== expectedWriteToken;
    if (stale || tokenStale) throw new Error('schedule changed since it was loaded');
    transaction.update(reference, { paused, updatedAt: serverTimestamp(), writeToken });
  });

  const results = await Promise.allSettled([
    saveAgainstLoadedVersion(true, 'writer-a-version-1'),
    saveAgainstLoadedVersion(false, 'writer-b-version-1'),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  const accepted = (await getDoc(reference)).data();
  assert.ok(accepted.updatedAt, 'the accepted transaction must persist its update timestamp');
  assert.ok(['writer-a-version-1', 'writer-b-version-1'].includes(accepted.writeToken),
    'the accepted transaction must persist its unique write token');
});

test('team membership and editProgram are both required for schedule writes', async () => {
  await assertFails(updateDoc(doc(db('viewer'), schedulePath('open')), {
    items: [{ locationId: 'loc-x', order: 1 }],
  }));
  await assertFails(updateDoc(doc(db('outsider'), schedulePath('open')), {
    items: [{ locationId: 'loc-x', order: 1 }],
  }));
});

test('closed schedule rejects member writes but Admin can reopen it', async () => {
  await assertFails(updateDoc(doc(db('editor'), schedulePath('closed')), { closed: false }));
  await assertSucceeds(updateDoc(doc(db('admin'), schedulePath('closed')), { closed: false }));
});
