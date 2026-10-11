const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-config', member: 'member-config', editor: 'editor-config' };
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
        effectivePermissions: role === 'editor' ? ['manageMessageTemplates', 'editContacts'] : [],
      });
    }
    batch.set(store.doc('meta/uiSettings'), { smsTemplates: [], theme: 'green' });
    batch.set(store.doc('locations/site'), { name: 'Site', contacts: [], phone: '' });
    batch.set(store.doc('suggestions/suggestion'), { userId: ids.member, upVotes: 0, downVotes: 0, text: 'Idea' });
    batch.set(store.doc('backgrounds/default'), { name: 'Default' });
    batch.set(store.doc('functions/developer'), { active: true, permissions: [] });
    await batch.commit();
  });
});
test('editorul poate actualiza doar șabloanele SMS globale', async () => {
  await assertSucceeds(db('editor').doc('meta/uiSettings').update({ smsTemplates: ['Salut'] }));
});
test('editorul nu poate schimba tema globală', async () => {
  await assertFails(db('editor').doc('meta/uiSettings').update({ theme: 'red' }));
});
test('membrul fără permisiune nu poate schimba șabloanele SMS', async () => {
  await assertFails(db('member').doc('meta/uiSettings').update({ smsTemplates: ['Interzis'] }));
});
test('editorul poate actualiza contactele unei locații', async () => {
  await assertSucceeds(db('editor').doc('locations/site').update({ contacts: ['Telefon'] }));
});
test('editorul nu poate modifica numele locației', async () => {
  await assertFails(db('editor').doc('locations/site').update({ name: 'Modificat' }));
});
test('membrul fără permisiune nu poate modifica contactele', async () => {
  await assertFails(db('member').doc('locations/site').update({ phone: '123' }));
});
test('membrul poate vota o sugestie', async () => {
  await assertSucceeds(db('member').doc('suggestions/suggestion').update({ upVotes: 1 }));
});
test('membrul nu poate modifica textul sugestiei altuia', async () => {
  await assertFails(db('editor').doc('suggestions/suggestion').update({ text: 'Changed' }));
});
test('autorul poate șterge propria sugestie', async () => {
  await assertSucceeds(db('member').doc('suggestions/suggestion').delete());
});
test('alt membru nu poate șterge sugestia', async () => {
  await assertFails(db('editor').doc('suggestions/suggestion').delete());
});
test('membrul poate vedea fundalurile', async () => {
  await assertSucceeds(db('member').doc('backgrounds/default').get());
});
test('membrul nu poate modifica fundalurile globale', async () => {
  await assertFails(db('member').doc('backgrounds/default').update({ name: 'Changed' }));
});
test('membrul poate vedea definițiile funcțiilor', async () => {
  await assertSucceeds(db('member').doc('functions/developer').get());
});
test('membrul nu poate modifica permisiunile funcțiilor', async () => {
  await assertFails(db('member').doc('functions/developer').update({ permissions: ['editProgram'] }));
});
