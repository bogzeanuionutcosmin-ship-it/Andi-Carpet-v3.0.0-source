const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('node:fs');
const { test } = require('node:test');

test('financial roles and protected writes', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet-rules',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  try {
    await env.withSecurityRulesDisabled(async ctx => {
      const db = ctx.firestore();
      await db.doc('users/admin').set({ active: true, role: 'admin' });
      for (const uid of ['manager', 'worker', 'outsider']) {
        await db.doc('users/' + uid).set({
          active: true, role: 'member', function: 'worker',
          effectivePermissions: ['viewOwnDecont', 'editProgram'],
        });
      }
      await db.doc('teams/team1').set({ members: ['manager', 'worker'] });
      await db.doc('finance/team1').set({ teamId: 'team1', managerId: 'manager' });
      await db.doc('settlements/trip1').set({
        teamId: 'team1', name: 'Test trip', managerId: 'manager',
        receivedDeparture: 0, receivedDuring: 0,
      });
    });
    const db = uid => env.authenticatedContext(uid).firestore();
    const diem = uid => ({
      teamId: 'team1', memberId: 'worker', distributedBy: uid,
      amount: 50, status: 'awaitingConfirmation', actualReceivedAmount: null,
    });
    await assertFails(db('worker').doc('perDiems/worker-diem').set(diem('worker')));
    await assertSucceeds(db('manager').doc('perDiems/manager-diem').set(diem('manager')));
    await assertSucceeds(db('admin').doc('perDiems/admin-diem').set(diem('admin')));
    await assertFails(db('outsider').doc('perDiems/outsider-diem').set(diem('outsider')));

    const expense = uid => ({
      teamId: 'team1', settlementId: 'trip1', createdBy: uid,
      amount: 75, confirmed: false, reviewStatus: 'pending',
    });
    await assertSucceeds(db('worker').doc('expenses/pending').set(expense('worker')));
    await assertFails(db('worker').doc('expenses/forged').set({
      ...expense('worker'), confirmed: true,
    }));
    await assertFails(db('worker').doc('expenses/forged-review').set({
      ...expense('worker'), reviewStatus: 'approved',
    }));
    await assertSucceeds(db('manager').doc('expenses/pending').update({
      confirmed: true, reviewStatus: 'approved',
    }));
    await assertFails(db('worker').doc('expenses/pending').update({ amount: 500 }));
    await assertFails(db('outsider').doc('expenses/outsider').set(expense('outsider')));

    await assertSucceeds(db('worker').doc('settlements/trip1').update({ name: 'Updated itinerary' }));
    await assertFails(db('worker').doc('settlements/trip1').update({ receivedDeparture: 900 }));
    await assertSucceeds(db('manager').doc('settlements/trip1').update({ receivedDeparture: 100 }));
    await assertFails(db('worker').doc('finance/team1').update({ managerId: 'worker' }));
    await assertSucceeds(db('admin').doc('finance/team1').update({ managerId: 'worker' }));
  } finally {
    await env.cleanup();
  }
});
