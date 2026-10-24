const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, serverTimestamp, writeBatch, runTransaction, Timestamp } = require('firebase/firestore');

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
        teamId: 'team-a', graphId: 'graph-1', graphName: 'Grafic test', closed: false, paused: false,
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

test('only Admin can pause or resume a graph', async () => {
  await assertFails(updateDoc(doc(db('editor'), schedulePath('open')), {
    paused: true, updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(db('editor'), schedulePath('open')))).data().paused, false);
  await assertSucceeds(updateDoc(doc(db('admin'), schedulePath('open')), {
    paused: true, updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(db('admin'), schedulePath('open')))).data().paused, true);
});

test('whole-graph admin pause is atomic and a denied editor batch leaves every day unchanged', async () => {
  const adminDb = db('admin');
  const first = doc(adminDb, schedulePath('open'));
  const second = doc(adminDb, schedulePath('batch-second'));

  const accepted = writeBatch(adminDb);
  accepted.update(first, { paused: true, updatedAt: serverTimestamp() });
  accepted.set(second, {
    teamId: 'team-a', graphId: 'graph-1', graphName: 'Grafic test', closed: false,
    paused: true, items: [], updatedAt: serverTimestamp(),
  });
  await assertSucceeds(accepted.commit());
  assert.equal((await getDoc(first)).data().paused, true);
  assert.equal((await getDoc(second)).data().paused, true);

  const editorDb = db('editor');
  const rejected = writeBatch(editorDb);
  rejected.update(doc(editorDb, schedulePath('open')), {
    items: [{ locationId: 'loc-c', order: 1, locationNameSnapshot: 'C nou' }],
    updatedAt: serverTimestamp(),
  });
  rejected.update(doc(editorDb, schedulePath('closed')), { items: [], updatedAt: serverTimestamp() });
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

test('Dashboard schedule START replays a committed batch after a lost acknowledgement without changing its receipt', async () => {
  const secondDay = doc(db('editor'), schedulePath('start-day-two'));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), schedulePath('start-day-two')), {
      teamId: 'team-a', graphId: 'graph-1', graphName: 'Grafic test', closed: false,
      paused: false, started: false, items: [{ locationId: 'loc-c', order: 1 }],
    });
  });

  const operationDb = db('admin');
  const refs = [doc(operationDb, schedulePath('open')), doc(operationDb, schedulePath('start-day-two'))];
  const snapshots = await Promise.all(refs.map((reference) => getDoc(reference)));
  const committedAt = Timestamp.fromDate(new Date('2026-10-23T08:00:00.000Z'));
  const desired = snapshots.map((snapshot, index) => ({
    ...snapshot.data(),
    started: true,
    paused: false,
    closed: false,
    departureName: 'Brăila',
    departureLatitude: 45.27,
    departureLongitude: 27.96,
    returnName: 'Galați',
    returnLatitude: 45.44,
    returnLongitude: 28.04,
    updatedAt: committedAt,
    writeToken: `stable-start-${index}`,
  }));
  const expected = snapshots.map((snapshot) => ({
    exists: snapshot.exists(),
    updatedAt: snapshot.data().updatedAt ?? null,
    writeToken: snapshot.data().writeToken ?? null,
    teamId: snapshot.data().teamId,
    graphId: snapshot.data().graphId,
  }));
  const sameValue = (left, right) => {
    if (left instanceof Timestamp && right instanceof Timestamp) return left.isEqual(right);
    if (left && right && typeof left === 'object' && typeof right === 'object') {
      const leftKeys = Object.keys(left);
      const rightKeys = Object.keys(right);
      return leftKeys.length === rightKeys.length && leftKeys.every((key) => sameValue(left[key], right[key]));
    }
    return left === right;
  };
  const apply = () => runTransaction(operationDb, async (transaction) => {
    const current = [];
    for (const reference of refs) current.push(await transaction.get(reference));
    const exactReplay = current.every((snapshot, index) => snapshot.exists()
      && Object.entries(desired[index]).every(([key, value]) => sameValue(snapshot.data()[key], value)));
    if (exactReplay) return 'replay';
    const baselineMatches = current.every((snapshot, index) => {
      const loaded = expected[index];
      if (snapshot.exists() !== loaded.exists) return false;
      if (!snapshot.exists()) return true;
      const data = snapshot.data();
      return data.teamId === loaded.teamId && data.graphId === loaded.graphId
        && sameValue(data.updatedAt ?? null, loaded.updatedAt)
        && (data.writeToken ?? null) === loaded.writeToken;
    });
    if (!baselineMatches) throw new Error('schedule changed since it was loaded');
    for (let index = 0; index < refs.length; index++) {
      transaction.set(refs[index], desired[index], { merge: true });
    }
    return 'write';
  });

  const lostAcknowledgement = async () => {
    assert.equal(await apply(), 'write');
    throw new Error('acknowledgement lost after commit');
  };
  await assert.rejects(lostAcknowledgement(), /acknowledgement lost/);
  const committed = await Promise.all(refs.map((reference) => getDoc(reference)));
  assert.equal(committed[0].data().writeToken, 'stable-start-0');
  assert.equal(committed[1].data().writeToken, 'stable-start-1');
  assert.ok(committed.every((snapshot) => snapshot.data().updatedAt.isEqual(committedAt)));

  assert.equal(await apply(), 'replay');
  const replayed = await Promise.all(refs.map((reference) => getDoc(reference)));
  assert.deepEqual(replayed.map((snapshot) => snapshot.data().writeToken), ['stable-start-0', 'stable-start-1']);
  assert.ok(replayed.every((snapshot) => snapshot.data().updatedAt.isEqual(committedAt)));
  assert.ok(replayed.every((snapshot) => snapshot.data().started === true));
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

// Existence provenance is independent of updatedAt/writeToken on legacy data.
// The app marks decoded schedules persisted and carries it through both editors.
test('legacy schedule deletion and new-ID collisions are rejected without partial writes', async () => {
  const database = db('editor');
  const legacy = doc(database, schedulePath('legacy-presence'));
  const other = doc(database, schedulePath('legacy-other'));
  const payload = { teamId:'team-a', graphId:'legacy', closed:false, items:[] };
  await setDoc(legacy, payload);
  await setDoc(other, payload);
  const loaded = await getDoc(legacy);
  assert.equal(loaded.data().updatedAt, undefined);
  assert.equal(loaded.data().writeToken, undefined);
  const { deleteDoc } = require('firebase/firestore');
  await deleteDoc(legacy);
  const save = (expectedExists) => runTransaction(database, async tx => {
    const snapshots = await Promise.all([tx.get(legacy), tx.get(other)]);
    if (snapshots[0].exists() !== expectedExists) throw new Error('presence changed');
    tx.set(legacy, payload);
    tx.update(other, { paused:true });
  });
  await assert.rejects(save(true), /presence changed/);
  assert.equal((await getDoc(legacy)).exists(), false);
  assert.equal((await getDoc(other)).data().paused, undefined);
  await setDoc(legacy, payload);
  await assert.rejects(save(false), /presence changed/);
  assert.equal((await getDoc(other)).data().paused, undefined);
});
