const projectId = 'demo-proof-votes';
const firestore = `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;
const authUrl =
  'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key';

const str = (value) => ({ stringValue: value });
const timestamp = () => ({ timestampValue: new Date().toISOString() });
const arr = (values) => ({
  arrayValue: { values: values.map((value) => value) },
});
const object = (fields) => ({ mapValue: { fields } });
const fieldsFor = (data) => ({
  fields: Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, value]),
  ),
});

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
  if (!response.ok) throw new Error(`Auth sign-up failed: ${await response.text()}`);
  return response.json();
}

async function write(token, taskId, data, masks = null) {
  const url = new URL(`${firestore}/accountability_tasks/${taskId}`);
  for (const mask of masks ?? []) url.searchParams.append('updateMask.fieldPaths', mask);
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(fieldsFor(data)),
  });
  return response;
}

async function expectDenied(response, label) {
  if (response.ok) throw new Error(`${label}: expected rules denial`);
  if (response.status !== 403) {
    throw new Error(`${label}: expected 403, got ${response.status}: ${await response.text()}`);
  }
}

async function main() {
  const [owner, reviewer1, reviewer2] = await Promise.all([
    createUser(),
    createUser(),
    createUser(),
  ]);
  const createTask = async (
    id,
    requiredApprovals = 2,
    status = 'pendingReview',
    proofStatus = 'submitted',
  ) => {
    const response = await fetch(`${firestore}/accountability_tasks?documentId=${id}`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${owner.idToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(fieldsFor({
      assignedByUid: str(owner.localId),
      accountableUid: str(reviewer1.localId),
      accountableUserIds: arr([str(reviewer1.localId), str(reviewer2.localId)]),
      partnerUid: str(reviewer1.localId),
      status: str(status),
      proofStatus: str(proofStatus),
      requiredApprovals: { integerValue: String(requiredApprovals) },
      approvals: arr([]),
      rejections: arr([]),
      approvalUids: arr([]),
      rejectionUids: arr([]),
      })),
    });
    if (!response.ok) throw new Error(`Task create failed: ${await response.text()}`);
  };
  const vote = (uid) => ({
    uid: str(uid),
    name: str('Reviewer'),
    timestamp: timestamp(),
  });

  await createTask('approved-proof', 2, 'approved', 'approved');
  await expectDenied(
    await write(
      owner.idToken,
      'approved-proof',
      { proofUrl: str('tampered-proof-url') },
      ['proofUrl'],
    ),
    'Changing proof after approval',
  );

  await createTask('quorum');
  const firstRecord = object(vote(reviewer1.localId));
  const firstVote = await write(
    reviewer1.idToken,
    'quorum',
    {
      approvalUids: arr([str(reviewer1.localId)]),
      approvals: arr([firstRecord]),
      proofReviewedAt: timestamp(),
    },
    ['approvalUids', 'approvals', 'proofReviewedAt'],
  );
  if (!firstVote.ok) throw new Error(`First approval vote failed: ${await firstVote.text()}`);

  const spoofedVote = await write(
    reviewer2.idToken,
    'quorum',
    {
      approvalUids: arr([str(reviewer1.localId), str(reviewer2.localId)]),
      approvals: arr([object(vote('spoofed-uid'))]),
      proofReviewedAt: timestamp(),
    },
    ['approvalUids', 'approvals', 'proofReviewedAt'],
  );
  await expectDenied(spoofedVote, 'Spoofed vote / erased prior vote');

  await expectDenied(
    await write(
      reviewer2.idToken,
      'quorum',
      {
        approvalUids: arr([str(reviewer1.localId), str(reviewer2.localId)]),
        approvals: arr([
          firstRecord,
          object(vote(reviewer2.localId)),
        ]),
        proofReviewedAt: timestamp(),
        status: str('approved'),
        proofStatus: str('approved'),
        reviewDecision: str('approved'),
        reviewedAt: timestamp(),
        completedAt: timestamp(),
      },
      [
        'approvalUids',
        'approvals',
        'proofReviewedAt',
        'status',
        'proofStatus',
        'reviewDecision',
        'reviewedAt',
        'completedAt',
      ],
    ),
    'Quorum bypass with mismatched vote',
  );

  const finalVote = await write(
    reviewer2.idToken,
    'quorum',
    {
      approvalUids: arr([str(reviewer1.localId), str(reviewer2.localId)]),
      approvals: arr([
        firstRecord,
        object(vote(reviewer2.localId)),
      ]),
      proofReviewedAt: timestamp(),
      status: str('approved'),
      proofStatus: str('approved'),
      reviewDecision: str('approved'),
      reviewedAt: timestamp(),
      completedAt: timestamp(),
    },
    [
      'approvalUids',
      'approvals',
      'proofReviewedAt',
      'status',
      'proofStatus',
      'reviewDecision',
      'reviewedAt',
      'completedAt',
    ],
  );
  if (!finalVote.ok) throw new Error(`Quorum approval failed: ${await finalVote.text()}`);

  await createTask('under-quorum');
  await expectDenied(
    await write(
      reviewer1.idToken,
      'under-quorum',
      {
        approvalUids: arr([str(reviewer1.localId)]),
        approvals: arr([object(vote(reviewer1.localId))]),
        proofReviewedAt: timestamp(),
        status: str('approved'),
        proofStatus: str('approved'),
        reviewDecision: str('approved'),
        reviewedAt: timestamp(),
        completedAt: timestamp(),
      },
      [
        'approvalUids',
        'approvals',
        'proofReviewedAt',
        'status',
        'proofStatus',
        'reviewDecision',
        'reviewedAt',
        'completedAt',
      ],
    ),
    'Approval below quorum',
  );

  await createTask('rejection');
  const rejected = await write(
    reviewer1.idToken,
    'rejection',
    {
      rejectionUids: arr([str(reviewer1.localId)]),
      rejections: arr([object(vote(reviewer1.localId))]),
      proofStatus: str('rejected'),
      proofReviewComment: str('Please resubmit'),
      proofReviewedAt: timestamp(),
      status: str('rejected'),
      reviewDecision: str('rejected'),
      reviewedAt: timestamp(),
    },
    [
      'rejectionUids',
      'rejections',
      'proofStatus',
      'proofReviewComment',
      'proofReviewedAt',
      'status',
      'reviewDecision',
      'reviewedAt',
    ],
  );
  if (!rejected.ok) throw new Error(`Reviewer rejection failed: ${await rejected.text()}`);
  console.log('Proof-vote rule smoke tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
