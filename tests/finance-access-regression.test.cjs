const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

let env;
const projectId = 'demo-andi-carpet-rules';
const uid = { admin: 'admin-test', manager: 'manager-test', worker: 'worker-test', outsider: 'outsider-test' };
const db = (user) => env.authenticatedContext(uid[user]).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    const batch = store.batch();
    for (const [role, id] of Object.entries(uid)) {
      batch.set(store.doc('users/' + id), {
        active: true, role: role === 'admin' ? 'admin' : 'member',
        function: role === 'worker' ? 'worker' : 'developer',
        effectivePermissions: role === 'worker' ? ['viewOwnDecont'] : [],
      });
    }
    batch.set(store.doc('teams/team-1'), { members: [uid.manager, uid.worker] });
    batch.set(store.doc('finance/team-1'), { managerId: uid.manager });
    batch.set(store.doc('memberDirectory/' + uid.worker), { name: 'Worker' });
    await batch.commit();
  });
});

test('directorul membrilor este accesibil lucrătorului activ, dar nu poate fi modificat', async () => {
  await assertSucceeds(db('worker').doc('memberDirectory/' + uid.worker).get());
  await assertFails(db('worker').doc('memberDirectory/' + uid.worker).update({ name: 'Altered' }));
});

test('lucrătorul nu poate lista profilurile private ale tuturor utilizatorilor', async () => {
  await assertFails(db('worker').collection('users').get());
});

test('lucrătorul poate citi doar propriul profil privat', async () => {
  await assertSucceeds(db('worker').doc('users/' + uid.worker).get());
  await assertFails(db('worker').doc('users/' + uid.manager).get());
});

test('lucrătorul poate propune cheltuială proprie neconfirmată', async () => {
  await assertSucceeds(db('worker').doc('expenses/proposal-ok').set({
    teamId: 'team-1', createdBy: uid.worker, confirmed: false,
    reviewStatus: 'pending', amount: 125,
  }));
});

test('lucrătorul nu poate crea cheltuială confirmată', async () => {
  await assertFails(db('worker').doc('expenses/proposal-confirmed').set({
    teamId: 'team-1', createdBy: uid.worker, confirmed: true,
    reviewStatus: 'pending', amount: 125,
  }));
});

test('lucrătorul nu poate crea cheltuială în numele altuia', async () => {
  await assertFails(db('worker').doc('expenses/proposal-forged').set({
    teamId: 'team-1', createdBy: uid.manager, confirmed: false,
    reviewStatus: 'pending', amount: 125,
  }));
});

test('lucrătorul nu poate propune o sumă negativă', async () => {
  await assertFails(db('worker').doc('expenses/proposal-negative').set({
    teamId: 'team-1', createdBy: uid.worker, confirmed: false,
    reviewStatus: 'pending', amount: -1,
  }));
});

test('persoana din afara echipei nu poate propune cheltuieli pentru echipă', async () => {
  await assertFails(db('outsider').doc('expenses/proposal-outsider').set({
    teamId: 'team-1', createdBy: uid.outsider, confirmed: false,
    reviewStatus: 'pending', amount: 125,
  }));
});
