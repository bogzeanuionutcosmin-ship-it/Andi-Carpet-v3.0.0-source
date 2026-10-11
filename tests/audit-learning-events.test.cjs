const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-events', member: 'member-events', other: 'other-events' };
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
    batch.set(store.doc('audit/existing'), { actorUid: ids.member, action: 'test' });
    batch.set(store.doc('learningEvents/existing'), { actorUid: ids.member, action: 'learn' });
    batch.set(store.doc('updateHistory/existing'), { version: '3.0.0' });
    await batch.commit();
  });
});
test('membrul poate crea propriul eveniment de audit', async () => {
  await assertSucceeds(db('member').doc('audit/own').set({ actorUid: ids.member, action: 'opened' }));
});
test('membrul nu poate falsifica actorul în audit', async () => {
  await assertFails(db('member').doc('audit/forged').set({ actorUid: ids.other, action: 'opened' }));
});
test('membrul nu poate citi auditul administrativ', async () => {
  await assertFails(db('member').doc('audit/existing').get());
});
test('administratorul poate citi auditul administrativ', async () => {
  await assertSucceeds(db('admin').doc('audit/existing').get());
});
test('membrul nu poate modifica evenimentele de audit', async () => {
  await assertFails(db('member').doc('audit/existing').update({ action: 'changed' }));
});
test('membrul nu poate șterge evenimentele de audit', async () => {
  await assertFails(db('member').doc('audit/existing').delete());
});
test('membrul poate crea propriul eveniment Learning', async () => {
  await assertSucceeds(db('member').doc('learningEvents/own').set({ actorUid: ids.member, action: 'view' }));
});
test('membrul nu poate falsifica actorul în Learning', async () => {
  await assertFails(db('member').doc('learningEvents/forged').set({ actorUid: ids.other, action: 'view' }));
});
test('membrul poate citi evenimentele Learning', async () => {
  await assertSucceeds(db('member').doc('learningEvents/existing').get());
});
test('membrul nu poate modifica evenimentele Learning', async () => {
  await assertFails(db('member').doc('learningEvents/existing').update({ action: 'changed' }));
});
test('membrul nu poate șterge evenimentele Learning', async () => {
  await assertFails(db('member').doc('learningEvents/existing').delete());
});
test('administratorul poate corecta un eveniment Learning', async () => {
  await assertSucceeds(db('admin').doc('learningEvents/existing').update({ action: 'corrected' }));
});
test('membrul poate citi istoricul actualizărilor', async () => {
  await assertSucceeds(db('member').doc('updateHistory/existing').get());
});
test('membrul nu poate modifica istoricul actualizărilor', async () => {
  await assertFails(db('member').doc('updateHistory/existing').update({ version: 'fake' }));
});
test('administratorul poate modifica istoricul actualizărilor', async () => {
  await assertSucceeds(db('admin').doc('updateHistory/existing').update({ version: '3.0.1' }));
});
