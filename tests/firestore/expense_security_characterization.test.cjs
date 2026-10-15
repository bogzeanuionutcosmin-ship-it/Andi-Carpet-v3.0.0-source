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
      // Legacy director intentionally has no effectivePermissions field.
      // The fallback currently grants every named permission.
      ['expense-ocr-legacy-director', {
        active: true, role: 'member', function: 'director',
      }],
    ]) {
      await setDoc(doc(ctx.firestore(), 'users', uid), data);
    }
    await setDoc(doc(ctx.firestore(), 'teams', 'expense-ocr-team'), {
      members: ['expense-ocr-member', 'expense-ocr-inactive', 'expense-ocr-legacy-director'],
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


// LEGACY ROLE FALLBACK: Known authorization gap, characterized as
// assertSucceeds deliberately. A director should be read-only under the
// owner's desired finance policy, but function='director' without the newer
// effectivePermissions list currently matches ANY permission in
// hasLegacyPermission(), including viewOwnDecont. These examples require
// same-team membership: do not claim cross-team writes were reproduced.
test('legacy director without effectivePermissions can rewrite own-team expense (unsafe)', async () => {
  await assertSucceeds(updateDoc(
    doc(db('expense-ocr-legacy-director'), 'expenses/expense-ocr-boundary'),
    { amount: 0.01, confirmed: true },
  ));
});

test('legacy director without effectivePermissions can replace own-team managerId (unsafe)', async () => {
  await assertSucceeds(updateDoc(
    doc(db('expense-ocr-legacy-director'), 'finance/expense-ocr-team'),
    { managerId: 'expense-ocr-legacy-director' },
  ));
});

test('legacy director without effectivePermissions can reopen own-team settlement (unsafe)', async () => {
  await assertSucceeds(updateDoc(
    doc(db('expense-ocr-legacy-director'), 'settlements/expense-ocr-boundary'),
    { closed: false },
  ));
});


// FINANCIAL AUTHORIZATION TRANSITIONS — isolated fixture IDs, demo emulator.
// The after-deletion assertions characterize a potentially dangerous legacy
// fallback; SUCCESS for an unauthorized write is intentionally evidence of
// an existing weakness, not approval of the policy.
test('financial access after field deletion: legacy driver permission resurrects', async () => {
  const { setDoc, deleteField } = require('firebase/firestore');
  const actor = 'expense-ocr-revoked-driver';
  const team = 'expense-ocr-revocation-team';
  const expensePath = 'expenses/expense-ocr-revocation-document';
  await env.withSecurityRulesDisabled(async (ctx) => {
    const storage = ctx.firestore();
    await setDoc(doc(storage, 'users/' + actor), {
      active: true, role: 'member', function: 'driver', effectivePermissions: [],
    });
    await setDoc(doc(storage, 'teams/' + team), { members: [actor] });
    await setDoc(doc(storage, expensePath), {
      teamId: team, amount: 100, confirmed: false,
    });
  });
  // Explicit empty list correctly revokes financial edit access.
  await assertFails(updateDoc(doc(db(actor), expensePath), { amount: 101 }));
  // Legacy migration that removes the field can *restore* the broad fallback.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'users/' + actor), {
      effectivePermissions: deleteField(),
    });
  });
  await assertSucceeds(updateDoc(doc(db(actor), expensePath), { amount: 102 }));
  // Server-side team membership check still denies writes after transfer.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'teams/' + team), { members: [] });
  });
  await assertFails(updateDoc(doc(db(actor), expensePath), { amount: 103 }));
});

test('inactive admin role cannot read or overwrite team finance', async () => {
  const { setDoc, getDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/expense-ocr-inactive-admin'), {
      active: false, role: 'admin',
    });
  });
  await assertFails(getDoc(doc(db('expense-ocr-inactive-admin'), 'finance/expense-ocr-team')));
  await assertFails(updateDoc(doc(db('expense-ocr-inactive-admin'), 'finance/expense-ocr-team'), {
    receivedDeparture: 0,
  }));
});

test('member cannot grant self finance permissions or admin role from client', async () => {
  await assertFails(updateDoc(doc(db('expense-ocr-member'), 'users/expense-ocr-member'), {
    role: 'admin',
  }));
  await assertFails(updateDoc(doc(db('expense-ocr-member'), 'users/expense-ocr-member'), {
    effectivePermissions: ['viewOwnDecont', 'viewOtherDecont'],
  }));
});

