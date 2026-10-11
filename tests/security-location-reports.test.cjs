const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-sec', alice: 'alice-sec', bob: 'bob-sec' };
const db = role => env.authenticatedContext(ids[role]).firestore();
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet-rules',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const store = ctx.firestore();
    const batch = store.batch();
    for (const [role, id] of Object.entries(ids)) {
      batch.set(store.doc('users/' + id), {
        active: true, role: role === 'admin' ? 'admin' : 'member',
        effectivePermissions: [],
      });
    }
    batch.set(store.doc('backups/snapshot'), { state: 'saved' });
    batch.set(store.doc('documents/policy'), { title: 'Policy' });
    batch.set(store.doc('liveLocations/' + ids.bob), { lat: 45, lng: 24 });
    batch.set(store.doc('errorReports/report'), { userId: ids.alice, text: 'Issue' });
    await batch.commit();
  });
});
test('utilizatorul poate scrie propria poziție live', async () => {
  await assertSucceeds(db('alice').doc('liveLocations/' + ids.alice).set({ lat: 45, lng: 24 }));
});
test('utilizatorul nu poate modifica poziția altuia', async () => {
  await assertFails(db('alice').doc('liveLocations/' + ids.bob).update({ lat: 47 }));
});
test('membrul activ poate vedea poziția colegului', async () => {
  await assertSucceeds(db('alice').doc('liveLocations/' + ids.bob).get());
});
test('utilizatorul poate crea raport de eroare propriu', async () => {
  await assertSucceeds(db('alice').doc('errorReports/own').set({ userId: ids.alice, text: 'Issue' }));
});
test('utilizatorul nu poate falsifica autorul raportului de eroare', async () => {
  await assertFails(db('alice').doc('errorReports/forged').set({ userId: ids.bob, text: 'Issue' }));
});
test('utilizatorul nu poate citi raportul privat al altuia', async () => {
  await assertFails(db('bob').doc('errorReports/report').get());
});
test('utilizatorul poate trimite sugestie proprie', async () => {
  await assertSucceeds(db('alice').doc('suggestions/own').set({ userId: ids.alice, text: 'Idea' }));
});
test('utilizatorul nu poate trimite sugestie în numele altuia', async () => {
  await assertFails(db('alice').doc('suggestions/forged').set({ userId: ids.bob, text: 'Idea' }));
});
test('membrul nu poate edita documentele administrate central', async () => {
  await assertFails(db('alice').doc('documents/policy').update({ title: 'Changed' }));
});
test('membrul poate citi documentele interne', async () => {
  await assertSucceeds(db('alice').doc('documents/policy').get());
});
test('membrul nu poate accesa backupul', async () => {
  await assertFails(db('alice').doc('backups/snapshot').get());
});
test('administratorul poate accesa backupul', async () => {
  await assertSucceeds(db('admin').doc('backups/snapshot').get());
});
test('membrul nu poate scrie istoricul actualizărilor', async () => {
  await assertFails(db('alice').doc('updateHistory/new').set({ version: '3.0.4' }));
});
test('administratorul poate scrie istoricul actualizărilor', async () => {
  await assertSucceeds(db('admin').doc('updateHistory/new').set({ version: '3.0.4' }));
});
test('membrul nu poate modifica setările globale', async () => {
  await assertFails(db('alice').doc('meta/uiSettings').set({ theme: 'green' }));
});
