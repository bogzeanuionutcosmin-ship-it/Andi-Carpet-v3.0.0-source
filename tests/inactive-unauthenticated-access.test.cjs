const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const activeId = 'active-edge', inactiveId = 'inactive-edge', adminId = 'admin-edge';
const db = id => env.authenticatedContext(id).firestore();
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
    batch.set(store.doc('users/' + activeId), { active: true, role: 'member', effectivePermissions: [] });
    batch.set(store.doc('users/' + inactiveId), { active: false, role: 'member', effectivePermissions: [] });
    batch.set(store.doc('users/' + adminId), { active: true, role: 'admin', effectivePermissions: [] });
    batch.set(store.doc('memberDirectory/' + activeId), { name: 'Active' });
    batch.set(store.doc('locations/site'), { name: 'Site' });
    batch.set(store.doc('documents/doc'), { title: 'Internal' });
    batch.set(store.doc('groupChatMessages/msg'), {
      senderId: activeId, senderName: 'Active', senderPhotoBase64: '',
      text: 'Salut', createdAt: new Date(),
    });
    batch.set(store.doc('notifications/notice'), {
      userId: activeId, title: 'Alertă', message: 'Mesaj', read: false,
    });
    await batch.commit();
  });
});
test('contul inactiv nu poate citi directorul membrilor', async () => {
  await assertFails(db(inactiveId).doc('memberDirectory/' + activeId).get());
});
test('contul inactiv nu poate citi locațiile', async () => {
  await assertFails(db(inactiveId).doc('locations/site').get());
});
test('contul inactiv nu poate citi documentele interne', async () => {
  await assertFails(db(inactiveId).doc('documents/doc').get());
});
test('contul inactiv nu poate citi chatul de grup', async () => {
  await assertFails(db(inactiveId).doc('groupChatMessages/msg').get());
});
test('contul inactiv nu poate trimite mesaje în grup', async () => {
  await assertFails(db(inactiveId).doc('groupChatMessages/new').set({
    senderId: inactiveId, senderName: 'Inactive', senderPhotoBase64: '',
    text: 'Salut', createdAt: new Date(),
  }));
});
test('contul inactiv nu poate crea notificări', async () => {
  await assertFails(db(inactiveId).doc('notifications/new').set({
    userId: activeId, title: 'Alertă', message: 'Mesaj', read: false,
  }));
});
test('contul inactiv nu poate publica poziția live', async () => {
  await assertFails(db(inactiveId).doc('liveLocations/' + inactiveId).set({ lat: 45, lng: 24 }));
});
test('contul inactiv nu poate depune sugestii', async () => {
  await assertFails(db(inactiveId).doc('suggestions/new').set({
    userId: inactiveId, text: 'Sugestie',
  }));
});
test('vizitatorul neautentificat nu poate citi directorul', async () => {
  await assertFails(env.unauthenticatedContext().firestore().doc('memberDirectory/' + activeId).get());
});
test('vizitatorul neautentificat nu poate citi locațiile', async () => {
  await assertFails(env.unauthenticatedContext().firestore().doc('locations/site').get());
});
test('vizitatorul neautentificat nu poate citi chatul de grup', async () => {
  await assertFails(env.unauthenticatedContext().firestore().doc('groupChatMessages/msg').get());
});
test('vizitatorul neautentificat nu poate trimite notificări', async () => {
  await assertFails(env.unauthenticatedContext().firestore().doc('notifications/new').set({
    userId: activeId, title: 'Alertă', message: 'Mesaj', read: false,
  }));
});
test('membrul activ poate citi directorul', async () => {
  await assertSucceeds(db(activeId).doc('memberDirectory/' + activeId).get());
});
test('membrul activ nu poate modifica directorul publicat de backend', async () => {
  await assertFails(db(activeId).doc('memberDirectory/' + activeId).update({ name: 'Changed' }));
});
test('contul inactiv își poate citi propriul profil pentru autentificare', async () => {
  await assertSucceeds(db(inactiveId).doc('users/' + inactiveId).get());
});
test('contul inactiv nu poate modifica propriul profil', async () => {
  await assertFails(db(inactiveId).doc('users/' + inactiveId).update({ name: 'Changed' }));
});
