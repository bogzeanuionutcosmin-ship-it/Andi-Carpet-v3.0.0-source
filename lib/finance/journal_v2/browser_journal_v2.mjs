// Opt-in browser candidate; never loaded by main.dart. All cooperating V2
// writers MUST use this module in the same origin/storage bucket. No V1 import.
const DB = 'andi-finance-history-v2', STORE = 'journals';
const FORMAT = 'AndiFinanceHistoryJournalV2', LIMIT = 128 * 1024;
const bytes = s => new TextEncoder().encode(s);
const fail = code => { throw new Error(code); };
const keys = (o, expected) => o && typeof o === 'object' && !Array.isArray(o) &&
  Object.keys(o).sort().join('|') === expected.split('|').sort().join('|');
const id = s => typeof s === 'string' && s.length > 0 && s.length <= 128 && !s.includes('/');
const hex = (s, n) => typeof s === 'string' && new RegExp(`^[a-f0-9]{${n}}$`).test(s);
const canonical = x => JSON.stringify(x, (_k, v) => v && typeof v === 'object' && !Array.isArray(v)
  ? Object.fromEntries(Object.keys(v).sort().map(k => [k, v[k]])) : v);
async function hash(s) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes(s))))
    .map(b => b.toString(16).padStart(2, '0')).join('');
}
function intent(raw, owner, team) {
  try {
    if (typeof raw !== 'string' || bytes(raw).length > 16384) fail('invalid');
    const d = JSON.parse(raw), r = d.receipt, c = r?.changes, date = c?.date?.['@timestamp'];
    if (!keys(d, 'protocol|receipt') || d.protocol !== 2 ||
      !keys(r, 'version|operationId|actorUid|teamId|collection|documentId|baseRevision|kind|changes') ||
      r.version !== 1 || r.kind !== 'receipt' || !hex(r.operationId, 32) ||
      r.actorUid !== owner || r.teamId !== team || !id(r.documentId) ||
      !['settlements', 'finance'].includes(r.collection) ||
      (r.collection === 'finance' && r.documentId !== team) ||
      !Number.isSafeInteger(r.baseRevision) || r.baseRevision < 0 || r.baseRevision >= Number.MAX_SAFE_INTEGER ||
      !keys(c, 'kind|amount|method|fromName|date') || !['departure', 'during'].includes(c.kind) ||
      typeof c.amount !== 'number' || !Number.isFinite(c.amount) || c.amount <= 0 ||
      !['Cash', 'Transfer'].includes(c.method) || typeof c.fromName !== 'string' || !c.fromName.trim() ||
      !keys(c.date, '@timestamp') || !Array.isArray(date) || date.length !== 2 ||
      !Number.isSafeInteger(date[0]) || date[0] < -62135596800 || date[0] > 253402300799 ||
      !Number.isInteger(date[1]) || date[1] < 0 || date[1] > 999999999) fail('invalid');
    // Retain the EXACT Dart-produced bytes, never JSON.stringify/re-number money.
    return {operationId: r.operationId, target: `${r.collection}/${r.documentId}`};
  } catch (_) { fail('journal_v2_invalid_intent'); }
}
function open() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 1);
    let abandoned = false;
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onerror = () => reject(new Error('journal_v2_storage_unavailable'));
    request.onblocked = () => { abandoned = true; reject(new Error('journal_v2_storage_blocked')); };
    request.onsuccess = () => {
      const db = request.result;
      if (abandoned) { db.close(); return; }
      db.onversionchange = () => db.close();
      resolve(db);
    };
  });
}
function read(db, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readonly'), request = tx.objectStore(STORE).get(key);
    tx.oncomplete = () => resolve(request.result);
    tx.onabort = tx.onerror = () => reject(new Error('journal_v2_read_failed'));
  });
}
function write(db, key, value, guard) {
  return new Promise((resolve, reject) => {
    // No relaxed/default fallback. Completion, not request.onsuccess, is barrier.
    const tx = db.transaction(STORE, 'readwrite', {durability: 'strict'});
    tx.onabort = tx.onerror = () => reject(new Error('journal_v2_write_failed'));
    tx.oncomplete = resolve;
    try {
      if (tx.durability !== 'strict') fail('journal_v2_durability_unavailable');
      guard();
      tx.objectStore(STORE).put(value, key);
    } catch (error) { tx.abort(); reject(error); }
  });
}

