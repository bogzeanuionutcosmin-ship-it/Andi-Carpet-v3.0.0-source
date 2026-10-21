const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const crypto = require('crypto');

initializeApp();
const db = getFirestore();
const REGION = 'europe-central2';

async function tokenDocs(userId) {
  if (!userId) return [];
  const snap = await db.collection('users').doc(userId).collection('pushTokens').get();
  return snap.docs.filter((d) => typeof d.data().token === 'string' && d.data().token.length > 0);
}

async function userNotificationAllowed(userId, category, mandatory = false) {
  if (mandatory) return true;
  try {
    const snap = await db.collection('users').doc(String(userId || '')).get();
    const data = snap.data() || {};
    const prefs = data.notificationPreferences || {};
    return prefs[category] !== false;
  } catch (error) {
    console.warn('[push] Could not read notification preferences:', error && error.message ? error.message : error);
    return true;
  }
}

function notificationCategory(data) {
  const title = String(data && data.title || '').toLowerCase();
  const body = String(data && data.message || '').toLowerCase();
  const text = `${title} ${body}`;
  if (title === 'sistem' || title.includes('admin')) return { category: 'general', mandatory: true };
  if (text.includes('diurn') || text.includes('decont') || text.includes('cheltu')) return { category: 'decont', mandatory: false };
  if (text.includes('sosir') || text.includes('locați') || text.includes('locati') || text.includes('gps')) return { category: 'arrival', mandatory: false };
  if (text.includes('learning') || text.includes('estim') || text.includes('recomand')) return { category: 'learning', mandatory: false };
  if (text.includes('grafic') || text.includes('program') || text.includes('traseu') || text.includes('plan')) return { category: 'schedule', mandatory: false };
  return { category: 'general', mandatory: false };
}

