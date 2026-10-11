const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

let env;
const user = (id) => env.authenticatedContext(id).firestore();
const doc = (id, path) => user(id).doc(path);
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
    const db = ctx.firestore();
    await Promise.all([
      db.doc('users/admin').set({ role: 'admin', active: true }),
      db.doc('users/worker').set({ role: 'member', active: true, effectivePermissions: ['viewDashboard', 'viewProgram', 'viewMap'] }),
      db.doc('users/inactive').set({ role: 'member', active: false }),
      db.doc('users/outsider').set({ role: 'member', active: true }),
    ]);
  });
});

const readCases = [
  ['locations', 'site'], ['locationCategories', 'category'], ['backgrounds', 'theme'],
  ['functions', 'worker'], ['teams', 'team'], ['cars', 'car'],
  ['schedules', 'shift'], ['records', 'record'], ['documents', 'document'],
  ['learningEvents', 'event'], ['updateHistory', 'version'], ['liveLocations', 'worker'],
];
for (const [collection, id] of readCases) {
  test(collection + ': membrul activ poate citi, contul inactiv nu poate', async () => {
    const path = collection + '/' + id;
    await env.withSecurityRulesDisabled(ctx => ctx.firestore().doc(path).set({ name: 'test' }));
    await assertSucceeds(doc('worker', path).get());
    await assertFails(doc('inactive', path).get());
  });
}

const adminOnlyWrite = [
  ['locations', 'site'], ['locationCategories', 'category'], ['backgrounds', 'theme'],
  ['functions', 'function'], ['teams', 'team'], ['cars', 'car'],
  ['documents', 'document'], ['updateHistory', 'version'],
];
for (const [collection, id] of adminOnlyWrite) {
  test(collection + ': numai administratorul poate crea documente', async () => {
    const path = collection + '/' + id;
    await assertFails(doc('worker', path).set({ name: 'new' }));
    await assertSucceeds(doc('admin', path).set({ name: 'new' }));
  });
}

test('profil: membrul își poate modifica numele, dar nu rolul', async () => {
  await assertSucceeds(doc('worker', 'users/worker').update({ name: 'Test Worker' }));
  await assertFails(doc('worker', 'users/worker').update({ role: 'admin' }));
  await assertFails(doc('worker', 'users/admin').update({ name: 'Intruder' }));
});

test('notificări: destinatarul poate marca drept citit, nu poate schimba destinatarul', async () => {
  const path = 'notifications/notice';
  await env.withSecurityRulesDisabled(ctx => ctx.firestore().doc(path).set({
    userId: 'worker', title: 'Test', message: 'Test', read: false,
  }));
  await assertSucceeds(doc('worker', path).update({ read: true }));
  await assertFails(doc('worker', path).update({ userId: 'outsider' }));
  await assertFails(doc('outsider', path).get());
});

test('locație live: membrul poate scrie doar poziția proprie', async () => {
  await assertSucceeds(doc('worker', 'liveLocations/worker').set({ latitude: 45, longitude: 24 }));
  await assertFails(doc('worker', 'liveLocations/outsider').set({ latitude: 45, longitude: 24 }));
  await assertSucceeds(doc('outsider', 'liveLocations/worker').get());
});

test('token push: fiecare utilizator controlează numai tokenurile proprii', async () => {
  await assertSucceeds(doc('worker', 'users/worker/pushTokens/device').set({ token: 'fake' }));
  await assertFails(doc('outsider', 'users/worker/pushTokens/device').get());
  await assertFails(doc('admin', 'users/worker/pushTokens/device').delete());
});

test('colecție necunoscută: administratorul nu poate ocoli restricția implicită', async () => {
  await assertFails(doc('admin', 'unexpectedCollection/item').set({ value: true }));
  await assertFails(doc('admin', 'unexpectedCollection/item').get());
});
