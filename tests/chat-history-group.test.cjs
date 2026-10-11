const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-chat-extra', alice: 'alice-chat-extra', bob: 'bob-chat-extra', outsider: 'outsider-chat-extra' };
const db = role => env.authenticatedContext(ids[role]).firestore();
const privateMessage = () => ({
  chatId: 'alice-bob', senderId: ids.alice, senderName: 'Alice',
  recipientId: ids.bob, recipientName: 'Bob',
  participantIds: [ids.alice, ids.bob], text: 'Salut', read: false,
  createdAt: new Date(),
});
const groupMessage = (overrides = {}) => ({
  senderId: ids.alice, senderName: 'Alice', senderPhotoBase64: '',
  text: 'Salut echipă', createdAt: new Date(), ...overrides,
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
  await env.withSecurityRulesDisabled(async ctx => {
    const store = ctx.firestore();
    const batch = store.batch();
    for (const [role, id] of Object.entries(ids)) {
      batch.set(store.doc('users/' + id), {
        active: true, role: role === 'admin' ? 'admin' : 'member',
        effectivePermissions: [],
      });
    }
    batch.set(store.doc('chatMessages/private'), privateMessage());
    batch.set(store.doc('groupChatMessages/recent'), groupMessage());
    batch.set(store.doc('groupChatMessages/old'), groupMessage({
      createdAt: new Date(Date.now() - 9 * 24 * 60 * 60 * 1000),
    }));
    await batch.commit();
  });
});
test('expeditorul poate citi mesajul privat', async () => {
  await assertSucceeds(db('alice').doc('chatMessages/private').get());
});
test('destinatarul poate citi mesajul privat', async () => {
  await assertSucceeds(db('bob').doc('chatMessages/private').get());
});
test('administratorul neparticipant nu poate citi mesajul privat', async () => {
  await assertFails(db('admin').doc('chatMessages/private').get());
});
test('participantul poate ascunde conversația numai pentru sine', async () => {
  await assertSucceeds(db('alice').doc('chatMessages/private').update({
    deletedFor: [ids.alice],
  }));
});
test('participantul nu poate ascunde conversația în numele altcuiva', async () => {
  await assertFails(db('alice').doc('chatMessages/private').update({
    deletedFor: [ids.bob],
  }));
});
test('participantul nu poate modifica textul mesajului deja trimis', async () => {
  await assertFails(db('alice').doc('chatMessages/private').update({ text: 'Schimbat' }));
});
test('destinatarul nu poate modifica expeditorul', async () => {
  await assertFails(db('bob').doc('chatMessages/private').update({ senderId: ids.bob }));
});
test('membrul poate trimite mesaj în grup', async () => {
  await assertSucceeds(db('alice').doc('groupChatMessages/new').set(groupMessage()));
});
test('membrul nu poate trimite mesaj gol în grup', async () => {
  await assertFails(db('alice').doc('groupChatMessages/empty').set(groupMessage({ text: '' })));
});
test('membrul nu poate trimite mesaj în grup mai lung de 5000 caractere', async () => {
  await assertFails(db('alice').doc('groupChatMessages/long').set(groupMessage({ text: 'x'.repeat(5001) })));
});
test('membrul nu poate falsifica autorul mesajului de grup', async () => {
  await assertFails(db('bob').doc('groupChatMessages/forged').set(groupMessage()));
});
test('membrul poate citi mesajele din grup', async () => {
  await assertSucceeds(db('bob').doc('groupChatMessages/recent').get());
});
test('nimeni nu poate edita mesajele din grup', async () => {
  await assertFails(db('admin').doc('groupChatMessages/recent').update({ text: 'Modificat' }));
});
test('mesajele de grup recente nu pot fi șterse', async () => {
  await assertFails(db('alice').doc('groupChatMessages/recent').delete());
});
test('mesajele de grup mai vechi de 7 zile pot fi curățate', async () => {
  await assertSucceeds(db('bob').doc('groupChatMessages/old').delete());
});
