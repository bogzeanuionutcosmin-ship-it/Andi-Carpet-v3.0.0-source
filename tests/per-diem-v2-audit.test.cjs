const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-audit', distributor: 'distributor-audit', beneficiary: 'beneficiary-audit', outsider: 'outsider-audit' };
const db = role => env.authenticatedContext(ids[role]).firestore();
const parent = 'per_diem_settlements_v2/settlement';
const old = () => ({
  distributorId: ids.distributor, beneficiaryId: ids.beneficiary,
  declaredBani: 12000, receivedBani: null, status: 'pending',
  paymentMethod: 'cash', revision: 0, createdAt: new Date(), updatedAt: new Date(),
});
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
        effectivePermissions: [],
      });
    }
    batch.set(store.doc(parent), old());
    batch.set(store.doc(parent + '/audit/declare'), {
      actorId: ids.distributor, action: 'declare', revision: 0,
    });
    await batch.commit();
  });
});
test('distribuitorul poate vedea auditul propriu', async () => {
  await assertSucceeds(db('distributor').doc(parent + '/audit/declare').get());
});
test('beneficiarul poate vedea auditul propriu', async () => {
  await assertSucceeds(db('beneficiary').doc(parent + '/audit/declare').get());
});
test('terțul nu poate vedea auditul decontului', async () => {
  await assertFails(db('outsider').doc(parent + '/audit/declare').get());
});
test('administratorul poate vedea auditul decontului', async () => {
  await assertSucceeds(db('admin').doc(parent + '/audit/declare').get());
});
test('nici administratorul nu poate modifica auditul imuabil', async () => {
  await assertFails(db('admin').doc(parent + '/audit/declare').update({ action: 'changed' }));
});
test('auditul imuabil nu poate fi șters din client', async () => {
  await assertFails(db('admin').doc(parent + '/audit/declare').delete());
});
test('un terț nu poate crea audit pentru tranzacția altora', async () => {
  await assertFails(db('outsider').doc(parent + '/audit/revision-1').set({
    action: 'acknowledge', actorId: ids.outsider, receivedBani: 12000,
    previousReceivedBani: null, previousStatus: 'pending',
    newStatus: 'received', revision: 1, at: new Date(),
  }));
});
test('beneficiarul nu poate crea audit fără actualizarea atomică a decontului', async () => {
  await assertFails(db('beneficiary').doc(parent + '/audit/revision-1').set({
    action: 'acknowledge', actorId: ids.beneficiary, receivedBani: 12000,
    previousReceivedBani: null, previousStatus: 'pending',
    newStatus: 'received', revision: 1, at: new Date(),
  }));
});
test('distribuitorul nu poate crea audit de confirmare în numele beneficiarului', async () => {
  await assertFails(db('distributor').doc(parent + '/audit/revision-1').set({
    action: 'acknowledge', actorId: ids.distributor, receivedBani: 12000,
    previousReceivedBani: null, previousStatus: 'pending',
    newStatus: 'received', revision: 1, at: new Date(),
  }));
});
test('nu poate fi suprascris auditul de declarare', async () => {
  await assertFails(db('distributor').doc(parent + '/audit/declare').set({
    action: 'declare', actorId: ids.distributor, amountBani: 12000,
    previousStatus: null, newStatus: 'pending', revision: 0, at: new Date(),
  }));
});
