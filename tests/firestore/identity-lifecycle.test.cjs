const { test, before, after } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection: firestoreCollection, setDoc, updateDoc } = require('firebase/firestore');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-andi-carpet',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const uid of ['payer', 'receiver', 'stranger']) {
      await setDoc(doc(ctx.firestore(), 'users', uid), { active: true, role: 'worker' });
    }
  });
});
after(async () => { if (env) await env.cleanup(); });

// Identity/backend characterization uses only demo-andi-carpet emulator fixtures.
// It does not exercise AuthGate, the Flutter client cache or a live project.
async function seedIdentityFixtures() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const database = ctx.firestore();
    await setDoc(doc(database, 'users/fixture-admin'), {active: true, role: 'admin'});
    await setDoc(doc(database, 'users/fixture-inactive-admin'), {active: false, role: 'admin'});
    await setDoc(doc(database, 'audit/fixture-private'), {actorUid: 'fixture-admin', action: 'Synthetic'});
    await setDoc(doc(database, 'meta/uiSettings'), {brandingLogoId: 'synthetic'});
    await setDoc(doc(database, 'functions/fixture-custom'), {active: true, permissions: ['viewMap']});
  });
}

test('identity: own profile remains readable but foreign private get/list require active admin', async () => {
  await seedIdentityFixtures();
  await assertSucceeds(getDoc(doc(db('payer'), 'users/payer')));
  await assertFails(getDoc(doc(db('receiver'), 'users/payer')));
  await assertFails(getDocs(firestoreCollection(db('receiver'), 'users')));
  await assertSucceeds(getDoc(doc(db('fixture-admin'), 'users/payer')));
  await assertSucceeds(getDocs(firestoreCollection(db('fixture-admin'), 'users')));
  await assertFails(getDoc(doc(db('fixture-inactive-admin'), 'users/payer')));
});

test('identity: B cannot write or read A push token path after account switch', async () => {
  const tokenPath = 'users/payer/pushTokens/fixture-device';
  await assertSucceeds(setDoc(doc(db('payer'), tokenPath), {
    token: 'synthetic-not-a-real-token', deviceOwnerUid: 'payer', active: true,
  }));
  await assertSucceeds(getDoc(doc(db('payer'), tokenPath)));
  await assertFails(getDoc(doc(db('receiver'), tokenPath)));
  await assertFails(setDoc(doc(db('receiver'), tokenPath), {
    token: 'synthetic-late-token', deviceOwnerUid: 'payer', active: true,
  }));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), tokenPath), {token: 'synthetic'}));
});

test('identity: audit is admin-readable; a member can create only its own actor entry', async () => {
  await seedIdentityFixtures();
  await assertFails(getDoc(doc(db('receiver'), 'audit/fixture-private')));
  await assertSucceeds(getDoc(doc(db('fixture-admin'), 'audit/fixture-private')));
  await assertFails(getDoc(doc(db('fixture-inactive-admin'), 'audit/fixture-private')));
  await assertSucceeds(setDoc(doc(db('receiver'), 'audit/fixture-own'), {actorUid: 'receiver', action: 'Synthetic'}));
  await assertFails(setDoc(doc(db('receiver'), 'audit/fixture-forged'), {actorUid: 'payer', action: 'Synthetic'}));
});

test('identity: member cannot self-assign authority or mutate function definitions; active admin can', async () => {
  await seedIdentityFixtures();
  await assertFails(updateDoc(doc(db('receiver'), 'users/receiver'), {role: 'admin'}));
  await assertFails(updateDoc(doc(db('receiver'), 'users/receiver'), {active: false}));
  await assertFails(updateDoc(doc(db('receiver'), 'users/receiver'), {functionIds: ['fixture-custom']}));
  await assertFails(updateDoc(doc(db('receiver'), 'users/receiver'), {effectivePermissions: ['viewOtherDecont']}));
  await assertFails(updateDoc(doc(db('receiver'), 'functions/fixture-custom'), {permissions: ['viewOtherDecont']}));
  await assertSucceeds(updateDoc(doc(db('fixture-admin'), 'users/receiver'), {
    functionIds: ['fixture-custom'], effectivePermissions: ['viewMap'],
  }));
  await assertFails(updateDoc(doc(db('fixture-inactive-admin'), 'users/receiver'), {functionIds: []}));
});

test('CHARACTERIZATION: uiSettings read is global even without authentication; member writes remain denied', async () => {
  await seedIdentityFixtures();
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'meta/uiSettings')));
  await assertSucceeds(getDoc(doc(db('payer'), 'meta/uiSettings')));
  await assertSucceeds(getDoc(doc(db('receiver'), 'meta/uiSettings')));
  await assertFails(updateDoc(doc(db('receiver'), 'meta/uiSettings'), {brandingLogoId: 'changed'}));
  await assertSucceeds(updateDoc(doc(db('fixture-admin'), 'meta/uiSettings'), {brandingLogoId: 'changed'}));
});