export function createJournalV2({ownerUid, teamId, sessionIsCurrent}) {
  if (!id(ownerUid) || !id(teamId) || typeof sessionIsCurrent !== 'function') fail('journal_v2_invalid_scope');
  const key = JSON.stringify(['history-xi', 2, ownerUid, teamId]);
  const lockName = `${DB}/${STORE}/${key}`;
  let alive = true;
  const guard = () => {
    try { if (sessionIsCurrent() !== true) alive = false; } catch (_) { alive = false; }
    if (!alive) fail('journal_v2_session_expired');
  };
  async function decode(raw) {
    if (raw === undefined) return {revision: 0, intents: []};
    try {
      if (typeof raw !== 'string' || bytes(raw).length > LIMIT) fail('invalid');
      const d = JSON.parse(raw), {checksum, ...body} = d;
      if (!keys(d, 'format|protocol|ownerUid|teamId|revision|intents|checksum') ||
        d.format !== FORMAT || d.protocol !== 2 || d.ownerUid !== ownerUid || d.teamId !== teamId ||
        !Number.isSafeInteger(d.revision) || d.revision < 1 || !hex(checksum, 64) ||
        !Array.isArray(d.intents) || d.intents.length > 32 || checksum !== await hash(canonical(body))) fail('invalid');
      guard();
      const ids = new Set(), targets = new Set();
      for (const item of d.intents) {
        if (!keys(item, 'raw|digest') || !hex(item.digest, 64)) fail('invalid');
        const i = intent(item.raw, ownerUid, teamId);
        if (ids.has(i.operationId) || targets.has(i.target) || item.digest !== await hash(item.raw)) fail('invalid');
        guard(); ids.add(i.operationId); targets.add(i.target);
      }
      return d;
    } catch (_) { guard(); fail('journal_v2_corrupt'); }
  }
  async function locked(action) {
    guard();
    if (!globalThis.isSecureContext || !globalThis.navigator?.locks?.request ||
      !globalThis.indexedDB || !globalThis.crypto?.subtle) fail('journal_v2_platform_unavailable');
    return navigator.locks.request(lockName, {mode: 'exclusive', ifAvailable: true}, async lock => {
      guard();
      if (!lock || lock.name !== lockName || lock.mode !== 'exclusive') fail('journal_v2_busy');
      const db = await open();
      try {
        guard(); const old = await read(db, key); guard();
        const state = await decode(old); guard();
        const change = await action(state); guard();
        if (change.next) {
          if (state.revision >= Number.MAX_SAFE_INTEGER) fail('journal_v2_revision_exhausted');
          const body = {format: FORMAT, protocol: 2, ownerUid, teamId,
            revision: state.revision + 1, intents: change.next};
          const value = canonical({...body, checksum: await hash(canonical(body))}); guard();
          if (bytes(value).length > LIMIT || change.next.length > 32) fail('journal_v2_full');
          await write(db, key, value, guard); guard();
          if (await read(db, key) !== value) fail('journal_v2_readback_failed');
          guard();
        }
        return change.result;
      } finally { db.close(); }
    });
  }
  return Object.freeze({
    dispose() { alive = false; },
    pending() { return locked(async state => ({result: state.intents.map(i => i.raw)})); },
    prepare(raw) {
      const i = intent(raw, ownerUid, teamId);
      return locked(async state => {
        const digest = await hash(raw); guard();
        for (const item of state.intents) {
          const old = intent(item.raw, ownerUid, teamId);
          if (old.operationId === i.operationId) {
            if (item.digest !== digest || item.raw !== raw) fail('journal_v2_identity_reuse');
            return {result: false}; // Existing uncertain intent NEVER authorizes another send.
          }
          if (old.target === i.target) fail('journal_v2_unresolved_target');
        }
        return {next: [...state.intents, {raw, digest}], result: true};
      });
    },
    // Trusted coordinator only, AFTER authoritative same-protocol evidence.
    // Neither a timeout, local amount nor certain rejection authorizes removal.
    confirm(raw) {
      const i = intent(raw, ownerUid, teamId);
      return locked(async state => {
        const item = state.intents.find(x => intent(x.raw, ownerUid, teamId).operationId === i.operationId);
        if (!item) return {result: false};
        if (item.raw !== raw || item.digest !== await hash(raw)) fail('journal_v2_identity_reuse');
        return {next: state.intents.filter(x => x !== item), result: true};
      });
    },
  });
}
