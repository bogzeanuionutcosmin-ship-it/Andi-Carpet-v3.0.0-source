const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-perdiem', manager: 'manager-perdiem', worker: 'worker-perdiem', outsider: 'outsider-perdiem' };
const db = (role) => env.authenticatedContext(ids[role]).firestore();
const diem = (overrides = {}) => ({
  teamId: 'team-1', memberId: ids.worker, distributedBy: ids.manager,
  amount: 100, status: 'awaitingConfirmation', actualReceivedAmount: null,
  ...overrides,
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
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    const batch = store.batch();
    for (const [role, id] of Object.entries(ids)) {
      batch.set(store.doc('users/' + id), {
        active: true, role: role === 'admin' ? 'admin' : 'member',
        function: 'developer', effectivePermissions: role === 'manager' ? ['viewOwnDecont'] : [],
      });
    }
    batch.set(store.doc('teams/team-1'), { members: [ids.manager, ids.worker] });
    batch.set(store.doc('finance/team-1'), { teamId: 'team-1', managerId: ids.manager, receivedDuring: 0 });
    await batch.commit();
  });
});
test('gestionarul desemnat poate distribui diurna', async () => {
  await assertSucceeds(db('manager').doc('perDiems/valid').set(diem()));
});
test('lucrătorul nu poate distribui în numele gestionarului', async () => {
  await assertFails(db('worker').doc('perDiems/forged').set(diem()));
});
test('persoana din afara echipei nu poate distribui diurna', async () => {
  await assertFails(db('outsider').doc('perDiems/outsider').set(diem({ distributedBy: ids.outsider })));
});
test('nu se poate distribui o diurnă negativă', async () => {
  await assertFails(db('manager').doc('perDiems/negative').set(diem({ amount: -100 })));
});
test('beneficiarul poate confirma suma primită', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/confirm').set(diem());
  });
  await assertSucceeds(db('worker').doc('perDiems/confirm').update({
    status: 'confirmed', received: true, actualReceivedAmount: 100,
  }));
});
test('gestionarul nu poate confirma în numele beneficiarului', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/forged-confirm').set(diem());
  });
  await assertFails(db('manager').doc('perDiems/forged-confirm').update({
    status: 'confirmed', received: true, actualReceivedAmount: 100,
  }));
});
test('beneficiarul nu poate modifica suma declarată la confirmare', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/alter-amount').set(diem());
  });
  await assertFails(db('worker').doc('perDiems/alter-amount').update({
    amount: 500, status: 'confirmed', received: true, actualReceivedAmount: 100,
  }));
});
test('gestionarul poate actualiza încasările financiare permise', async () => {
  await assertSucceeds(db('manager').doc('finance/team-1').update({ receivedDuring: 200 }));
});
test('lucrătorul nu poate modifica încasările gestionarului', async () => {
  await assertFails(db('worker').doc('finance/team-1').update({ receivedDuring: 200 }));
});
test('gestionarul nu poate schimba singur identitatea gestionarului', async () => {
  await assertFails(db('manager').doc('finance/team-1').update({ managerId: ids.worker }));
});


test('beneficiarul nu poate confirma diurna cu sumă zero', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/zero-confirm').set(diem());
  });
  await assertFails(db('worker').doc('perDiems/zero-confirm').update({
    status: 'confirmed', received: true, actualReceivedAmount: 0,
  }));
});
test('beneficiarul nu poate confirma diurna de două ori', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/double-confirm').set(diem({
      status: 'confirmed', received: true, actualReceivedAmount: 100,
    }));
  });
  await assertFails(db('worker').doc('perDiems/double-confirm').update({
    actualReceivedAmount: 200,
  }));
});
test('gestionarul nu poate distribui diurnă cu status deja confirmat', async () => {
  await assertFails(db('manager').doc('perDiems/early-confirm').set(diem({
    status: 'confirmed', actualReceivedAmount: 100,
  })));
});
test('lucrătorul nu poate șterge diurna', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/delete-worker').set(diem());
  });
  await assertFails(db('worker').doc('perDiems/delete-worker').delete());
});
test('gestionarul nu poate șterge diurna fără drepturi admin', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/delete-manager').set(diem());
  });
  await assertFails(db('manager').doc('perDiems/delete-manager').delete());
});
test('beneficiarul nu poate crea contestație în numele distribuitorului', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/dispute-worker').set(diem({
      status: 'confirmed', actualReceivedAmount: 50,
    }));
  });
  await assertFails(db('worker').doc('perDiemDisputes/dispute-worker').set({
    perDiemId: 'dispute-worker', distributorId: ids.manager,
    beneficiaryId: ids.worker, declaredBani: 10000, receivedBani: 5000,
    status: 'disputed', reason: 'Diferență', actorUid: ids.worker,
  }));
});
test('gestionarul poate deschide contestație justificată', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/dispute-manager').set(diem({
      status: 'confirmed', actualReceivedAmount: 50,
    }));
  });
  await assertSucceeds(db('manager').doc('perDiemDisputes/dispute-manager').set({
    perDiemId: 'dispute-manager', distributorId: ids.manager,
    beneficiaryId: ids.worker, declaredBani: 10000, receivedBani: 5000,
    status: 'disputed', reason: 'Diferență de sumă', actorUid: ids.manager,
  }));
});
test('gestionarul nu poate deschide contestație fără motiv', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiems/dispute-empty').set(diem({
      status: 'confirmed', actualReceivedAmount: 50,
    }));
  });
  await assertFails(db('manager').doc('perDiemDisputes/dispute-empty').set({
    perDiemId: 'dispute-empty', distributorId: ids.manager,
    beneficiaryId: ids.worker, declaredBani: 10000, receivedBani: 5000,
    status: 'disputed', reason: '', actorUid: ids.manager,
  }));
});
test('doar administratorul poate soluționa contestația', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('perDiemDisputes/resolve').set({
      status: 'disputed', distributorId: ids.manager, beneficiaryId: ids.worker,
    });
  });
  await assertFails(db('manager').doc('perDiemDisputes/resolve').update({
    status: 'resolved_accepted', resolvedBy: ids.manager,
  }));
  await assertSucceeds(db('admin').doc('perDiemDisputes/resolve').update({
    status: 'resolved_accepted', resolvedBy: ids.admin,
  }));
});
