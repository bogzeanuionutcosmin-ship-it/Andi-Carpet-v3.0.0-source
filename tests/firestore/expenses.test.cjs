const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc } = require('firebase/firestore');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const expenseRef = (firestore, id) => doc(firestore, 'expenses', id);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const adminDb = ctx.firestore();
    await Promise.all([
      setDoc(doc(adminDb, 'users/writer'), {
        active: true, role: 'worker', effectivePermissions: ['viewOwnDecont'],
      }),
      setDoc(doc(adminDb, 'users/finance-writer'), {
        active: true, role: 'worker', effectivePermissions: ['viewOwnDecont'],
      }),
      setDoc(doc(adminDb, 'users/member-no-finance'), {
        active: true, role: 'worker', effectivePermissions: [],
      }),
      setDoc(doc(adminDb, 'users/outsider'), {
        active: true, role: 'worker', effectivePermissions: ['viewOwnDecont'],
      }),
      setDoc(doc(adminDb, 'teams/team-a'), { members: ['writer', 'finance-writer', 'member-no-finance'] }),
      setDoc(doc(adminDb, 'settlements/settlement-a'), { teamId: 'team-a', managerId: 'writer' }),
      setDoc(doc(adminDb, 'teams/team-b'), { members: ['outsider'] }),
    ]);
  });
});

after(async () => { if (env) await env.cleanup(); });

function expense(teamId) {
  return {
    teamId,
    settlementId: 'settlement-a',
    category: 'Combustibil',
    description: 'Test receipt',
    amount: 12.5,
    documentType: 'fiscalReceipt',
    documentNumber: 'TEST-001',
    supplier: 'Test supplier',
    confirmed: false,
  };
}

test('team finance writer can create an expense without a per-diem distributedBy field', async () => {
  await assertSucceeds(setDoc(expenseRef(db('writer'), 'expense-authorized'), expense('team-a')));
});

test('expense creation still requires finance permission and team membership', async () => {
  await assertFails(setDoc(expenseRef(db('member-no-finance'), 'expense-no-permission'), expense('team-a')));
  await assertFails(setDoc(expenseRef(db('outsider'), 'expense-other-team'), expense('team-a')));
});

test('assigned finance manager can change only the confirmation fields', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(expenseRef(ctx.firestore(), 'expense-to-confirm'), expense('team-a'));
  });
  await assertSucceeds(updateDoc(expenseRef(db('writer'), 'expense-to-confirm'), {
    confirmed: true, updatedAt: new Date('2026-10-23T08:00:00Z'),
  }));
  await assertFails(updateDoc(expenseRef(db('writer'), 'expense-to-confirm'), {
    amount: 999,
  }));
});

test('other finance writers cannot confirm another member expense', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(expenseRef(ctx.firestore(), 'expense-not-manager'), expense('team-a'));
  });
  await assertFails(updateDoc(expenseRef(db('finance-writer'), 'expense-not-manager'), {
    confirmed: true, updatedAt: new Date('2026-10-23T08:00:00Z'),
  }));
});