async function sendToUser(userId, message) {
  const docs = await tokenDocs(userId);
  if (!docs.length) {
    console.warn(`[push] No FCM tokens stored for user ${userId}`);
    return;
  }
  const tokens = docs.map((d) => d.data().token);
  console.log(`[push] Sending to user ${userId}; tokens=${tokens.length}`);
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: message.notification,
    data: message.data || {},
    android: { priority: 'high', notification: { sound: 'default' } },
    webpush: {
      notification: { icon: '/icons/Icon-192.png', badge: '/icons/Icon-192.png' },
      fcmOptions: { link: 'https://andicarpet-e777e.web.app/' }
    }
  });
  console.log(`[push] Result for user ${userId}: success=${response.successCount}, failure=${response.failureCount}`);
  const stale = [];
  response.responses.forEach((r, i) => {
    if (!r.success) console.error(`[push] Token ${i} failed:`, r.error && r.error.code, r.error && r.error.message);
    const code = r.error && r.error.code;
    if (!r.success && (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token')) stale.push(docs[i].ref.delete());
  });
  if (stale.length) await Promise.allSettled(stale);
}

exports.pushChatMessage = onDocumentCreated({ document: 'chatMessages/{messageId}', region: REGION }, async (event) => {
  const d = event.data && event.data.data();
  if (!d || !d.recipientId) return;
  let senderName = String(d.senderName || 'Un membru');
  let senderHidden = false;
  let senderIsAdmin = false;
  const senderId = String(d.senderId || '');
  if (senderId) {
    try {
      const sender = await db.collection('users').doc(senderId).get();
      const sd = sender.data() || {};
      senderIsAdmin = sd.role === 'admin';
      senderHidden = senderIsAdmin && sd.hiddenFromMembers === true;
      if (senderHidden) senderName = 'Sistem';
    } catch (error) {
      console.warn('[push] Could not resolve sender visibility:', error && error.message ? error.message : error);
    }
  }
  const text = String(d.text || 'Ai primit un mesaj nou.');
  if (!(await userNotificationAllowed(String(d.recipientId), 'chat', senderIsAdmin))) {
    console.log(`[push] Chat notification disabled by user ${d.recipientId}`);
    return;
  }
  await sendToUser(String(d.recipientId), {
    notification: { title: `Mesaj nou de la ${senderName}`, body: text.length > 140 ? `${text.slice(0, 137)}...` : text },
    data: senderHidden
      ? { type: 'system', messageId: event.params.messageId }
      : { type: 'chat', senderId, chatId: String(d.chatId || ''), messageId: event.params.messageId }
  });
});

exports.pushSystemNotification = onDocumentCreated({ document: 'notifications/{notificationId}', region: REGION }, async (event) => {
  const d = event.data && event.data.data();
  if (!d || !d.userId) return;
  const pref = notificationCategory(d);
  if (!(await userNotificationAllowed(String(d.userId), pref.category, pref.mandatory))) {
    console.log(`[push] ${pref.category} notification disabled by user ${d.userId}`);
    return;
  }
  await sendToUser(String(d.userId), {
    notification: { title: String(d.title || 'Notificare nouă'), body: String(d.message || '') },
    data: { type: 'notification', notificationId: event.params.notificationId }
  });
});

function normalizeAlias(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizePhone(value) {
  return String(value || '').replace(/[^0-9]/g, '');
}

async function resolveUserEmail(identifier) {
  const raw = String(identifier || '').trim();
  const alias = normalizeAlias(raw);
  const phone = normalizePhone(raw);
  if (!alias) return null;

  // Caută întâi câmpurile normalizate pentru conturile noi/actualizate.
  const usernameSnap = await db.collection('users').where('usernameNormalized', '==', alias).limit(2).get();
  if (usernameSnap.size === 1) return String(usernameSnap.docs[0].data().email || '').trim();
  if (usernameSnap.size > 1) return null;
  if (phone.length >= 8) {
    const phoneSnap = await db.collection('users').where('phoneNormalized', '==', phone).limit(2).get();
    if (phoneSnap.size === 1) return String(phoneSnap.docs[0].data().email || '').trim();
    if (phoneSnap.size > 1) return null;
  }

  // Compatibilitate pentru conturile create înainte de 1.9.0. Pentru aplicația
  // internă numărul de utilizatori este mic; la prima editare câmpurile normalizate
  // sunt salvate și această ramură nu mai este necesară pentru acel cont.
  const all = await db.collection('users').get();
  const matches = [];
  for (const doc of all.docs) {
    const data = doc.data() || {};
    const email = String(data.email || '').trim();
    if (!email) continue;
    const username = normalizeAlias(data.username || '');
    const emailPrefix = normalizeAlias(email.split('@')[0]);
    const storedPhone = normalizePhone(data.phone || '');
    if (alias === username || alias === emailPrefix || (phone.length >= 8 && phone === storedPhone)) {
      matches.push(email);
    }
  }
  return matches.length === 1 ? matches[0] : null;
}

// Autentificare prin username/telefon. Parola este verificată de Firebase Auth
// înainte ca emailul rezolvat să fie returnat aplicației; astfel endpointul nu
// poate fi folosit pentru enumerarea simplă a adreselor de email.
exports.resolveLoginAlias = onRequest({ region: REGION, cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    const identifier = String((req.body && req.body.identifier) || '').trim();
    const password = String((req.body && req.body.password) || '');
    if (!identifier || !password || password.length > 256) {
      return res.status(401).json({ error: 'invalid-credential' });
    }
    const email = await resolveUserEmail(identifier);
    if (!email) return res.status(401).json({ error: 'invalid-credential' });

    const apiKey = 'AIzaSyDbCrAkYTS-ikxjc0JLrYwCww8_ybgndtM';
    const verify = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    });
    if (!verify.ok) return res.status(401).json({ error: 'invalid-credential' });
    const authResult = await verify.json();
    if (!authResult || !authResult.localId) return res.status(401).json({ error: 'invalid-credential' });
    return res.status(200).json({ email });
  } catch (error) {
    console.error('[auth] resolveLoginAlias failed:', error && error.message ? error.message : error);
    return res.status(500).json({ error: 'internal' });
  }
});

async function requireActiveFirebaseUser(req) {
  const authorization = String(req.headers.authorization || '');
  if (!authorization.startsWith('Bearer ')) throw new Error('unauthorized');
  const token = authorization.slice(7).trim();
  if (!token) throw new Error('unauthorized');
  const decoded = await getAuth().verifyIdToken(token);
  const profile = await db.collection('users').doc(decoded.uid).get();
  if (!profile.exists || profile.data().active !== true) throw new Error('inactive');
  return decoded;
}

