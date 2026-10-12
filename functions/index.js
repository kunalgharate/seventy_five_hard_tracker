const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Preference categories, mirroring NotificationPreferences (Flutter).
// Absent/unknown → allowed (fail-open).
function prefsAllow(prefs, type) {
  const byCategory = {
    reviews: [
      'taskNeedsReview',
      'reviewApproved',
      'reviewRejected',
      'reviewReminder20h',
      'reviewExpired',
    ],
    tasks: ['taskAssigned'],
    invitations: [
      'invitationReceived',
      'invitationAccepted',
      'invitationDeclined',
    ],
    messages: ['partnerMessage'],
  };
  for (const [category, types] of Object.entries(byCategory)) {
    if (types.includes(type)) {
      return prefs[category] !== false;
    }
  }
  return true;
}

// ── Push delivery ─────────────────────────────────────────────
// Fires for every fcm_notifications doc the app writes (task review,
// proof submitted/approved/rejected, invitation, chat message, …) and
// delivers a real FCM push to the recipient's registered device tokens,
// so notifications arrive even when the app is killed. The task-ID
// channel doubles as the FCM collapse key, so repeat events for one
// task replace the pending push instead of stacking.
exports.sendPushOnNotificationCreate = onDocumentCreated(
  'fcm_notifications/{docId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const n = snap.data() || {};
    const recipientUid = n.recipientUid;
    const title = (n.title || '').toString();
    const body = (n.body || '').toString();
    if (!recipientUid || (!title && !body)) return;

    const userSnap = await db.doc(`users/${recipientUid}`).get();
    const tokens = userSnap.exists
      ? userSnap.get('fcmTokens') || []
      : [];
    if (!tokens.length) return;

    // Honor the recipient's notification prefs (users/{uid}.notifPrefs).
    // Categories mirror NotificationPreferences.categoryForType (Flutter).
    if (!prefsAllow(userSnap.get('notifPrefs') || {}, (n.type || '').toString())) {
      return;
    }

    const data = {};
    const raw = n.data || {};
    for (const [k, v] of Object.entries(raw)) data[k] = String(v);
    if (n.channel) data.channel = String(n.channel);
    if (n.type) data.type = String(n.type);
    const channel = (n.channel || event.params.docId).toString();

    const message = {
      notification: { title: title || 'DailyMettle', body },
      data,
      android: { collapseKey: channel, priority: 'high' },
      apns: { headers: { 'apns-collapse-id': channel } },
    };

    // sendEachForMulticast caps at 500 tokens per call.
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const res = await admin
        .messaging()
        .sendEachForMulticast({ tokens: batch, ...message });
      const dead = [];
      res.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error && r.error.code;
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            dead.push(batch[idx]);
          }
        }
      });
      if (dead.length) {
        await db
          .doc(`users/${recipientUid}`)
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
          });
      }
    }
  },
);

// ── Tron AI proxy ─────────────────────────────────────────────
// Holds the NVIDIA key server-side in the `config/ai` Firestore doc
// (client reads denied by firestore.rules; functions use Admin SDK).
// Zero Secret Manager usage, so the free-tier secret quota is untouched.
// The key is cached per function instance — one Firestore read per
// cold start, then served from memory. Callable, auth required,
// per-user daily cap.
const TRON_MODEL = 'meta/llama-3.1-8b-instruct';
const TRON_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';
const MAX_INPUT_CHARS = 4000;
const DAILY_CAP = 50;
const SYSTEM_PROMPT =
  'You clean up dictated journal entries. ' +
  'Fix grammar, punctuation and obvious speech-recognition mistakes. ' +
  'Keep the EXACT same language the user spoke (Marathi stays Marathi, ' +
  'Hindi stays Hindi, English stays English) — never translate. ' +
  'Do not add new ideas, advice or commentary. ' +
  'Reply with ONLY the cleaned text, nothing else.';

let cachedNvidiaKey = null;
async function getNvidiaKey() {
  if (cachedNvidiaKey) return cachedNvidiaKey;
  const snap = await db.doc('config/ai').get();
  const key = snap.exists ? (snap.get('nvidiaKey') || '').toString() : '';
  if (key) cachedNvidiaKey = key;
  return key;
}

exports.polishDictation = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to use Tron AI.');
    }
    const text = ((request.data && request.data.text) || '').toString();
    if (!text.trim()) {
      throw new HttpsError('invalid-argument', 'Empty text.');
    }
    if (text.length > MAX_INPUT_CHARS) {
      throw new HttpsError(
        'invalid-argument',
        'Text too long for Tron AI to polish — try shortening it.',
      );
    }
    const key = await getNvidiaKey();
    if (!key) {
      throw new HttpsError(
        'failed-precondition',
        'Tron AI is not configured yet.',
      );
    }

    const uid = request.auth.uid;
    const today = new Date().toISOString().slice(0, 10);
    const usageRef = db.doc(`ai_usage/${uid}`);
    await db.runTransaction(async (tx) => {
      const s = await tx.get(usageRef);
      let count = 0;
      if (s.exists && s.get('date') === today) count = s.get('count') || 0;
      if (count >= DAILY_CAP) {
        throw new HttpsError(
          'resource-exhausted',
          'Daily Tron AI limit reached. Try again tomorrow.',
        );
      }
      tx.set(usageRef, { date: today, count: count + 1 }, { merge: true });
    });

    let resp;
    try {
      resp = await fetch(TRON_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: TRON_MODEL,
          temperature: 0.2,
          max_tokens: 1500,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: text },
          ],
        }),
        signal: AbortSignal.timeout(25000),
      });
    } catch (e) {
      throw new HttpsError(
        'unavailable',
        'Could not reach Tron AI. Check your connection.',
      );
    }
    if (resp.status === 429) {
      throw new HttpsError(
        'resource-exhausted',
        'Tron AI is busy. Try again shortly.',
      );
    }
    if (resp.status === 401 || resp.status === 403) {
      throw new HttpsError('internal', 'Tron AI key rejected.');
    }
    if (!resp.ok) {
      throw new HttpsError(
        'unavailable',
        `Tron AI unavailable (${resp.status}).`,
      );
    }
    const data = await resp.json();
    const choices = data.choices;
    if (Array.isArray(choices) && choices.length > 0) {
      const first = choices[0] || {};
      const finish = (first.finish_reason || '').toString().toLowerCase();
      if (finish === 'length') {
        throw new HttpsError(
          'invalid-argument',
          'Text too long for Tron AI to polish — try shortening it.',
        );
      }
      const content =
        first.message && typeof first.message.content === 'string'
          ? first.message.content.trim()
          : '';
      if (content) return { text: content };
    }
    throw new HttpsError('internal', 'Tron AI returned an empty reply.');
  },
);