test('legacy director can read cross-team finance but cannot edit cross-team amounts', async () => {
  const { setDoc, getDoc } = require('firebase/firestore');
  const path = 'expenses/expense-ocr-foreign-expense';
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), {
      teamId: 'expense-ocr-foreign-team', amount: 8, confirmed: false,
    });
  });
  await assertSucceeds(getDoc(doc(db('expense-ocr-legacy-director'), path)));
  await assertFails(updateDoc(doc(db('expense-ocr-legacy-director'), path), { amount: 0 }));
});

test('finance create: member can nominate outsider and arbitrary receipt (unsafe)', async () => {
  const { setDoc } = require('firebase/firestore');
  const actor = 'expense-ocr-finance-creator';
  const team = 'expense-ocr-finance-creator-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    const storage = ctx.firestore();
    await setDoc(doc(storage, 'users/' + actor), {
      active: true, role: 'member', effectivePermissions: ['viewOwnDecont'],
    });
    await setDoc(doc(storage, 'teams/' + team), { members: [actor] });
  });
  await assertSucceeds(setDoc(doc(db(actor), 'finance/' + team), {
    teamId: team, managerId: 'expense-ocr-outsider', receivedDeparture: 99999,
  }));
});

test('finance update: member can falsify teamId inside own finance document (unsafe)', async () => {
  // Dedicated team/actor from previous test already owns this finance path;
  // seed a separate, complete self-contained fixture to avoid test-order coupling.
  const { setDoc } = require('firebase/firestore');
  const actor = 'expense-ocr-finance-spoof';
  const team = 'expense-ocr-finance-spoof-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    const storage = ctx.firestore();
    await setDoc(doc(storage, 'users/' + actor), {
      active: true, role: 'member', effectivePermissions: ['viewOwnDecont'],
    });
    await setDoc(doc(storage, 'teams/' + team), { members: [actor] });
    await setDoc(doc(storage, 'finance/' + team), {
      teamId: team, managerId: actor, receivedDeparture: 0,
    });
  });
  await assertSucceeds(updateDoc(doc(db(actor), 'finance/' + team), {
    teamId: 'expense-ocr-foreign-team',
  }));
});

test('settlements create: ordinary teammate can self-create closed arbitrary settlement (unsafe)', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(
    doc(db('expense-ocr-member'), 'settlements/expense-ocr-self-created-closed'),
    {
      teamId: 'expense-ocr-team', managerId: 'expense-ocr-outsider',
      closed: true, receivedDeparture: 123456,
    },
  ));
});


// ISSUE #32 — supplementary financial field-level characterization.
// Existing viewOwnDecont controls the *whole* update, not just read access.
// Synthetic fixtures only; assertSucceeds means "unsafe write reproduced".
// All paths below have independent IDs to avoid suite-order coupling.
async function seedExpenseFieldProbe(path, overrides = {}) {
  const { setDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), {
      ...expenseOcrPayload(), confirmed: true, amount: 15.20, ...overrides,
    });
  });
}
async function seedFinanceFieldProbe(path, data) {
  const { setDoc } = require('firebase/firestore');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

test('unsafe: teammate can replace confirmed OCR image evidence and document number', async () => {
  const path = 'expenses/expense-ocr-tamper-photo';
  await seedExpenseFieldProbe(path);
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    documentImageBase64: 'SYNTHETIC_REPLACED_IMAGE',
    imageFingerprint: 'synthetic-replaced-fingerprint',
    documentNumber: 'SYNTHETIC_REPLACED_NO',
  }));
});

test('unsafe: teammate can reassign expense to another settlement in same team', async () => {
  const path = 'expenses/expense-ocr-tamper-settlement';
  await seedExpenseFieldProbe(path);
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    settlementId: 'different-synthetic-settlement', description: 'reassigned',
  }));
});

test('unsafe: teammate can forge unvalidated confirmation author and timestamp', async () => {
  const path = 'expenses/expense-ocr-tamper-confirmation-metadata';
  await seedExpenseFieldProbe(path);
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    confirmedBy: 'expense-ocr-member', confirmedAt: serverTimestamp(),
    supplier: 'REPLACED SUPPLIER',
  }));
});

test('unsafe: member can put nonnumeric text in expense amount via update', async () => {
  const path = 'expenses/expense-ocr-tamper-amount-type';
  await seedExpenseFieldProbe(path);
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    amount: 'not-a-number',
  }));
});