// Proxy de geocodare pentru Web. Android poate apela direct Nominatim, dar browserul
// poate avea comportament CORS/rețea diferit. Endpointul păstrează identificarea
// serverului și limitează accesul la utilizatorii activi ai aplicației.
exports.geocodeRomaniaPlace = onRequest({ region: REGION, cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    await requireActiveFirebaseUser(req);
    const raw = String((req.body && req.body.query) || '').trim();
    if (!raw || raw.length > 120) return res.status(400).json({ error: 'invalid-query' });

    const candidates = [raw];
    const lower = raw.toLocaleLowerCase('ro-RO');
    if (!lower.includes('românia') && !lower.includes('romania')) candidates.push(`${raw}, România`);

    for (const query of candidates) {
      const url = new URL('https://nominatim.openstreetmap.org/search');
      url.searchParams.set('format', 'jsonv2');
      url.searchParams.set('q', query);
      url.searchParams.set('limit', '1');
      url.searchParams.set('countrycodes', 'ro');
      url.searchParams.set('accept-language', 'ro');
      url.searchParams.set('addressdetails', '1');
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'ro',
          'User-Agent': 'AndiCarpet/2.0.8 (https://andicarpet-e777e.web.app/)',
        },
      });
      if (!response.ok) continue;
      const data = await response.json();
      if (!Array.isArray(data) || data.length === 0) continue;
      const first = data[0] || {};
      const lat = Number(first.lat);
      const lon = Number(first.lon);
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
      return res.status(200).json({
        name: raw,
        lat,
        lon,
        displayName: String(first.display_name || query),
      });
    }
    return res.status(404).json({ error: 'not-found' });
  } catch (error) {
    const message = error && error.message ? error.message : String(error);
    if (message === 'unauthorized' || message === 'inactive') return res.status(401).json({ error: message });
    console.error('[geocode] geocodeRomaniaPlace failed:', message);
    return res.status(500).json({ error: 'internal' });
  }
});


// -----------------------------------------------------------------------------
// SMS automat manageri - gateway Android cu SIM propriu
// -----------------------------------------------------------------------------
const SMS_GATEWAY_CONFIG = db.collection('systemConfig').doc('smsGateway');
const SMS_JOBS = db.collection('managerSmsJobs');
const SMS_STATE = db.collection('managerSmsState');
const SMS_TZ = 'Europe/Bucharest';
const DEFAULT_SMS_PREVIOUS_DAY_TIME = '10:00';
const DEFAULT_SMS_TEMPLATES = {
  initial: 'Bună ziua! Echipa Andi Carpet va ajunge în locația dvs. în data de [data exactă], pentru efectuarea serviciului de curățare a mochetei. Vă mulțumim!',
  rescheduled: 'Bună ziua! Vizita echipei Andi Carpet în locația dvs. a fost reprogramată pentru data de [data exactă]. Vă mulțumim!',
  postponed: 'Bună ziua! Vizita echipei Andi Carpet în locația dvs., programată pentru data de [data exactă], a fost amânată. Vom reveni cu noua dată de sosire. Vă mulțumim!',
};

function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function safeId(value) {
  return sha256(value).slice(0, 40);
}

function normalizePhoneForSms(value) {
  let phone = String(value || '').replace(/[^0-9+]/g, '');
  if (!phone) return '';
  if (phone.startsWith('00')) phone = `+${phone.slice(2)}`;
  if (phone.startsWith('0') && phone.length === 10) phone = `+40${phone.slice(1)}`;
  if (!phone.startsWith('+') && phone.length === 9) phone = `+40${phone}`;
  return phone;
}

function localParts(date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: SMS_TZ, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hour12: false,
  }).formatToParts(date);
  const out = {};
  for (const p of parts) if (p.type !== 'literal') out[p.type] = p.value;
  return out;
}

function localDateKey(date) {
  const p = localParts(date);
  return `${p.year}-${p.month}-${p.day}`;
}

function localDisplayDate(date) {
  const p = localParts(date);
  return `${p.day}.${p.month}.${p.year}`;
}

function displayDateKey(key) {
  const m = String(key || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return m ? `${m[3]}.${m[2]}.${m[1]}` : String(key || '');
}

function addDaysToDateKey(key, days) {
  const m = String(key || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return '';
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]) + Number(days || 0), 12, 0, 0));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

function normalizeSmsSendTime(value) {
  const raw = String(value || '').trim();
  return /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(raw) ? raw : DEFAULT_SMS_PREVIOUS_DAY_TIME;
}

function minuteOfLocalDay(date) {
  const p = localParts(date);
  const hour = Math.max(0, Math.min(23, Number(p.hour === '24' ? '0' : p.hour) || 0));
  const minute = Math.max(0, Math.min(59, Number(p.minute) || 0));
  return hour * 60 + minute;
}

function minuteOfConfiguredTime(value) {
  const [hh, mm] = normalizeSmsSendTime(value).split(':').map(Number);
  return hh * 60 + mm;
}

function initialSmsIsDue(workDateKey, now, sendTime) {
  const previousDayKey = addDaysToDateKey(workDateKey, -1);
  return localDateKey(now) === previousDayKey && minuteOfLocalDay(now) >= minuteOfConfiguredTime(sendTime);
}

