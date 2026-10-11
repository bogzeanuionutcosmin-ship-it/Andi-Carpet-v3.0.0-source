const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-profile', member: 'member-profile', other: 'other-profile' };
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
        name: role, active: true, role: role === 'admin' ? 'admin' : 'member',
        effectivePermissions: [], phone: '',
      });
    }
    await batch.commit();
  });
});
test('membrul își poate modifica numele', async () => {
  await assertSucceeds(db('member').doc('users/' + ids.member).update({ name: 'Nume nou' }));
});
test('membrul își poate modifica tema', async () => {
  await assertSucceeds(db('member').doc('users/' + ids.member).update({ theme: 'green' }));
});
test('membrul își poate modifica preferințele de notificare', async () => {
  await assertSucceeds(db('member').doc('users/' + ids.member).update({ notificationPreferences: {} }));
});
test('membrul nu se poate promova administrator', async () => {
  await assertFails(db('member').doc('users/' + ids.member).update({ role: 'admin' }));
});
test('membrul nu poate activa propriul cont prin modificarea profilului', async () => {
  await assertFails(db('member').doc('users/' + ids.member).update({ active: false }));
});
test('membrul nu își poate acorda permisiuni', async () => {
  await assertFails(db('member').doc('users/' + ids.member).update({ effectivePermissions: ['editProgram'] }));
});
test('membrul nu poate edita profilul altui membru', async () => {
  await assertFails(db('member').doc('users/' + ids.other).update({ name: 'Changed' }));
});
test('administratorul poate modifica rolul unui membru', async () => {
  await assertSucceeds(db('admin').doc('users/' + ids.member).update({ role: 'admin' }));
});
test('utilizatorul poate salva propriul token push', async () => {
  await assertSucceeds(db('member').doc('users/' + ids.member + '/pushTokens/device').set({ token: 'sample' }));
});
test('utilizatorul nu poate salva token push pentru alt utilizator', async () => {
  await assertFails(db('member').doc('users/' + ids.other + '/pushTokens/device').set({ token: 'sample' }));
});
test('utilizatorul nu poate citi tokenul push al altuia', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('users/' + ids.other + '/pushTokens/device').set({ token: 'private' });
  });
  await assertFails(db('member').doc('users/' + ids.other + '/pushTokens/device').get());
});
test('utilizatorul își poate șterge propriul token push', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await ctx.firestore().doc('users/' + ids.member + '/pushTokens/device').set({ token: 'old' });
  });
  await assertSucceeds(db('member').doc('users/' + ids.member + '/pushTokens/device').delete());
});
