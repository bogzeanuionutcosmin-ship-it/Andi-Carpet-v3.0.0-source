const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const users = { admin: 'admin-msg', alice: 'alice-msg', bob: 'bob-msg', stranger: 'stranger-msg' };
const db = role => env.authenticatedContext(users[role]).firestore();
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
    for (const [role, id] of Object.entries(users)) {
      batch.set(store.doc('users/' + id), {
        active: true, role: role === 'admin' ? 'admin' : 'member',
        effectivePermissions: [],
      });
    }
    await batch.commit();
  });
});
const message = (extra = {}) => ({
  chatId: 'alice-bob', senderId: users.alice, senderName: 'Alice',
  recipientId: users.bob, recipientName: 'Bob',
  participantIds: [users.alice, users.bob], text: 'Salut',
  read: false, createdAt: new Date(), ...extra,
});
test('expeditorul poate trimite mesaj privat', async () => {
  await assertSucceeds(db('alice').doc('chatMessages/sent').set(message()));
});
test('un utilizator nu poate falsifica expeditorul', async () => {
  await assertFails(db('bob').doc('chatMessages/forged').set(message()));
});
test('nu se pot trimite mesaje private goale', async () => {
  await assertFails(db('alice').doc('chatMessages/empty').set(message({ text: '' })));
});
test('nu se pot trimite mesaje private peste limita de caractere', async () => {
  await assertFails(db('alice').doc('chatMessages/long').set(message({ text: 'x'.repeat(5001) })));
});
test('expeditorul nu își poate trimite singur mesaj privat', async () => {
  await assertFails(db('alice').doc('chatMessages/self').set(message({
    recipientId: users.alice, participantIds: [users.alice, users.alice],
  })));
});
test('persoana din afara conversației nu poate citi mesajul', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('chatMessages/private').set(message());
  });
  await assertFails(db('stranger').doc('chatMessages/private').get());
});
test('destinatarul poate marca mesajul drept citit', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('chatMessages/read').set(message());
  });
  await assertSucceeds(db('bob').doc('chatMessages/read').update({ read: true }));
});
test('expeditorul nu poate marca mesajul drept citit în locul destinatarului', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('chatMessages/read-forged').set(message());
  });
  await assertFails(db('alice').doc('chatMessages/read-forged').update({ read: true }));
});
test('participantul nu poate șterge global mesajul privat', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('chatMessages/delete').set(message());
  });
  await assertFails(db('alice').doc('chatMessages/delete').delete());
});
test('un utilizator poate crea notificare necitită pentru alt membru activ', async () => {
  await assertSucceeds(db('alice').doc('notifications/notify').set({
    userId: users.bob, title: 'Diurnă', message: 'Verifică diurna', read: false,
  }));
});
test('un utilizator nu poate crea notificare deja citită', async () => {
  await assertFails(db('alice').doc('notifications/notify-read').set({
    userId: users.bob, title: 'Diurnă', message: 'Verifică diurna', read: true,
  }));
});
test('destinatarul poate marca notificarea citită', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('notifications/read').set({
      userId: users.bob, title: 'Diurnă', message: 'Verifică diurna', read: false,
    });
  });
  await assertSucceeds(db('bob').doc('notifications/read').update({ read: true }));
});
test('alt membru nu poate modifica notificarea destinatarului', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('notifications/private').set({
      userId: users.bob, title: 'Diurnă', message: 'Verifică diurna', read: false,
    });
  });
  await assertFails(db('alice').doc('notifications/private').update({ read: true }));
});