function renderSmsTemplate(template, { dateText, locationName }) {
  let out = String(template || '').trim();
  if (!out) return '';
  const replacements = {
    '[data exactă]': dateText, '[data exacta]': dateText, '[data]': dateText,
    '{{date}}': dateText, '{{data}}': dateText,
    '[locație]': locationName, '[locatie]': locationName, '{{location}}': locationName, '{{locatie}}': locationName,
  };
  for (const [from, to] of Object.entries(replacements)) out = out.split(from).join(String(to || ''));
  return out;
}

function addCalendarDaysLocal(date, days) {
  // Folosit doar pentru chei calendaristice. Pornim de la prânz UTC ca să evităm
  // schimbările DST din jurul miezului nopții.
  const p = localParts(date);
  const base = new Date(Date.UTC(Number(p.year), Number(p.month) - 1, Number(p.day) + days, 12, 0, 0));
  return base;
}

function haversineKm(aLat, aLon, bLat, bLon) {
  if (![aLat, aLon, bLat, bLon].every((x) => Number.isFinite(Number(x)))) return 0;
  const toRad = (x) => Number(x) * Math.PI / 180;
  const dLat = toRad(Number(bLat) - Number(aLat));
  const dLon = toRad(Number(bLon) - Number(aLon));
  const aa = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(aa), Math.sqrt(1 - aa));
}

function estimateTravelMinutes(aLat, aLon, bLat, bLon) {
  const straightKm = haversineKm(aLat, aLon, bLat, bLon);
  if (!straightKm) return 0;
  // Estimare fără API plătit: factor rutier + viteză medie + tampon oprire.
  return Math.max(8, Math.round(((straightKm * 1.25) / 65) * 60 + 8));
}

function recordDurationMinutes(data) {
  if (!data || data.status !== 'completed' || data.keptForLearning === false) return null;
  const start = data.startedAt && typeof data.startedAt.toDate === 'function' ? data.startedAt.toDate() : null;
  const finish = data.finishedAt && typeof data.finishedAt.toDate === 'function' ? data.finishedAt.toDate() : null;
  if (!start || !finish || finish <= start) return null;
  return Math.max(1, Math.round((finish.getTime() - start.getTime()) / 60000));
}

function learnedMinutesForLocation(recordsByLocation, locationId) {
  const values = (recordsByLocation.get(locationId) || []).filter((x) => Number.isFinite(x) && x > 0);
  if (values.length < 3) return 60;
  const recent = values.slice(-12).sort((a, b) => a - b);
  const trimmed = recent.length >= 5 ? recent.slice(1, recent.length - 1) : recent;
  return Math.max(10, Math.round(trimmed.reduce((a, b) => a + b, 0) / trimmed.length));
}

function scheduleWorkDate(data) {
  return data && data.date && typeof data.date.toDate === 'function' ? data.date.toDate() : null;
}

function etaPlanForSchedule(scheduleData, locationMap, recordsByLocation) {
  const workDate = scheduleWorkDate(scheduleData);
  if (!workDate) return new Map();
  const items = Array.isArray(scheduleData.items) ? [...scheduleData.items] : [];
  items.sort((a, b) => Number(a.order || 0) - Number(b.order || 0));

  // În aplicație fereastra standard începe la 23:30 în seara dinaintea datei graficului.
  let cursor = new Date(workDate.getTime() - 30 * 60 * 1000);
  let prevLat = Number(scheduleData.departureLatitude);
  let prevLon = Number(scheduleData.departureLongitude);
  const result = new Map();

  for (const item of items) {
    const loc = locationMap.get(String(item.locationId || '')) || {};
    const lat = Number(loc.latitude);
    const lon = Number(loc.longitude);
    if ([prevLat, prevLon, lat, lon].every(Number.isFinite)) {
      cursor = new Date(cursor.getTime() + estimateTravelMinutes(prevLat, prevLon, lat, lon) * 60000);
    }
    result.set(String(item.locationId || ''), new Date(cursor));
    cursor = new Date(cursor.getTime() + learnedMinutesForLocation(recordsByLocation, String(item.locationId || '')) * 60000);
    if (Number.isFinite(lat) && Number.isFinite(lon)) {
      prevLat = lat;
      prevLon = lon;
    }
  }
  return result;
}

function initialSms(locationName, workDateKey, templates = DEFAULT_SMS_TEMPLATES) {
  const dateText = displayDateKey(workDateKey);
  return renderSmsTemplate(templates.initial || DEFAULT_SMS_TEMPLATES.initial, { dateText, locationName });
}

function updatedSms(locationName, workDateKey, templates = DEFAULT_SMS_TEMPLATES) {
  const dateText = displayDateKey(workDateKey);
  return renderSmsTemplate(templates.rescheduled || DEFAULT_SMS_TEMPLATES.rescheduled, { dateText, locationName });
}

