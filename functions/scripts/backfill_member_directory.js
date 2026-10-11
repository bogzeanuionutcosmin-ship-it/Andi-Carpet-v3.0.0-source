'use strict';
// One-time repair for users created before syncMemberDirectory was deployed.
// Requires Firebase Admin credentials. Defaults to a read-only dry run.
// Usage: node scripts/backfill_member_directory.js
// Apply: APPLY_MEMBER_DIRECTORY_BACKFILL=1 node scripts/backfill_member_directory.js
const admin = require('firebase-admin');
const { projectMember } = require('../member_directory_projection');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

async function main() {
  const apply = process.env.APPLY_MEMBER_DIRECTORY_BACKFILL === '1';
  const users = await db.collection('users').get();
  const directory = await db.collection('memberDirectory').get();
  const desired = new Map();
  for (const user of users.docs) {
    const projected = projectMember(user.data());
    if (projected) desired.set(user.id, projected);
  }
  const existing = new Map(directory.docs.map(doc => [doc.id, doc.data()]));
  const writes = [];
  for (const [id, data] of desired) {
    if (JSON.stringify(existing.get(id)) !== JSON.stringify(data)) {
      writes.push({ kind: 'set', id, data });
    }
  }
  // Also remove stale records for deleted/hidden admins.
  for (const id of existing.keys()) {
    if (!desired.has(id)) writes.push({ kind: 'delete', id });
  }
  console.log(JSON.stringify({
    mode: apply ? 'APPLY' : 'DRY_RUN',
    users: users.size, expectedVisible: desired.size,
    existing: directory.size, changes: writes.length,
    createOrUpdate: writes.filter(w => w.kind === 'set').length,
    remove: writes.filter(w => w.kind === 'delete').length
  }, null, 2));
  if (!apply) return;
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const write of writes.slice(i, i + 400)) {
      const ref = db.collection('memberDirectory').doc(write.id);
      if (write.kind === 'delete') batch.delete(ref);
      else batch.set(ref, write.data);
    }
    await batch.commit();
  }
  console.log('Member directory backfill complete.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
