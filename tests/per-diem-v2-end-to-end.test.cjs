const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { serverTimestamp } = require('firebase/firestore');

let env;
const ids = { distributor: 'manager-e2e', beneficiary: 'worker-e2e', stranger: 'stranger-e2e' };
const path = 'per_diem_settlements_v2/transfer-e2e';
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
    const batch = ctx.firestore().batch();
    for (const uid of Object.values(ids)) {
      batch.set(ctx.firestore().doc('users/' + uid), {
        active: true, role: 'member', effectivePermissions: ['viewOwnDecont'],
      });
    }
    await batch.commit();
  });
});

async function declareTransfer() {
  const distributorDb = db('distributor');
  const batch = distributorDb.batch();
  batch.set(distributorDb.doc(path), {
    distributorId: ids.distributor, beneficiaryId: ids.beneficiary,
    declaredBani: 12500, receivedBani: null, status: 'pending',
    paymentMethod: 'cash', revision: 0,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  batch.set(distributorDb.doc(path + '/audit/declare'), {
    action: 'declare', actorId: ids.distributor, amountBani: 12500,
    previousStatus: null, newStatus: 'pending', revision: 0,
    at: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
}

test('distribuire diurnă: creare atomică, vizibilitate beneficiar, confirmare și audit', async () => {
  await declareTransfer();
  const beneficiaryView = await assertSucceeds(db('beneficiary').doc(path).get());
  if (beneficiaryView.data().declaredBani !== 12500) throw Error('Suma declarată nu este vizibilă beneficiarului');
  const beneficiaryDb = db('beneficiary');
  const batch = beneficiaryDb.batch();
  batch.update(beneficiaryDb.doc(path), {
    receivedBani: 12500, status: 'received', revision: 1, updatedAt: serverTimestamp(),
  });
  batch.set(beneficiaryDb.doc(path + '/audit/revision-1'), {
    action: 'acknowledge', actorId: ids.beneficiary, receivedBani: 12500,
    previousReceivedBani: null, previousStatus: 'pending',
    newStatus: 'received', revision: 1, at: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  const result = await assertSucceeds(db('distributor').doc(path).get());
  if (result.data().status !== 'received' || result.data().revision !== 1) {
    throw Error('Confirmarea diurnei nu a fost salvată');
  }
  await assertSucceeds(db('beneficiary').doc(path + '/audit/revision-1').get());
});

test('distribuire diurnă: străinul nu poate citi, confirma sau șterge tranzacția', async () => {
  await declareTransfer();
  await assertFails(db('stranger').doc(path).get());
  await assertFails(db('stranger').doc(path).update({
    receivedBani: 12500, status: 'received', revision: 1,
  }));
  await assertFails(db('stranger').doc(path).delete());
});

test('distribuire diurnă: confirmarea fără audit atomic este respinsă', async () => {
  await declareTransfer();
  await assertFails(db('beneficiary').doc(path).update({
    receivedBani: 12500, status: 'received', revision: 1, updatedAt: serverTimestamp(),
  }));
});
