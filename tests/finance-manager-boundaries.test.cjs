const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-finance-extra', manager: 'manager-finance-extra', worker: 'worker-finance-extra', outsider: 'outsider-finance-extra' };
const db = role => env.authenticatedContext(ids[role]).firestore();
const financePath = 'finance/team-extra';
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
    batch.set(store.doc('teams/team-extra'), { members: [ids.manager, ids.worker] });
    batch.set(store.doc(financePath), {
      teamId: 'team-extra', managerId: ids.manager,
      receivedDeparture: 100, receivedDuring: 50, perDiemRate: 45,
    });
    await batch.commit();
  });
});
test('gestionarul poate citi finanțele echipei', async () => {
  await assertSucceeds(db('manager').doc(financePath).get());
});
test('lucrătorul echipei poate citi finanțele', async () => {
  await assertSucceeds(db('worker').doc(financePath).get());
});
test('persoana din afara echipei nu poate citi finanțele', async () => {
  await assertFails(db('outsider').doc(financePath).get());
});
test('gestionarul poate actualiza suma primită la plecare', async () => {
  await assertSucceeds(db('manager').doc(financePath).update({ receivedDeparture: 200 }));
});
test('gestionarul poate actualiza suma primită în deplasare', async () => {
  await assertSucceeds(db('manager').doc(financePath).update({ receivedDuring: 100 }));
});
test('gestionarul poate actualiza tariful diurnei', async () => {
  await assertSucceeds(db('manager').doc(financePath).update({ perDiemRate: 50 }));
});
test('lucrătorul nu poate modifica sumele gestionarului', async () => {
  await assertFails(db('worker').doc(financePath).update({ receivedDuring: 900 }));
});
test('gestionarul nu poate schimba identitatea gestionarului', async () => {
  await assertFails(db('manager').doc(financePath).update({ managerId: ids.worker }));
});
test('gestionarul nu poate muta registrul financiar în altă echipă', async () => {
  await assertFails(db('manager').doc(financePath).update({ teamId: 'other-team' }));
});
test('gestionarul nu poate șterge registrul financiar', async () => {
  await assertFails(db('manager').doc(financePath).delete());
});
test('administratorul poate șterge registrul financiar', async () => {
  await assertSucceeds(db('admin').doc(financePath).delete());
});
test('lucrătorul nu poate inițializa registrul financiar', async () => {
  await assertFails(db('worker').doc('finance/new-team').set({ teamId: 'new-team' }));
});
test('administratorul poate crea registru financiar fără gestionar', async () => {
  await assertSucceeds(db('admin').doc('finance/new-team').set({ teamId: 'new-team' }));
});
test('administratorul nu poate atribui gestionar din afara echipei', async () => {
  await assertFails(db('admin').doc(financePath).update({ managerId: ids.outsider }));
});
test('administratorul poate transfera gestiunea unui membru al echipei', async () => {
  await assertSucceeds(db('admin').doc(financePath).update({ managerId: ids.worker }));
});
test('gestionarul nu poate modifica câmpuri financiare nepermise', async () => {
  await assertFails(db('manager').doc(financePath).update({ approvedBy: ids.manager }));
});
