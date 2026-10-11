const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-ledger', distributor: 'distributor-ledger', beneficiary: 'beneficiary-ledger', stranger: 'stranger-ledger' };
const db = role => env.authenticatedContext(ids[role]).firestore();
const path = 'per_diem_settlements_v2/settlement';
const fixture = () => ({
  distributorId: ids.distributor, beneficiaryId: ids.beneficiary,
  declaredBani: 15000, receivedBani: null, status: 'pending',
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
    batch.set(store.doc(path), fixture());
    await batch.commit();
  });
});
test('distribuitorul poate vedea decontul v2', async () => {
  await assertSucceeds(db('distributor').doc(path).get());
});
test('beneficiarul poate vedea decontul v2', async () => {
  await assertSucceeds(db('beneficiary').doc(path).get());
});
test('persoana străină nu poate vedea decontul v2', async () => {
  await assertFails(db('stranger').doc(path).get());
});
test('administratorul poate vedea decontul v2', async () => {
  await assertSucceeds(db('admin').doc(path).get());
});
test('nimeni nu poate șterge decontul v2 din client', async () => {
  await assertFails(db('admin').doc(path).delete());
});
test('distribuitorul nu poate confirma primirea în numele beneficiarului', async () => {
  await assertFails(db('distributor').doc(path).update({
    status: 'received', receivedBani: 15000, revision: 1,
  }));
});
test('beneficiarul nu poate confirma fără audit atomic', async () => {
  await assertFails(db('beneficiary').doc(path).update({
    status: 'received', receivedBani: 15000, revision: 1,
  }));
});
test('beneficiarul nu poate confirma mai mult decât suma declarată', async () => {
  await assertFails(db('beneficiary').doc(path).update({
    status: 'received', receivedBani: 20000, revision: 1,
  }));
});
test('un terț nu poate modifica suma declarată', async () => {
  await assertFails(db('stranger').doc(path).update({ declaredBani: 100 }));
});
test('un participant nu poate modifica identitatea beneficiarului', async () => {
  await assertFails(db('beneficiary').doc(path).update({ beneficiaryId: ids.stranger }));
});
test('un participant nu poate modifica identitatea distribuitorului', async () => {
  await assertFails(db('distributor').doc(path).update({ distributorId: ids.stranger }));
});
test('un participant nu poate reduce revizia', async () => {
  await assertFails(db('beneficiary').doc(path).update({ revision: -1 }));
});
test('un terț nu poate crea decontul în numele distribuitorului', async () => {
  await assertFails(db('stranger').doc('per_diem_settlements_v2/forged').set(fixture()));
});
test('nu poate fi creat decontul cu sumă negativă', async () => {
  await assertFails(db('distributor').doc('per_diem_settlements_v2/negative').set({
    ...fixture(), declaredBani: -1,
  }));
});
test('nu poate fi creat decontul cu aceeași persoană la ambele capete', async () => {
  await assertFails(db('distributor').doc('per_diem_settlements_v2/self').set({
    ...fixture(), beneficiaryId: ids.distributor,
  }));
});
test('nu poate fi creat decontul cu metodă de plată neacceptată', async () => {
  await assertFails(db('distributor').doc('per_diem_settlements_v2/method').set({
    ...fixture(), paymentMethod: 'crypto',
  }));
});
test('nu poate fi creat decontul cu revizie inițială greșită', async () => {
  await assertFails(db('distributor').doc('per_diem_settlements_v2/revision').set({
    ...fixture(), revision: 5,
  }));
});
