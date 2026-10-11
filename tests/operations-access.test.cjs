const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
let env;
const ids = { admin: 'admin-ops', editor: 'editor-ops', worker: 'worker-ops', outsider: 'outsider-ops' };
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
        effectivePermissions: role === 'editor' ? ['editProgram', 'editCentralizer'] : [],
      });
    }
    batch.set(store.doc('teams/team-ops'), { members: [ids.editor, ids.worker] });
    batch.set(store.doc('schedules/shift'), { teamId: 'team-ops', title: 'Initial' });
    batch.set(store.doc('records/record'), { teamId: 'team-ops', status: 'started' });
    batch.set(store.doc('locations/site'), { name: 'Site', contacts: [] });
    await batch.commit();
  });
});
test('membrul activ poate citi graficul', async () => {
  await assertSucceeds(db('worker').doc('schedules/shift').get());
});
test('editorul echipei poate modifica graficul', async () => {
  await assertSucceeds(db('editor').doc('schedules/shift').update({ title: 'Actualizat' }));
});
test('membrul fără permisiune nu poate modifica graficul', async () => {
  await assertFails(db('worker').doc('schedules/shift').update({ title: 'Interzis' }));
});
test('editorul nu poate muta graficul către echipa din care nu face parte', async () => {
  await assertFails(db('editor').doc('schedules/shift').update({ teamId: 'other-team' }));
});
test('editorul poate crea o tură pentru echipa sa', async () => {
  await assertSucceeds(db('editor').doc('schedules/new').set({ teamId: 'team-ops', title: 'Nou' }));
});
test('persoana din afara echipei nu poate crea tură', async () => {
  await assertFails(db('outsider').doc('schedules/outsider').set({ teamId: 'team-ops' }));
});
test('editorul poate actualiza înregistrarea echipei', async () => {
  await assertSucceeds(db('editor').doc('records/record').update({ status: 'finished' }));
});
test('membrul fără drept de editare nu poate modifica înregistrarea', async () => {
  await assertFails(db('worker').doc('records/record').update({ status: 'finished' }));
});
test('editorul nu poate muta înregistrarea în altă echipă', async () => {
  await assertFails(db('editor').doc('records/record').update({ teamId: 'other-team' }));
});
test('editorul nu poate șterge înregistrările fără drepturi admin', async () => {
  await assertFails(db('editor').doc('records/record').delete());
});
test('administratorul poate șterge înregistrarea', async () => {
  await assertSucceeds(db('admin').doc('records/record').delete());
});
test('membrul activ poate vedea locațiile', async () => {
  await assertSucceeds(db('worker').doc('locations/site').get());
});
test('membrul fără drepturi admin nu poate șterge locații', async () => {
  await assertFails(db('worker').doc('locations/site').delete());
});
test('membrul fără drepturi admin nu poate crea categorii de locații', async () => {
  await assertFails(db('worker').doc('locationCategories/new').set({ name: 'Categorie' }));
});
test('administratorul poate crea categorii de locații', async () => {
  await assertSucceeds(db('admin').doc('locationCategories/new').set({ name: 'Categorie' }));
});
