'use strict';
const crypto = require('node:crypto');

class GraphClosureError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const fail = (code, message) => { throw new GraphClosureError(code, message); };
const validId = value => typeof value === 'string' && value.length > 0 &&
  value.length <= 128 && !value.includes('/');
const millis = value => value && typeof value.toMillis === 'function' ? value.toMillis() : null;
const eventTime = record => Math.max(...['waitingStartedAt', 'waitingEndedAt', 'startedAt', 'finishedAt']
  .map(key => millis(record[key]) || 0));
const finalResult = r => (r.status === 'completed' && millis(r.startedAt) !== null &&
  millis(r.finishedAt) > millis(r.startedAt)) || (r.status === 'notCompleted' &&
  millis(r.finishedAt) !== null && typeof r.refusalReason === 'string' && r.refusalReason.trim().length > 0);

/// All queries are transaction reads, including membership, authorization and
/// the complete team schedule/record sets. No UI readiness result is trusted.
async function closeGraph(db, uid, input, { timestamp, beforeWrite } = {}) {
  const { teamId, graphId, requestId, days } = input || {};
  if (![teamId, graphId, requestId, uid].every(validId) || !Array.isArray(days) ||
      !days.length || days.length > 400 || days.some(d => !validId(d.id) ||
        !(d.writeToken == null || typeof d.writeToken === 'string')) ||
      new Set(days.map(d => d.id)).size !== days.length) {
    fail('invalid-argument', 'Cerere STOP invalidă.');
  }
  const receiptId = crypto.createHash('sha256').update(`${uid}\0${requestId}`).digest('hex');
  const state = db.collection('graphStates').doc(teamId).collection('graphs').doc(graphId);
  const receipt = db.collection('graphClosures').doc(receiptId);
  return db.runTransaction(async tx => {
    const [user, team, previous, schedules, records, lock, graphState] = await Promise.all([
      tx.get(db.collection('users').doc(uid)), tx.get(db.collection('teams').doc(teamId)),
      tx.get(receipt), tx.get(db.collection('schedules').where('teamId', '==', teamId)),
      tx.get(db.collection('records').where('teamId', '==', teamId)),
      tx.get(db.collection('activeRecordLocks').doc(teamId)), tx.get(state),
    ]);
    const u = user.data() || {};
    const admin = u.role === 'admin';
    if (u.active !== true || (!admin && (!Array.isArray(team.data()?.members) ||
        !team.data().members.includes(uid) || !Array.isArray(u.effectivePermissions) ||
        !u.effectivePermissions.includes('editProgram')))) {
      fail('permission-denied', 'Nu ai dreptul să închizi graficul acestei echipe.');
    }
    const fingerprint = JSON.stringify({ teamId, graphId,
      days: days.map(d => ({ id: d.id, writeToken: d.writeToken ?? null })).sort((a,b) => a.id.localeCompare(b.id)) });
    if (previous.exists) {
      if (previous.data().fingerprint !== fingerprint) fail('conflict', 'Identificator STOP reutilizat pentru altă cerere.');
      return { closed: true, receiptId, replay: true };
    }
    if (graphState.data()?.closed === true) fail('conflict', 'Grafic deja închis. Reîncarcă.');
    const graph = schedules.docs.filter(d => d.data().graphId === graphId);
    if (graph.length !== days.length || graph.some(d => !days.some(expected => expected.id === d.id))) {
      fail('conflict', 'Componența graficului s-a schimbat. Reîncarcă înainte de STOP.');
    }
    if (graph.some(d => (d.data().writeToken ?? null) !==
        (days.find(expected => expected.id === d.id).writeToken ?? null))) {
      fail('conflict', 'Graficul s-a schimbat. Reîncarcă înainte de STOP.');
    }
    if (records.docs.some(d => d.data().status === 'running' && d.data().finishedAt == null)) {
      fail('failed-precondition', 'Echipa are o intervenție activă, inclusiv din versiunea veche.');
    }
    if (lock.exists) fail('failed-precondition', 'Echipa are o rezervare START activă.');
    if (graph.some(d => d.data().closed === true || d.data().started !== true)) {
      fail('failed-precondition', 'Graficul nu este integral pornit sau este deja închis. Reîncarcă.');
    }
    const seen = new Set();
    for (const day of graph) {
      if (!Array.isArray(day.data().items)) fail('failed-precondition', 'Zi de grafic invalidă.');
      for (const item of day.data().items) {
        if (!validId(item.interventionId) || seen.has(item.interventionId)) {
          fail('failed-precondition', 'Intervenție fără identitate stabilă sau duplicată. Necesită reconciliere explicită.');
        }
        seen.add(item.interventionId);
        const attempts = records.docs.map(d => ({ id: d.id, ...d.data() })).filter(r =>
          r.interventionId === item.interventionId);
        // A transfer preserves identity, but only the current owner can finish.
        if (attempts.some(r => r.graphId !== graphId ||
            r.locationId !== item.locationId)) fail('conflict', 'Referințe de intervenție neconcordante.');
        attempts.sort((a,b) => eventTime(a) - eventTime(b) || a.id.localeCompare(b.id));
        if (!attempts.length || attempts.at(-1).scheduleId !== day.id || attempts.some(r => r.finishedAt == null) || !finalResult(attempts.at(-1))) {
          fail('failed-precondition', `Intervenție fără rezultat final: ${item.locationNameSnapshot || item.locationId}`);
        }
      }
    }
    if (!seen.size) fail('failed-precondition', 'Graficul nu are intervenții.');
    if (beforeWrite) await beforeWrite(); // Emulator concurrency barrier; never supplied by HTTP.
    const closedAt = timestamp();
    for (const day of graph) tx.update(day.ref, {
      closed: true, paused: false, active: false, updatedAt: closedAt,
      writeToken: receiptId, closeReceiptId: receiptId,
    });
    tx.set(state, { teamId, graphId, closed: true, receiptId, closedAt });
    tx.create(receipt, { teamId, graphId, actorId: uid, requestId, fingerprint,
      closedAt, scheduleIds: graph.map(d => d.id), interventionCount: seen.size });
    return { closed: true, receiptId, replay: false };
  });
}
module.exports = { closeGraph, GraphClosureError, finalResult };