function postponedSms(locationName, previousDateKey, templates = DEFAULT_SMS_TEMPLATES) {
  const dateText = displayDateKey(previousDateKey) || 'data programată';
  return renderSmsTemplate(templates.postponed || DEFAULT_SMS_TEMPLATES.postponed, { dateText, locationName });
}

async function queueSmsJob({ stateId, kind, phone, contactName, locationId, locationName, scheduleId, workDateKey, eta, message }) {
  const signature = `${kind}|${stateId}|${workDateKey || ''}|${message}`;
  const jobId = safeId(signature);
  const ref = SMS_JOBS.doc(jobId);
  try {
    await ref.create({
      stateId, kind, phone, contactName: contactName || '', locationId, locationName,
      scheduleId, workDateKey: workDateKey || '', etaAt: eta || null, message,
      status: 'queued', retryCount: 0, createdAt: new Date(), updatedAt: new Date(),
    });
    console.log(`[sms] queued ${kind} -> ${phone} (${locationName})`);
  } catch (e) {
    if (!(e && (e.code === 6 || e.code === 'already-exists'))) throw e;
  }
}

async function loadPlannerContext() {
  const [locationsSnap, recordsSnap, uiSettingsSnap] = await Promise.all([
    db.collection('locations').get(),
    db.collection('records').get(),
    db.collection('meta').doc('uiSettings').get(),
  ]);
  const locations = new Map();
  for (const doc of locationsSnap.docs) locations.set(doc.id, doc.data() || {});
  const recordsByLocation = new Map();
  const timed = [];
  for (const doc of recordsSnap.docs) {
    const d = doc.data() || {};
    const minutes = recordDurationMinutes(d);
    if (minutes == null) continue;
    const loc = String(d.locationId || '');
    const when = d.finishedAt && typeof d.finishedAt.toDate === 'function' ? d.finishedAt.toDate().getTime() : 0;
    timed.push({ loc, minutes, when });
  }
  timed.sort((a, b) => a.when - b.when);
  for (const x of timed) {
    const arr = recordsByLocation.get(x.loc) || [];
    arr.push(x.minutes);
    recordsByLocation.set(x.loc, arr);
  }
  const ui = uiSettingsSnap.exists ? uiSettingsSnap.data() || {} : {};
  const storedTemplates = ui.smsTemplates && typeof ui.smsTemplates === 'object' ? ui.smsTemplates : {};
  const smsTemplates = { ...DEFAULT_SMS_TEMPLATES, ...storedTemplates };
  const smsPreviousDayTime = normalizeSmsSendTime(ui.smsPreviousDayTime);
  return { locations, recordsByLocation, smsTemplates, smsPreviousDayTime };
}

