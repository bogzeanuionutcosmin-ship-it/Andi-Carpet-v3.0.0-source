const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');

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
      setDoc(doc(adminDb, 'users/member-no-finance'), {
        active: true, role: 'worker', effectivePermissions: [],
      }),
      setDoc(doc(adminDb, 'users/outsider'), {
        active: true, role: 'worker', effectivePermissions: ['viewOwnDecont'],
      }),
      setDoc(doc(adminDb, 'teams/team-a'), { members: ['writer', 'member-no-finance'] }),
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
