const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-set', manager: 'manager-set', worker: 'worker-set', outsider: 'outsider-set' };
const db = role => env.authenticatedContext(ids[role]).firestore();
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet-rules',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const store = ctx.firestore();
    const batch = store.batch();
    for (const [role, id] of Object.entries(ids)) {
      batch.set(store.doc('users/' + id), {
        active: true, role: role === 'admin' ? 'admin' : 'member',
        effectivePermissions: role === 'outsider' ? [] : ['viewOwnDecont'],
      });
    }
    batch.set(store.doc('teams/team-1'), { members: [ids.manager, ids.worker] });
    batch.set(store.doc('finance/team-1'), { teamId: 'team-1', managerId: ids.manager });
    batch.set(store.doc('settlements/settlement-1'), {
      teamId: 'team-1', managerId: ids.manager, name: 'Decont inițial',
    });
    await batch.commit();
  });
});
test('membrul echipei poate citi decontul', async () => {
  await assertSucceeds(db('worker').doc('settlements/settlement-1').get());
});
test('persoana din afara echipei nu poate citi decontul', async () => {
  await assertFails(db('outsider').doc('settlements/settlement-1').get());
});
test('membrul poate crea decont fără gestionar prestabilit', async () => {
  await assertSucceeds(db('worker').doc('settlements/new').set({
    teamId: 'team-1', name: 'Decont nou',
  }));
});
test('membrul nu poate crea decont cu gestionar atribuit arbitrar', async () => {
  await assertFails(db('worker').doc('settlements/forged-manager').set({
    teamId: 'team-1', managerId: ids.worker, name: 'Decont fals',
  }));
});
test('persoana din afara echipei nu poate crea decontul', async () => {
  await assertFails(db('outsider').doc('settlements/outsider').set({
    teamId: 'team-1', name: 'Decont',
  }));
});
test('membrul poate actualiza numele decontului', async () => {
  await assertSucceeds(db('worker').doc('settlements/settlement-1').update({
    name: 'Decont actualizat',
  }));
});
test('membrul nu poate schimba echipa decontului', async () => {
  await assertFails(db('worker').doc('settlements/settlement-1').update({
    teamId: 'other-team',
  }));
});
test('membrul nu poate schimba gestionarul decontului', async () => {
  await assertFails(db('worker').doc('settlements/settlement-1').update({
    managerId: ids.worker,
  }));
});
test('persoana din afara echipei nu poate actualiza decontul', async () => {
  await assertFails(db('outsider').doc('settlements/settlement-1').update({
    name: 'Interzis',
  }));
});
test('membrul nu poate șterge decontul', async () => {
  await assertFails(db('worker').doc('settlements/settlement-1').delete());
});
test('administratorul poate șterge decontul', async () => {
  await assertSucceeds(db('admin').doc('settlements/settlement-1').delete());
});
test('gestionarul poate actualiza câmpurile financiare permise ale decontului', async () => {
  await assertSucceeds(db('manager').doc('settlements/settlement-1').update({
    total: 500,
  }));
});
test('lucrătorul nu poate actualiza totalul financiar al decontului', async () => {
  await assertFails(db('worker').doc('settlements/settlement-1').update({
    total: 500,
  }));
});