async function planScheduleSms(scheduleId, scheduleData, context, now = new Date(), oldData = null) {
  if (!scheduleData) return;
  const workDate = scheduleWorkDate(scheduleData);
  if (!workDate) return;
  const workDateKey = localDateKey(workDate);
  const etaByLocation = etaPlanForSchedule(scheduleData, context.locations, context.recordsByLocation);
  const items = Array.isArray(scheduleData.items) ? [...scheduleData.items] : [];
  items.sort((a, b) => Number(a.order || 0) - Number(b.order || 0));

  const currentItemIds = new Set(items.map((x) => String(x.locationId || '')));
  const oldItems = oldData && Array.isArray(oldData.items) ? oldData.items : [];

  // Locațiile scoase dintr-un grafic deja anunțat primesc mesaj de amânare.
  for (const oldItem of oldItems) {
    const locationId = String(oldItem.locationId || '');
    if (!locationId || currentItemIds.has(locationId)) continue;
    const loc = context.locations.get(locationId) || {};
    const contacts = Array.isArray(loc.contacts) ? loc.contacts : [];
    for (const c of contacts) {
      if (c && c.smsEnabled === false) continue;
      const phone = normalizePhoneForSms(c && c.phone);
      if (!phone) continue;
      const stateId = safeId(`${scheduleId}|${locationId}|${phone}`);
      const stateSnap = await SMS_STATE.doc(stateId).get();
      const state = stateSnap.exists ? stateSnap.data() || {} : {};
      if (state.initialSent !== true || state.lastStatus === 'postponed') continue;
      const previousEta = state.lastEtaAt && typeof state.lastEtaAt.toDate === 'function' ? state.lastEtaAt.toDate() : null;
      await queueSmsJob({
        stateId, kind: 'postponed', phone, contactName: String(c.name || ''), locationId,
        locationName: String(loc.name || oldItem.locationNameSnapshot || locationId), scheduleId,
        workDateKey: String(state.lastWorkDateKey || workDateKey), eta: previousEta,
        message: postponedSms(String(loc.name || oldItem.locationNameSnapshot || locationId), String(state.lastWorkDateKey || workDateKey), context.smsTemplates),
      });
    }
  }

  for (const item of items) {
    const locationId = String(item.locationId || '');
    if (!locationId) continue;
    const loc = context.locations.get(locationId) || {};
    const locationName = String(loc.name || item.locationNameSnapshot || locationId);
    const contacts = Array.isArray(loc.contacts) ? loc.contacts : [];
    const eta = etaByLocation.get(locationId) || workDate;

    for (const c of contacts) {
      if (c && c.smsEnabled === false) continue;
      const phone = normalizePhoneForSms(c && c.phone);
      if (!phone) continue;
      const stateId = safeId(`${scheduleId}|${locationId}|${phone}`);
      const stateSnap = await SMS_STATE.doc(stateId).get();
      const state = stateSnap.exists ? stateSnap.data() || {} : {};
      const isPostponed = scheduleData.postponed === true;

      if (state.initialSent === true && isPostponed && state.lastStatus !== 'postponed') {
        const previousEta = state.lastEtaAt && typeof state.lastEtaAt.toDate === 'function' ? state.lastEtaAt.toDate() : null;
        await queueSmsJob({
          stateId, kind: 'postponed', phone, contactName: String(c.name || ''), locationId, locationName, scheduleId,
          workDateKey: String(state.lastWorkDateKey || workDateKey), eta: previousEta,
          message: postponedSms(locationName, String(state.lastWorkDateKey || workDateKey), context.smsTemplates),
        });
        continue;
      }
      if (isPostponed) continue;

      if (state.initialSent === true) {
        const oldDateKey = String(state.lastWorkDateKey || '');
        if (oldDateKey && oldDateKey !== workDateKey) {
          await queueSmsJob({
            stateId, kind: 'rescheduled', phone, contactName: String(c.name || ''), locationId, locationName, scheduleId,
            workDateKey, eta, message: updatedSms(locationName, workDateKey, context.smsTemplates),
          });
        }
        // Nu mai trimitem actualizări pentru simple schimbări de ETA în aceeași zi:
        // mesajele către locație nu conțin oră, deci ar fi duplicate fără informație nouă.
        continue;
      }

      const initialDue = initialSmsIsDue(workDateKey, now, context.smsPreviousDayTime);
      if (initialDue) {
        await queueSmsJob({
          stateId, kind: 'initial', phone, contactName: String(c.name || ''), locationId, locationName, scheduleId,
          workDateKey, eta, message: initialSms(locationName, workDateKey, context.smsTemplates),
        });
      }
    }
  }
}

async function cancelPendingSmsJobsForSchedule(scheduleId, workDateKey = '') {
  const snap = await SMS_JOBS.where('scheduleId', '==', String(scheduleId || '')).get();
  let batch = db.batch();
  let writes = 0;
  let cancelled = 0;
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    if (workDateKey && String(d.workDateKey || '') !== workDateKey) continue;
    if (!['queued', 'leased'].includes(String(d.status || ''))) continue;
    batch.set(doc.ref, { status: 'cancelled', cancelledAt: new Date(), updatedAt: new Date() }, { merge: true });
    writes += 1;
    cancelled += 1;
    if (writes >= 350) {
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }
  }
  if (writes > 0) await batch.commit();
  if (cancelled > 0) console.log(`[sms] cancelled ${cancelled} pending jobs for schedule ${scheduleId}${workDateKey ? ` date=${workDateKey}` : ''}`);
}

async function planAllManagerSms(now = new Date()) {
  const configSnap = await SMS_GATEWAY_CONFIG.get();
  const config = configSnap.exists ? configSnap.data() || {} : {};
  if (config.enabled !== true || !config.secretHash) {
    console.log('[sms] gateway not configured; planner skipped');
    return;
  }
  const [context, schedulesSnap] = await Promise.all([
    loadPlannerContext(),
    db.collection('schedules').get(),
  ]);
  for (const doc of schedulesSnap.docs) {
    const data = doc.data() || {};
    const workDate = scheduleWorkDate(data);
    if (!workDate) continue;
    // Nu mai procesăm grafice foarte vechi.
    if (workDate.getTime() < now.getTime() - 36 * 60 * 60 * 1000) continue;
    await planScheduleSms(doc.id, data, context, now);
  }
}

