const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, writeBatch, serverTimestamp, getDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;
const collection = 'per_diem_settlements_v2';
const path = (id) => `${collection}/${id}`;
const db = (uid) => env.authenticatedContext(uid).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const { setDoc } = require('firebase/firestore');
    for (const uid of ['payer', 'receiver', 'stranger']) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { active: true, role: 'worker' });
    }
  });
});
after(async () => { if (env) await env.cleanup(); });

function declaration(id, payer = 'payer', receiver = 'receiver') {
  const database = db(payer);
  const batch = writeBatch(database);
  batch.set(doc(database, path(id)), {
    distributorId: payer, beneficiaryId: receiver,
    declaredBani: 5000, receivedBani: null, status: 'pending',
    paymentMethod: 'cash', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(), revision: 0,
  });
  batch.set(doc(database, `${path(id)}/audit/declare`), {
    action: 'declare', actorId: payer, amountBani: 5000,
    previousStatus: null, newStatus: 'pending', revision: 0,
    at: serverTimestamp(),
  });
  return batch.commit();
}
function confirmation(id, actor, amount, override = {}) {
  const database = db(actor);
  const batch = writeBatch(database);
  const status = amount === 0 ? 'refused' : amount === 5000 ? 'received' : 'partiallyReceived';
  batch.update(doc(database, path(id)), {
    receivedBani: amount, status, revision: 1,
    updatedAt: serverTimestamp(), ...override,
  });
  batch.set(doc(database, `${path(id)}/audit/revision-1`), {
    action: amount === 0 ? 'refuse' : 'acknowledge', actorId: actor,
    receivedBani: amount, previousReceivedBani: null,
    previousStatus: 'pending', newStatus: status, revision: 1,
    at: serverTimestamp(),
  });
  return batch.commit();
}

test('payer may declare with audit; receiver can read', async () => {
  await assertSucceeds(declaration('valid'));
  await assertSucceeds(getDoc(doc(db('receiver'), path('valid'))));
  await assertFails(getDoc(doc(db('stranger'), path('valid'))));
});
test('receiver may confirm with matching audit', async () => {
  await assertSucceeds(declaration('confirm'));
  await assertSucceeds(confirmation('confirm', 'receiver', 5000));
});
test('receiver may refuse with matching audit', async () => {
  await assertSucceeds(declaration('refuse'));
  await assertSucceeds(confirmation('refuse', 'receiver', 0));
});
test('stranger and payer cannot confirm for receiver', async () => {
  await assertSucceeds(declaration('no-stranger'));
  await assertFails(confirmation('no-stranger', 'stranger', 5000));
  await assertFails(confirmation('no-stranger', 'payer', 5000));
});
test('receiver cannot change declared amount during confirmation', async () => {
  await assertSucceeds(declaration('tamper'));
  await assertFails(confirmation('tamper', 'receiver', 5000, { declaredBani: 1 }));
});
test('confirmation cannot omit audit', async () => {
  await assertSucceeds(declaration('no-audit'));
  await assertFails(updateDoc(doc(db('receiver'), path('no-audit')), {
    receivedBani: 5000, status: 'received', revision: 1, updatedAt: serverTimestamp(),
  }));
});
test('receiver cannot delete settlement', async () => {
  await assertSucceeds(declaration('no-delete'));
  await assertFails(deleteDoc(doc(db('receiver'), path('no-delete'))));
});