test('unsafe: member can replace finance receivedEntries and perDiemRate', async () => {
  const path = 'finance/expense-ocr-team';
  await seedFinanceFieldProbe(path, {
    teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
    receivedDeparture: 10, receivedEntries: [], perDiemRate: 30,
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    receivedEntries: [{ id: 'synthetic-false-receipt', amount: 99999, kind: 'during' }],
    perDiemRate: 99999,
  }));
});

test('unsafe: member can rewrite receivedEntries and perDiemRate in closed settlement', async () => {
  const path = 'settlements/expense-ocr-field-closed';
  await seedFinanceFieldProbe(path, {
    teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
    closed: true, perDiemRate: 30, receivedEntries: [],
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    receivedEntries: [{ id: 'synthetic-closed-receipt', amount: 90000, kind: 'departure' }],
    perDiemRate: 90000,
  }));
});

test('unsafe: expenses create with injected distributedBy permits string amount', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(
    doc(db('expense-ocr-member'), 'expenses/expense-ocr-malformed-create'),
    { ...expenseOcrPayload(), distributedBy: 'expense-ocr-member', amount: 'invalid' },
  ));
});

test('unsafe: explicit director viewing privilege plus viewOwnDecont enables own-team write', async () => {
  const actor = 'expense-ocr-director-dual-permissions';
  const team = 'expense-ocr-director-dual-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    const { setDoc } = require('firebase/firestore');
    const storage = ctx.firestore();
    await setDoc(doc(storage, 'users/' + actor), {
      active: true, role: 'member', function: 'director',
      effectivePermissions: ['viewOtherDecont', 'viewOwnDecont'],
    });
    await setDoc(doc(storage, 'teams/' + team), { members: [actor] });
    await setDoc(doc(storage, 'finance/' + team), {
      teamId: team, managerId: 'expense-ocr-admin', receivedDeparture: 10,
    });
  });
  await assertSucceeds(updateDoc(doc(db(actor), 'finance/' + team), {
    receivedDeparture: 999,
  }));
});

test('managerId claim alone does not authorize finance write without own-decont permission', async () => {
  const actor = 'expense-ocr-manager-without-permission';
  const team = 'expense-ocr-manager-no-permission-team';
  await env.withSecurityRulesDisabled(async (ctx) => {
    const { setDoc } = require('firebase/firestore');
    const storage = ctx.firestore();
    await setDoc(doc(storage, 'users/' + actor), {
      active: true, role: 'member', effectivePermissions: [],
    });
    await setDoc(doc(storage, 'teams/' + team), { members: [actor] });
    await setDoc(doc(storage, 'finance/' + team), {
      teamId: team, managerId: actor, receivedDeparture: 10,
    });
  });
  await assertFails(updateDoc(doc(db(actor), 'finance/' + team), {
    receivedDeparture: 15,
  }));
});


// NONFINITE MONEY — CHARACTERIZATION ONLY. Firestore stores special floating
// point values; the current expense rules have no amount type/finite/range
// validation. An assertSucceeds is evidence of this gap, NOT desired policy.
// All IDs, actors and values are synthetic emulator fixtures.
test('unsafe: expense create accepts NaN amount with forged distributedBy', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(
    doc(db('expense-ocr-member'), 'expenses/expense-ocr-nan-create'),
    { ...expenseOcrPayload(), distributedBy: 'expense-ocr-member', amount: Number.NaN },
  ));
});

test('unsafe: expense create accepts positive Infinity amount with forged distributedBy', async () => {
  const { setDoc } = require('firebase/firestore');
  await assertSucceeds(setDoc(
    doc(db('expense-ocr-member'), 'expenses/expense-ocr-infinity-create'),
    { ...expenseOcrPayload(), distributedBy: 'expense-ocr-member', amount: Number.POSITIVE_INFINITY },
  ));
});

test('unsafe: existing confirmed expense amount can be changed to NaN by teammate', async () => {
  const path = 'expenses/expense-ocr-nan-update';
  await seedExpenseFieldProbe(path);
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    amount: Number.NaN,
  }));
});

test('unsafe: settlement can receive nonfinite receivedEntries values via teammate update', async () => {
  const path = 'settlements/expense-ocr-nonfinite-received';
  await seedFinanceFieldProbe(path, {
    teamId: 'expense-ocr-team', managerId: 'expense-ocr-admin',
    closed: true, receivedEntries: [],
  });
  await assertSucceeds(updateDoc(doc(db('expense-ocr-member'), path), {
    receivedEntries: [{ id: 'synthetic-nonfinite', amount: Number.POSITIVE_INFINITY, kind: 'departure' }],
  }));
});