exports.planManagerSms = onSchedule({ schedule: 'every 15 minutes', timeZone: SMS_TZ, region: REGION }, async () => {
  await planAllManagerSms(new Date());
});

exports.onScheduleSmsUpdate = onDocumentWritten({ document: 'schedules/{scheduleId}', region: REGION }, async (event) => {
  const before = event.data && event.data.before && event.data.before.exists ? event.data.before.data() : null;
  const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;

  const beforeDate = scheduleWorkDate(before);
  const afterDate = scheduleWorkDate(after);
  const beforeDateKey = beforeDate ? localDateKey(beforeDate) : '';
  const afterDateKey = afterDate ? localDateKey(afterDate) : '';

  // Dacă data s-a schimbat înainte ca SMS-ul inițial să plece, anulăm joburile
  // vechi din coadă. Noul mesaj va intra la ora configurată pentru noua dată.
  if (beforeDateKey && beforeDateKey !== afterDateKey) {
    await cancelPendingSmsJobsForSchedule(event.params.scheduleId, beforeDateKey);
  }

  const configSnap = await SMS_GATEWAY_CONFIG.get();
  const config = configSnap.exists ? configSnap.data() || {} : {};
  if (config.enabled !== true || !config.secretHash) return;

  const context = await loadPlannerContext();
  if (after) {
    await planScheduleSms(event.params.scheduleId, after, context, new Date(), before);
    return;
  }
  // Grafic șters definitiv: dacă managerul fusese deja informat, trimitem amânarea.
  if (before) {
    const fake = { ...before, active: false, postponed: true };
    await planScheduleSms(event.params.scheduleId, fake, context, new Date(), before);
  }
});

async function verifyAdminBearer(req) {
  const authHeader = String(req.headers.authorization || '');
  if (!authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;
  const decoded = await getAuth().verifyIdToken(token);
  const userSnap = await db.collection('users').doc(decoded.uid).get();
  const user = userSnap.exists ? userSnap.data() || {} : {};
  if (user.active !== true || user.role !== 'admin') return null;
  return decoded.uid;
}

async function verifyGateway(req) {
  const deviceId = String(req.headers['x-sms-gateway-id'] || '').trim();
  const secret = String(req.headers['x-sms-gateway-secret'] || '').trim();
  if (!deviceId || !secret) return null;
  const snap = await SMS_GATEWAY_CONFIG.get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (data.enabled !== true || String(data.deviceId || '') !== deviceId) return null;
  const provided = Buffer.from(sha256(secret));
  const expected = Buffer.from(String(data.secretHash || ''));
  if (provided.length !== expected.length || !crypto.timingSafeEqual(provided, expected)) return null;
  return data;
}

exports.registerSmsGateway = onRequest({ region: REGION, cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    const uid = await verifyAdminBearer(req);
    if (!uid) return res.status(403).json({ error: 'admin-required' });
    const deviceId = String((req.body && req.body.deviceId) || '').trim();
    const secret = String((req.body && req.body.secret) || '').trim();
    if (deviceId.length < 8 || secret.length < 20) return res.status(400).json({ error: 'invalid-gateway' });
    await SMS_GATEWAY_CONFIG.set({
      enabled: true, deviceId, secretHash: sha256(secret), gatewayUid: uid,
      updatedAt: new Date(), registeredAt: new Date(),
    }, { merge: true });
    console.log(`[sms] gateway registered by ${uid}; device=${deviceId}`);
    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error('[sms] register gateway failed', e);
    return res.status(500).json({ error: 'internal' });
  }
});

exports.disableSmsGateway = onRequest({ region: REGION, cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    const uid = await verifyAdminBearer(req);
    if (!uid) return res.status(403).json({ error: 'admin-required' });
    await SMS_GATEWAY_CONFIG.set({ enabled: false, updatedAt: new Date(), disabledBy: uid }, { merge: true });
    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error('[sms] disable gateway failed', e);
    return res.status(500).json({ error: 'internal' });
  }
});

exports.pullManagerSmsJobs = onRequest({ region: REGION, cors: false }, async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    const gateway = await verifyGateway(req);
    if (!gateway) return res.status(403).json({ error: 'invalid-gateway' });
    const snap = await SMS_JOBS.where('status', '==', 'queued').limit(40).get();
    const docs = [...snap.docs].sort((a, b) => {
      const aa = a.data().createdAt && a.data().createdAt.toMillis ? a.data().createdAt.toMillis() : 0;
      const bb = b.data().createdAt && b.data().createdAt.toMillis ? b.data().createdAt.toMillis() : 0;
      return aa - bb;
    }).slice(0, 10);
    const jobs = [];
    for (const doc of docs) {
      const d = doc.data() || {};
      await doc.ref.set({ status: 'leased', leasedAt: new Date(), leasedBy: String(gateway.deviceId || ''), updatedAt: new Date() }, { merge: true });
      jobs.push({ id: doc.id, phone: String(d.phone || ''), message: String(d.message || ''), kind: String(d.kind || '') });
    }
    await SMS_GATEWAY_CONFIG.set({ lastPollAt: new Date() }, { merge: true });
    return res.status(200).json({ jobs });
  } catch (e) {
    console.error('[sms] pull failed', e);
    return res.status(500).json({ error: 'internal' });
  }
});

