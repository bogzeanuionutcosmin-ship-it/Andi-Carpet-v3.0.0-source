'use strict';

// One-time backfill for users created before syncMemberDirectory was deployed.
// Run with authenticated Google Cloud credentials for the Firebase project.
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { projectMember } = require('./member_directory_projection');

initializeApp({ projectId: 'andicarpet-e777e' });
const db = getFirestore();

async function main() {
  const snapshot = await db.collection('users').get();
  let written = 0;
  let deleted = 0;
  for (const doc of snapshot.docs) {
    const ref = db.collection('memberDirectory').doc(doc.id);
    await db.runTransaction(async (tx) => {
      const current = await tx.get(doc.ref);
      const projected = projectMember(current.exists ? current.data() : null);
      if (projected === null) {
        tx.delete(ref);
        deleted++;
      } else {
        tx.set(ref, projected);
        written++;
      }
    });
  }
  console.log('Member directory backfill complete:', { written, deleted });
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
