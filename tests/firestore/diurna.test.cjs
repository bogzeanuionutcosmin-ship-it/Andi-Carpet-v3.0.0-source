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
    await setDoc(doc(ctx.firestore(), 'users', 'expense-ocr-admin'), {
      active: true, role: 'admin',
    });
    await setDoc(doc(ctx.firestore(), 'users', 'expense-ocr-member'), {
      active: true, role: 'member', effectivePermissions: ['viewOwnDecont'],
    });
    await setDoc(doc(ctx.firestore(), 'users', 'expense-ocr-outsider'), {
      active: true, role: 'member', effectivePermissions: ['viewOwnDecont'],
    });
    await setDoc(doc(ctx.firestore(), 'teams', 'expense-ocr-team'), {
      members: ['expense-ocr-member'],
    });
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


// Contractul ACTUAL al regulilor pentru cheltuieli OCR, nu remedierea lui:
// payloadul real _expenseMap nu include distributedBy, deși create non-admin îl cere.
// Modificarea contractului financiar necesită PR separat și aprobare explicită.
function expenseOcrPayload() {
  return {
    teamId: 'expense-ocr-team', settlementId: null,
    category: 'Combustibil', description: 'Test OCR sintetic',
    amount: 1234.56, date: serverTimestamp(),
    documentType: 'fiscalReceipt', documentNumber: 'TEST-EXP-123',
    supplier: 'TEST SRL', liters: null, pricePerLiter: null,
    documentImageBase64: '', imageFingerprint: 'synthetic-fingerprint',
    ocrRawText: '', ocrConfidence: 0.9, confirmed: false,
    updatedAt: serverTimestamp(),
  };
}

test('expenses OCR: admin poate salva payloadul curent fără distributedBy', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(doc(db('expense-ocr-admin'), 'expenses/expense-ocr-admin-save'),
    expenseOcrPayload(), { merge: true }));
});

test('expenses OCR: un membru cu viewOwnDecont primește deny pentru payloadul curent', async () => {
  const { setDoc } = require('firebase/firestore');
  // Reproducere controlată a incompatibilității cunoscute, nu rezultat dorit.
  await assertFails(setDoc(doc(db('expense-ocr-member'), 'expenses/expense-ocr-current'),
    expenseOcrPayload(), { merge: true }));
});

test('expenses OCR: distributedBy == uid trece condiția prezentă; câmpul nu există în DTO', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(doc(db('expense-ocr-member'), 'expenses/expense-ocr-probe'),
    { ...expenseOcrPayload(), distributedBy: 'expense-ocr-member' }, { merge: true }));
});

test('expenses OCR: membru din altă echipă nu poate salva prin distributedBy fals', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertFails(setDoc(doc(db('expense-ocr-outsider'), 'expenses/expense-ocr-forgery'),
    { ...expenseOcrPayload(), distributedBy: 'expense-ocr-outsider' }, { merge: true }));
});


test('expenses update: colegul cu viewOwnDecont poate schimba amount și confirmed (regula actuală)', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'expenses/expense-ocr-existing-teammate';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), expenseOcrPayload());
  });
  // Contractul actual acceptă schimbarea sumei și confirmarea din SDK direct.
  // Acesta este un defect de autorizare documentat, NU permisiunea dorită.
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    amount: 999.99, confirmed: true,
  }));
});

test('expenses update: altă echipă nu poate modifica cheltuiala', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'expenses/expense-ocr-existing-outsider';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), expenseOcrPayload());
  });
  await assertFails(updateDoc(doc(db('expense-ocr-outsider'), path), {
    amount: 999.99, confirmed: true,
  }));
});

test('expenses update: colegul nu poate muta cheltuiala în afara echipei', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'expenses/expense-ocr-existing-move';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), expenseOcrPayload());
  });
  await assertFails(updateDoc(doc(db('expense-ocr-member'), path), {
    teamId: 'another-team',
  }));
});

test('expenses create: creatorul poate seta confirmed direct în payloadul permis acum', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(
    doc(db('expense-ocr-member'), 'expenses/expense-ocr-self-confirm'),
    { ...expenseOcrPayload(), distributedBy: 'expense-ocr-member', confirmed: true },
    { merge: true },
  ));
});


test('managerId registration characterization: finance team member can edit manager field today', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'finance/expense-ocr-manager-check';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), { teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin' });
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), { managerId: 'expense-ocr-member' }));
});

test('managerId registration characterization: settlement team member can edit manager field today', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'settlements/expense-ocr-manager-check';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), { teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin' });
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), { managerId: 'expense-ocr-member' }));
});

test('managerId registration characterization: unrelated user cannot edit finance manager field', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'finance/expense-ocr-outsider-check';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), { teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin' });
  });
  await assertFails(updateDoc(doc(db('expense-ocr-outsider'), path), { managerId: 'expense-ocr-outsider' }));
});
