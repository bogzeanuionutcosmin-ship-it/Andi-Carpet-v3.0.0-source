// CHARACTERIZATION ONLY — ISSUE #32. These tests document current vulnerabilities,
// not a security policy; several assertSucceeds statements prove operations that must
// eventually be denied after the approved finance rules remediation.
// Synthetic accounts/data, Firebase emulator only. No production access.
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, serverTimestamp, updateDoc } = require('firebase/firestore');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const { setDoc } = require('firebase/firestore');
    for (const [uid, role] of [
      ['expense-ocr-admin', 'admin'],
      ['expense-ocr-member', 'member'],
      ['expense-ocr-outsider', 'member'],
    ]) {
      await setDoc(doc(ctx.firestore(), 'users', uid), {
        active: true, role,
        ...(role === 'member' ? { effectivePermissions: ['viewOwnDecont'] } : {}),
      });
    }
    // Boundary fixtures: inactive member, read-only director, and developer are
    // distinct from the admin role. No real accounts or production data used.
    for (const [uid, data] of [
      ['expense-ocr-inactive', {
        active: false, role: 'member', effectivePermissions: ['viewOwnDecont'],
      }],
      ['expense-ocr-director', {
        active: true, role: 'member', function: 'director',
        effectivePermissions: ['viewOtherDecont'],
      }],
      ['expense-ocr-developer', {
        active: true, role: 'member', function: 'developer',
        effectivePermissions: [],
      }],
    ]) {
      await setDoc(doc(ctx.firestore(), 'users', uid), data);
    }
    await setDoc(doc(ctx.firestore(), 'teams', 'expense-ocr-team'), {
      members: ['expense-ocr-member', 'expense-ocr-inactive'],
    });
  });
  // Seed additional boundary documents AFTER initializeTestEnvironment, never in
  // a separate top-level before() hook (hook registration is not ordered).
  await seedBoundaryDocuments();
});
after(async () => { if (env) await env.cleanup(); });

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
  const path = 'finance/expense-ocr-team';
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
  const path = 'finance/expense-ocr-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), { teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin' });
  });
  await assertFails(updateDoc(doc(db('expense-ocr-outsider'), path), { managerId: 'expense-ocr-outsider' }));
});


test('finance characterization: another team user can be nominated as manager', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'finance/expense-ocr-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), {
      teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
    });
  });
  // Current server rule validates who writes, not whether the nominee belongs to this team.
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    managerId: 'expense-ocr-outsider',
  }));
});

test('finance characterization: teammate can overwrite received money', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'finance/expense-ocr-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), {
      teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
      receivedDeparture: 10,
    });
  });
  // Regression characterization of existing overly broad update, not the desired policy.
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    receivedDeparture: 99999,
  }));
});

test('settlements characterization: member can reopen a closed decont directly', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'settlements/expense-ocr-closed-settlement';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), {
      teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
      closed: true, name: 'Decont de test închis',
    });
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    closed: false,
  }));
});

test('expenses characterization: member can reverse confirmation and rewrite amount', async () => {
  const { setDoc } = require('firebase/firestore');
  const path = 'expenses/expense-ocr-confirmed-existing';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), {
      ...expenseOcrPayload(), confirmed: true, amount: 1234.56,
    });
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    confirmed: false, amount: 1,
  }));
});

test('expenses characterization: current create rule does not validate positive amount', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(
    doc(db('expense-ocr-member'), 'expenses/expense-ocr-negative-probe'),
    {
      ...expenseOcrPayload(),
      distributedBy: 'expense-ocr-member', amount: -10, confirmed: true,
    },
  ));
});


// ISSUE #32 — authorization boundaries. These are *currently denied* cases;
// unlike the preceding vulnerability proofs, GREEN here means the baseline
// rejected the attempted operation in the Firestore rules emulator.
// These tests do not assert that the entire finance policy is safe.
async function seedBoundaryDocuments() {
  const { setDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    const storage = ctx.firestore();
    await setDoc(doc(storage, 'expenses/expense-ocr-boundary'), {
      ...expenseOcrPayload(), confirmed: false,
    });
    await setDoc(doc(storage, 'finance/expense-ocr-team'), {
      teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
      receivedDeparture: 10,
    });
    await setDoc(doc(storage, 'settlements/expense-ocr-boundary'), {
      teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin', closed: true,
    });
  });
}

test('inactive team member: cannot read its team expense', async () => {
  const { getDoc } = require('firebase/firestore');
  await assertFails(getDoc(doc(db('expense-ocr-inactive'), 'expenses/expense-ocr-boundary')));
});

test('inactive team member: cannot alter an expense even while listed in team', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-inactive'), 'expenses/expense-ocr-boundary'), {
    amount: 0, confirmed: true,
  }));
});

test('inactive team member: cannot create an expense with forged distributedBy', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertFails(setDoc(doc(db('expense-ocr-inactive'), 'expenses/expense-ocr-inactive-create'), {
    ...expenseOcrPayload(), distributedBy: 'expense-ocr-inactive',
  }));
});

test('inactive team member: cannot overwrite finance even when it belonged to team', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-inactive'), 'finance/expense-ocr-team'), {
    managerId: 'expense-ocr-inactive',
  }));
});

test('inactive team member: cannot reopen a settlement', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-inactive'), 'settlements/expense-ocr-boundary'), {
    closed: false,
  }));
});

test('director permission: can read expense outside own team', async () => {
  const { getDoc } = require('firebase/firestore');
  await assertSucceeds(getDoc(doc(db('expense-ocr-director'), 'expenses/expense-ocr-boundary')));
});

test('director permission: can read finance outside own team', async () => {
  const { getDoc } = require('firebase/firestore');
  await assertSucceeds(getDoc(doc(db('expense-ocr-director'), 'finance/expense-ocr-team')));
});

test('director permission: can read settlement outside own team', async () => {
  const { getDoc } = require('firebase/firestore');
  await assertSucceeds(getDoc(doc(db('expense-ocr-director'), 'settlements/expense-ocr-boundary')));
});

test('director permission: cannot alter an expense without team edit rights', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-director'), 'expenses/expense-ocr-boundary'), {
    amount: 0, confirmed: true,
  }));
});

test('director permission: cannot replace the finance manager', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-director'), 'finance/expense-ocr-team'), {
    managerId: 'expense-ocr-director',
  }));
});

test('director permission: cannot reopen a team settlement', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-director'), 'settlements/expense-ocr-boundary'), {
    closed: false,
  }));
});

test('developer profession is not admin: cannot read another team expense', async () => {
  const { getDoc } = require('firebase/firestore');
  await assertFails(getDoc(doc(db('expense-ocr-developer'), 'expenses/expense-ocr-boundary')));
});

test('developer profession is not admin: cannot change another team manager', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-developer'), 'finance/expense-ocr-team'), {
    managerId: 'expense-ocr-developer',
  }));
});

test('non-admin member cannot delete its own team expense', async () => {
  const { deleteDoc } = require('firebase/firestore');
  await assertFails(deleteDoc(doc(db('expense-ocr-member'), 'expenses/expense-ocr-boundary')));
});