exports.ackManagerSmsJob = onRequest({ region: REGION, cors: false }, async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    const gateway = await verifyGateway(req);
    if (!gateway) return res.status(403).json({ error: 'invalid-gateway' });
    const jobId = String((req.body && req.body.jobId) || '').trim();
    const success = req.body && req.body.success === true;
    const error = String((req.body && req.body.error) || '').slice(0, 500);
    if (!jobId) return res.status(400).json({ error: 'missing-job' });
    const ref = SMS_JOBS.doc(jobId);
    const snap = await ref.get();
    if (!snap.exists) return res.status(404).json({ error: 'job-not-found' });
    const d = snap.data() || {};
    const retryCount = Number(d.retryCount || 0);
    if (!success && retryCount < 2) {
      await ref.set({ status: 'queued', retryCount: retryCount + 1, lastError: error, updatedAt: new Date() }, { merge: true });
      return res.status(200).json({ ok: true, retry: true });
    }
    await ref.set({
      status: success ? 'sent' : 'failed', lastError: success ? '' : error,
      sentAt: success ? new Date() : null, updatedAt: new Date(),
    }, { merge: true });
    if (success && d.stateId) {
      const patch = {
        initialSent: true,
        lastStatus: d.kind === 'postponed' ? 'postponed' : 'active',
        lastWorkDateKey: String(d.workDateKey || ''),
        lastEtaAt: d.etaAt || null,
        lastKind: String(d.kind || ''),
        lastSentAt: new Date(),
        lastPhone: String(d.phone || ''),
        locationName: String(d.locationName || ''),
        scheduleId: String(d.scheduleId || ''),
      };
      await SMS_STATE.doc(String(d.stateId)).set(patch, { merge: true });
      await SMS_GATEWAY_CONFIG.set({ lastSentAt: new Date(), lastSentPhone: String(d.phone || '') }, { merge: true });
    }
    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error('[sms] ack failed', e);
    return res.status(500).json({ error: 'internal' });
  }
});


// ADMIN PRIVACY: only the backend can project member data to the readable directory.
// Deleting/marking hidden removes the document so hidden Admin profiles cannot be enumerated.
const { projectMember } = require('./member_directory_projection');
exports.syncMemberDirectory = onDocumentWritten(
  { document: 'users/{userId}', region: REGION },
  async (event) => {
    const userId = event.params.userId;
    // Firestore events may be delivered more than once or out of order.
    // Read the CURRENT private profile inside the transaction so a delayed
    // event cannot republish a member who was subsequently hidden or deleted.
    const userRef = db.collection('users').doc(userId);
    const directoryRef = db.collection('memberDirectory').doc(userId);
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(userRef);
      const projection = projectMember(current.exists ? current.data() : null);
      if (projection === null) transaction.delete(directoryRef);
      else transaction.set(directoryRef, projection);
    });
  }
);

// Official graph STOP is a server transaction; direct client closure is denied.
const { closeGraph, GraphClosureError } = require('./graph_closure');
exports.closeProgramGraph = onRequest({ region: REGION, cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'method-not-allowed' });
  try {
    const actor = await requireActiveFirebaseUser(req);
    const result = await closeGraph(db, actor.uid, req.body, {
      timestamp: () => require('firebase-admin/firestore').Timestamp.now(),
    });
    return res.status(200).json(result);
  } catch (error) {
    if (error instanceof GraphClosureError) {
      const status = error.code === 'permission-denied' ? 403 : error.code === 'invalid-argument' ? 400 : 409;
      return res.status(status).json({ error: error.code, message: error.message });
    }
    if (['unauthorized', 'inactive'].includes(error.message) || String(error.code || '').startsWith('auth/')) {
      return res.status(401).json({ error: 'unauthorized' });
    }
    console.error('[program] STOP failed', { code: String(error.code || 'internal') });
    return res.status(503).json({ error: 'unavailable', message: 'STOP neconfirmat. Reîncarcă și verifică starea serverului.' });
  }
});
