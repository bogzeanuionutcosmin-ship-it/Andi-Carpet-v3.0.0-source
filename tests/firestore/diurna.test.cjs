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
    await setDoc(doc(ctx.firestore(), 'users', 'craiova-admin'), { active: true, role: 'admin' });
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


test('legacy perDiems: beneficiary can confirm a positive received amount', async () => {
  const { setDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'perDiems', 'legacy-valid'), {
      memberId: 'receiver', distributedBy: 'payer', teamId: 'team-a',
      amount: 50, status: 'awaitingConfirmation',
      actualReceivedAmount: null, received: false,
    });
  });
  await assertSucceeds(updateDoc(doc(db('receiver'), 'perDiems/legacy-valid'), {
    status: 'confirmed', received: true, actualReceivedAmount: 50,
  }));
});

test('legacy perDiems: unrelated member cannot confirm receipt', async () => {
  const { setDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'perDiems', 'legacy-stranger'), {
      memberId: 'receiver', distributedBy: 'payer', teamId: 'team-a',
      amount: 50, status: 'awaitingConfirmation',
      actualReceivedAmount: null, received: false,
    });
  });
  await assertFails(updateDoc(doc(db('stranger'), 'perDiems/legacy-stranger'), {
    status: 'confirmed', received: true, actualReceivedAmount: 50,
  }));
});

test('legacy perDiems: characterize currently allowed over-declared receipt', async () => {
  const { setDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'perDiems', 'legacy-overdeclared'), {
      memberId: 'receiver', distributedBy: 'payer', teamId: 'team-a',
      amount: 50, status: 'awaitingConfirmation',
      actualReceivedAmount: null, received: false,
    });
  });
  // Characterization, not approval: legacy rules do not cap actualReceivedAmount.
  // A product decision is required before changing accounting behavior.
  await assertSucceeds(updateDoc(doc(db('receiver'), 'perDiems/legacy-overdeclared'), {
    status: 'confirmed', received: true, actualReceivedAmount: 75,
  }));
});


// Craiova regression: synthetic executions only, no production Firebase data.
test('Craiova: 11 execution IDs survive 5/6 planned -> 6/5 actual date correction', async () => {
  const { setDoc, runTransaction, Timestamp, getDocs, collection } = require('firebase/firestore');
  const ids = Array.from({ length: 11 }, (_, i) => `craiova-test-${i + 1}`);
  const plan = ids.map((_, i) => i < 5 ? 5 : 6);
  const actual = ids.map((_, i) => i < 6 ? 5 : 6);
  assert.deepEqual([plan.filter(x => x === 5).length, plan.filter(x => x === 6).length], [5, 6]);
  await env.withSecurityRulesDisabled(async ctx => {
    const database = ctx.firestore();
    for (let i = 0; i < ids.length; i++) {
      await setDoc(doc(database, 'records', ids[i]), {
        teamId: 'craiova-team', locationId: `room-${i + 1}`,
        type: 'million', status: 'completed',
        startedAt: Timestamp.fromDate(new Date(Date.UTC(2026, 9, plan[i], 7))),
        finishedAt: Timestamp.fromDate(new Date(Date.UTC(2026, 9, plan[i], 8))),
        facadeDone: false,
      });
    }
  });
  const database = db('craiova-admin');
  for (let i = 0; i < ids.length; i++) {
    const ref = doc(database, 'records', ids[i]);
    await assertSucceeds(runTransaction(database, async tx => {
      const snapshot = await tx.get(ref);
      assert.equal(snapshot.exists(), true);
      tx.update(ref, {
        startedAt: Timestamp.fromDate(new Date(Date.UTC(2026, 9, actual[i], 7))),
        finishedAt: Timestamp.fromDate(new Date(Date.UTC(2026, 9, actual[i], 8))),
      });
    }));
  }
  const result = await getDocs(collection(database, 'records'));
  const craiova = result.docs.filter(d => ids.includes(d.id));
  assert.equal(craiova.length, 11, 'correction must not insert extra records');
  assert.equal(new Set(craiova.map(d => d.id)).size, 11);
  assert.deepEqual([
    craiova.filter(d => d.data().startedAt.toDate().getUTCDate() === 5).length,
    craiova.filter(d => d.data().startedAt.toDate().getUTCDate() === 6).length,
  ], [6, 5]);
});

test('Craiova: deleted intervention is not recreated by transactional correction', async () => {
  const { setDoc, runTransaction } = require('firebase/firestore');
  const database = db('craiova-admin');
  const ref = doc(database, 'records', 'craiova-deleted');
  await assertSucceeds(setDoc(ref, { teamId:'craiova-team', locationId:'room-deleted', status:'completed' }));
  await assertSucceeds(deleteDoc(ref));
  await assert.rejects(runTransaction(database, async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error('record deleted');
    tx.update(ref, { facadeDone: true });
  }), /record deleted/);
  assert.equal((await getDoc(ref)).exists(), false);
});

test('Craiova: stale correction rejects concurrent changes', async () => {
  const { setDoc, runTransaction } = require('firebase/firestore');
  const database = db('craiova-admin');
  const ref = doc(database, 'records', 'craiova-stale');
  await assertSucceeds(setDoc(ref, { teamId:'craiova-team', locationId:'room-stale', status:'completed', facadeDone:false }));
  const original = (await getDoc(ref)).data();
  await assertSucceeds(updateDoc(ref, { facadeDone:true }));
  await assert.rejects(runTransaction(database, async tx => {
    const snap = await tx.get(ref);
    if (snap.data().facadeDone !== original.facadeDone) throw new Error('stale correction');
    tx.update(ref, { facadeDone:false });
  }), /stale correction/);
  assert.equal((await getDoc(ref)).data().facadeDone, true);
});
