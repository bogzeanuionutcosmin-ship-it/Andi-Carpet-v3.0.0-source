/**
 * One-time member directory reconciliation from trusted Admin SDK credentials.
 * Dry-run by default. --apply reconciles each document transactionally against
 * the CURRENT private profile, avoiding stale snapshot writes that could
 * accidentally republish a hidden or deleted Admin/member profile.
 *
 * Deploy backend sync trigger first, run this migration, then coordinate
 * restrictive rules + updated client rollout (old clients may break).
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const { projectMember } = require('../functions/member_directory_projection');
async function main() {
  const apply = process.argv.includes('--apply');
  const users = await db.collection('users').get();
  const existing = await db.collection('memberDirectory').get();
  const ids = new Set([...users.docs.map(d => d.id), ...existing.docs.map(d => d.id)]);
  const expected = users.docs.filter(d => projectMember(d.data()) !== null).length;
  const stale = existing.docs.filter(d => {
    const user = users.docs.find(u => u.id === d.id);
    return !user || projectMember(user.data()) === null;
  }).length;
  console.log(JSON.stringify({ mode: apply ? 'APPLY' : 'DRY_RUN', users: users.size, directoryEntries: expected, staleEntries: stale, candidates: ids.size }));
  if (!apply) return;
  let written = 0, deleted = 0;
  for (const id of ids) {
    const userRef = db.collection('users').doc(id);
    const directoryRef = db.collection('memberDirectory').doc(id);
    const result = await db.runTransaction(async tx => {
      const current = await tx.get(userRef);
      const value = projectMember(current.exists ? current.data() : null);
      if (value === null) { tx.delete(directoryRef); return 'deleted'; }
      tx.set(directoryRef, value); return 'written';
    });
    if (result === 'deleted') deleted++; else written++;
  }
  console.log(JSON.stringify({ status: 'completed', written, deleted }));
}
main().catch(e => { console.error(e); process.exitCode = 1; });
