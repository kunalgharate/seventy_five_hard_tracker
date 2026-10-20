const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'dailymettle-rules-test';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const authUrl = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
const firestoreUrl = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;

admin.initializeApp({ projectId });
const db = admin.firestore();

const stringValue = (value) => ({ stringValue: value });
const boolValue = (value) => ({ booleanValue: value });
const arrayValue = (values) => ({ arrayValue: { values } });
const mapValue = (fields) => ({ mapValue: { fields } });
const timestampValue = () => ({ timestampValue: new Date().toISOString() });
const fieldsFor = (data) => ({ fields: data });

async function createUser() {
  const response = await fetch(authUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: `${Date.now()}-${Math.random()}@example.com`,
      password: 'test-password',
      returnSecureToken: true,
    }),
  });
  if (!response.ok) {
    throw new Error(`Auth signup failed: ${await response.text()}`);
  }
  return response.json();
}

async function request(token, path, options = {}) {
  return fetch(`${firestoreUrl}/${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      ...(options.headers || {}),
    },
  });
}

async function expectDenied(response, label) {
  if (response.status !== 403) {
    throw new Error(`${label}: expected 403, received ${response.status}: ${await response.text()}`);
  }
}

async function seed() {
  const [owner, reviewer, stranger] = await Promise.all([
    createUser(),
    createUser(),
    createUser(),
  ]);

  await db.collection('partnerships').doc('partnership-1').set({
    ownerUid: owner.localId,
    partnerUid: reviewer.localId,
    status: 'accepted',
  });

  await db.collection('accountability_tasks').doc('task-1').set({
    assignedByUid: owner.localId,
    accountableUid: owner.localId,
    partnerUid: reviewer.localId,
    accountableUserIds: [owner.localId, reviewer.localId],
    partnershipId: 'partnership-1',
    status: 'pending',
    proofStatus: 'not_required',
    approvals: [],
    rejections: [],
    approvalUids: [],
    rejectionUids: [],
  });

  await db.collection('entitlements').doc(owner.localId).set({
    status: 'active',
    isPremium: true,
    source: 'test',
  });

  return { owner, reviewer, stranger };
}

async function main() {
  const { owner, reviewer, stranger } = await seed();

  const validNotification = await request(owner.idToken, 'fcm_notifications', {
    method: 'POST',
    body: JSON.stringify(fieldsFor({
      recipientUid: stringValue(reviewer.localId),
      senderUid: stringValue(owner.localId),
      title: stringValue('Task update'),
      body: stringValue('A task needs your attention.'),
      data: mapValue({
        taskId: stringValue('task-1'),
        partnershipId: stringValue('partnership-1'),
      }),
      createdAt: timestampValue(),
      delivered: boolValue(false),
    })),
  });
  if (!validNotification.ok) {
    throw new Error(`Valid notification was denied: ${await validNotification.text()}`);
  }

  await expectDenied(
    await request(stranger.idToken, 'fcm_notifications', {
      method: 'POST',
      body: JSON.stringify(fieldsFor({
        recipientUid: stringValue(reviewer.localId),
        senderUid: stringValue(stranger.localId),
        title: stringValue('Spam'),
        body: stringValue('Not a participant.'),
        data: mapValue({ taskId: stringValue('task-1') }),
        createdAt: timestampValue(),
        delivered: boolValue(false),
      })),
    }),
    'unrelated notification sender',
  );

  await expectDenied(
    await request(owner.idToken, 'fcm_notifications', {
      method: 'POST',
      body: JSON.stringify(fieldsFor({
        recipientUid: stringValue(owner.localId),
        senderUid: stringValue(owner.localId),
        title: stringValue('Self'),
        body: stringValue('Self notification.'),
        data: mapValue({ taskId: stringValue('task-1') }),
        createdAt: timestampValue(),
        delivered: boolValue(false),
      })),
    }),
    'self notification',
  );

  const ownEntitlement = await request(
    owner.idToken,
    `entitlements/${owner.localId}`,
    { method: 'GET' },
  );
  if (!ownEntitlement.ok) {
    throw new Error(`Owner entitlement read was denied: ${await ownEntitlement.text()}`);
  }

  await expectDenied(
    await request(reviewer.idToken, `entitlements/${owner.localId}`, {
      method: 'GET',
    }),
    'cross-account entitlement read',
  );

  console.log('Firestore security rule smoke tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
