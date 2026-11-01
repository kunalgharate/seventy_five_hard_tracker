# DailyMettle / 75 Hard Tracker — Security, Privacy, Reliability & Product-Quality Audit

> **CONFIDENTIAL — CLIENT DELIVERABLE**
>
> This report contains exploit paths and remediation detail. The repository
> `github.com/kunalgharate/seventy_five_hard_tracker` is **public** at the time
> of writing. Do **not** commit this file, paste it into an issue, or attach it
> to a public CI artifact until every Critical and High finding is remediated.
> Move it to a private drive or add it to `.gitignore` before the next commit.

| | |
|---|---|
| **Prepared for** | Kunal Gharate, owner of DailyMettle |
| **Repository** | `github.com/kunalgharate/seventy_five_hard_tracker` |
| **Branch / commit** | `fix/partner-task-proof-submission-and-uploads` / `575376cfc2a14aa7cd4f89723690ff88b5673c17` |
| **Audit date** | 25 October 2026 |
| **Report version** | 1.0 |
| **Application version** | `1.0.8+8` |
| **Platforms reviewed** | Flutter (Android, iOS), Firebase, Cloudinary, GitHub Actions, Codemagic |
| **Review type** | Static application security, privacy, reliability and product-quality review |
| **Classification** | Confidential — restricted distribution |

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Scope, method and limitations](#2-scope-method-and-limitations)
3. [Risk dashboard and quantitative baseline](#3-risk-dashboard-and-quantitative-baseline)
4. [Emergency actions — next 72 hours](#4-emergency-actions--next-72-hours)
5. [Detailed findings](#5-detailed-findings)
   - 5.1 [Secrets, signing and supply chain](#51-secrets-signing-and-supply-chain)
   - 5.2 [Firebase authorization and data access](#52-firebase-authorization-and-data-access)
   - 5.3 [Privacy and data protection](#53-privacy-and-data-protection)
   - 5.4 [Backend, monetization and reliability](#54-backend-monetization-and-reliability)
   - 5.5 [Platform and store compliance](#55-platform-and-store-compliance)
   - 5.6 [CI/CD, dependencies and testing](#56-cicd-dependencies-and-testing)
   - 5.7 [Performance, UI/UX and accessibility](#57-performance-uiux-and-accessibility)
   - 5.8 [Code quality and maintainability](#58-code-quality-and-maintainability)
   - 5.9 [Medium and low findings register](#59-medium-and-low-findings-register)
6. [Prioritized remediation roadmap](#6-prioritized-remediation-roadmap)
7. [Retest and verification plan](#7-retest-and-verification-plan)
8. [Appendices](#8-appendices)
9. [Closing assessment](#closing-assessment)

---

## 1. Executive summary

### 1.1 Overall assessment

**Overall risk: CRITICAL. The application is not ready for a public production
launch that handles real user data, payments, or partner-shared content.**

The codebase shows real engineering effort — the Flutter project analyzes
cleanly, 197 tests pass, the Firestore rules contain thoughtful field-level
transition logic, cloud backups use AES-256-GCM, and several privacy guards are
better than the industry average. Those strengths, however, are undermined by a
small number of high-leverage failures:

1. **A live Google Cloud service-account private key and the Android upload
   keystore were published in the public git history.** Deleting the files in a
   later commit does not revoke the credentials. Anyone who cloned or forked the
   repository can recover them. Treat both as compromised now.
2. **The Firestore rules let any signed-in stranger become a "partner" of any
   user, read that user's daily progress, and inject chat messages — without the
   victim's consent.** The same rules let the person who must prove a task
   approve their own proof, which defeats the core accountability product.
3. **Premium monetization is not implemented end-to-end.** The purchase service
   is unreachable from the UI, no backend writes the `entitlements` document,
   and no feature checks the entitlement. Revenue is effectively zero, and a
   store listing that implies a paid tier would be unsupported.
4. **The cloud-backup design can permanently destroy a user's history.** The
   encryption key is random, device-bound, and has no export or recovery path.
   After an Android reinstall or a device change, the app generates a new key,
   fails to decrypt the old backup, and a later auto-sync overwrites the old
   ciphertext with data encrypted under the new key.
5. **Private journal text, runtime font requests and dictation audio leave the
   device to third parties (NVIDIA, Google Fonts, OS speech services), and a
   Gemini integration is coded but unreachable.** None of these flows is
   disclosed or consent-gated, while the in-app privacy copy says "Only you can
   decrypt your data" and "We cannot read your content."

The green CI signal is misleading. `flutter analyze` is clean and all 197 tests
pass, but line coverage is **10.4%** (1,843 of 17,673 measured lines), and the
Firestore rules have only **three** emulator deny assertions. None of the critical
authorization paths above is covered by a test.

### 1.2 Top ten findings

| # | ID | Finding | Severity | Business consequence |
|---|---|---|---|---|
| 1 | SEC-01 | Live GCP service-account private key in public git history | **Critical** | Cloud project takeover, data breach, billing abuse |
| 2 | SEC-02 | Android upload keystore in public git history | **Critical** | App signing identity compromise, malicious releases |
| 3 | AUTH-01 | Any user can forge an accepted partnership with any victim | **Critical** | Unauthorized access to progress, task names, photos, chat |
| 4 | AUTH-02 | Any authenticated user can list and claim any pending invite | **Critical** | Partnership hijacking, unsolicited progress sharing |
| 5 | AUTH-03 | The accountable doer can approve their own photo proof | **Critical** | Core accountability promise is bypassable |
| 6 | DATA-01 | Backup key is unrecoverable and can be overwritten after reinstall | **Critical** | Permanent loss of 75-day history; refunds and churn |
| 7 | MON-01 | Premium purchase flow is dead code; entitlements never written | **Critical** | No revenue; if wired, paying users receive nothing |
| 8 | AUTH-05 | `users` collection is world-readable to every signed-in user | **High** | Email/name/photo/FCM-token enumeration; phishing |
| 9 | PRIV-01 | Journal text sent to NVIDIA and fonts fetched from Google without disclosure | **High** | GDPR/CCPA, Play Data Safety, App Store privacy breach |
| 10 | INFRA-02 | No backend: entitlements, notifications, expiry and rate limits are client-side | **High** | Every server-side control is bypassable; unreliable features |

### 1.3 What is already working well

This is not a "rewrite it" report. The following controls are genuinely good and
should be preserved during remediation:

- **Entitlements are server-authoritative by design.** `entitlements/{uid}` is
  read-only to clients (`allow write: if false`), and the entitlement parser
  requires a recognized active status plus a non-expired timestamp instead of
  trusting a boolean (`lib/core/services/premium_entitlement_service.dart:48-93`).
- **Task transitions have field-level whitelists.** Most `accountability_tasks`
  updates are gated by `diff().affectedKeys().hasOnly([...])`, with separate
  branches for claim, submit, review, expire, accept, proof submit and proof
  vote (`firestore.rules:414-600`). This is well above typical Firebase rules.
- **Proof voting is append-only and single-vote.** The rules enforce one UID per
  vote, matching array lengths, and quorum checks
  (`firestore.rules:79-112`, `135-196`). The intent is strong; the role check is
  inverted (AUTH-03).
- **Backups are authenticated encryption.** AES-256-GCM with a random 96-bit
  nonce and a 128-bit tag. New writes never downgrade to the legacy key, and
  encryption fails closed if secure storage cannot persist a key
  (`lib/core/services/cloud_sync_service.dart:35-56`, `439-537`). The gap is
  lifecycle, not cryptography: a *missing* key is silently replaced, which is
  the root of DATA-01.
- **Cloudinary uploads are signed.** Unsigned Cloudinary uploads are rejected,
  and the signer contract validates the timestamp and requires an API key and
  cloud name (`lib/core/services/photo_sync_service.dart:203-252`). When the
  signer is not configured the app falls back to Firebase Storage, which is a
  separate and currently unverified posture (INFRA-01).
- **Cleartext traffic is disabled on Android** and the network security config
  trusts only system roots in release (`android/app/src/main/res/xml/network_security_config.xml`).
- **Analytics is deliberately content-minimized.** Event payloads exclude
  challenge titles, task names, journal text and notes; there is no advertising
  or cross-app tracking SDK (`lib/core/services/analytics_service.dart:16-30`).
- **Cross-account isolation exists.** `DataOwnership` prevents one account's
  local data from being shown or uploaded under another account, and the offline
  outbox has explicit account-isolation tests
  (`lib/core/services/data_ownership.dart`, `test/bug_regression_test.dart`).
- **Sign-out is safety-gated.** The app refuses to clear local data or sign out
  when the pre-sign-out backup fails
  (`lib/screens/profile_screen.dart:1003-1078`).

### 1.4 Audit limitations

This review was performed without console or production access. It did **not**
include:

- live exploitation against the production Firebase project, Cloudinary
  account, or Play Console;
- inspection of the actual Firebase Storage bucket rules, IAM policy, Play App
  Signing enrolment, or Cloud Audit Logs;
- device-level profiling (cold-start traces, frame timings, memory) or a
  physical accessibility audit;
- legal advice. Privacy and store-compliance findings are engineering
  observations, not legal opinions.

Where a conclusion depends on console state, the report says so explicitly and
gives the exact check to perform. No production data was read or modified, and
no source file was changed by this audit.

---

## 2. Scope, method and limitations

### 2.1 Scope

| Area | Reviewed |
|---|---|
| Dart/Flutter source | 139 files under `lib/`, 47,380 lines |
| Tests | 27 files, 5,872 lines, 197 test cases |
| Firebase | `firestore.rules` (618 lines), `firestore.indexes.json` (17 indexes), `firebase.json`, Auth, Firestore, Storage, FCM, Analytics, Crashlytics |
| Cloudinary | Upload signer contract, proof and avatar upload paths |
| Secrets | Full git history, working tree, CI configuration, build artifacts |
| Android | Manifest, Gradle config, signing, permissions, backup, network security |
| iOS | `Info.plist`, entitlements, privacy manifest, signing/CI |
| CI/CD | GitHub Actions, Codemagic, Dockerfile |
| Product | Purchase flow, premium gating, account lifecycle, backup/restore |
| UI/UX | Screen structure, state management, lists, images, fonts, accessibility |
| Dependencies | `pubspec.yaml`, `pubspec.lock`, `flutter pub outdated` |

### 2.2 Method

1. **Repository and history forensics.** Full `git log`, `git rev-list`,
   `git cat-file`, blob-size analysis, secret-pattern search across all commits,
   and comparison of working-tree signing material with historical blobs.
2. **Static review.** Manual reading of the security-sensitive paths: rules,
   authentication, partnership lifecycle, proof review, backup encryption,
   purchase flow, photo upload, account switching, startup.
3. **Tool-assisted checks.** `flutter analyze`, `flutter test`,
   `flutter test --coverage`, `flutter pub outdated`, `grep`-based metrics for
   code smells, widget patterns and logging.
4. **Threat modeling.** Two-account attacker models (stranger, invited user,
   partner, doer, reviewer) and a device-loss/reinstall model.
5. **Evidence capture.** Every finding is tied to a file and line, a commit, or
   a reproducible command. Where the issue is a design gap rather than a single
   line, the report cites the full path and the relevant functions.

### 2.3 Severity definitions

| Severity | Meaning |
|---|---|
| **Critical** | Exploitable now with severe confidentiality, integrity, financial or existential business impact; or a certain, unrecoverable data-loss path. Fix before any public release. |
| **High** | Likely exploitation or major privacy/revenue/compliance impact; or a control that is trivially bypassable. Fix within 30 days. |
| **Medium** | Defence-in-depth gap, significant quality/performance issue, or a compliance risk that needs a planned fix. Fix within 90 days. |
| **Low** | Hygiene, consistency, documentation or minor hardening. Schedule opportunistically. |

Indicative CVSS 3.1 ranges are given for Critical findings only. They are
estimates, not certified scores; the actual score depends on IAM scope, store
enrolment and deployment state.

---

## 3. Risk dashboard and quantitative baseline

### 3.1 Codebase and quality baseline

| Metric | Value | Comment |
|---|---:|---|
| Dart files in `lib/` | 139 | 166 including tests |
| Lines of Dart in `lib/` | 47,380 | Largest file: 4,706 lines |
| Test files | 27 | 5,872 lines |
| Test cases | 197 | All passing |
| Line coverage | **10.4%** | 1,843 / 17,673 lines across 120 measured files |
| `flutter analyze` | **0 issues** | No errors, warnings or infos |
| Firestore rules | 618 lines | 13 collection paths (11 top-level + 2 subcollections) |
| Firestore composite indexes | 17 | 13 for `accountability_tasks` |
| Rules test assertions | **3** | 163-line smoke file; 3 deny checks plus 2 positive checks |
| Tracked files | 429 | 40 Markdown, 45 `.kiro` files |
| Git history | 221 commits, 58,725 objects | `.git` = **4.0 GB** |
| Android permissions | 14 | Includes exact alarm, DND, full-screen intent |
| iOS usage descriptions | 5 | Camera, mic, speech, photo library read/add |
| `print` / `debugPrint` sites | 294 | Several unguarded in release paths |
| Empty or swallow-all catches | 35 empty; 78 `catch (_)` | Silent feature failures |
| `dynamic` usages | 178 | Weak typing at boundaries |
| Singleton services | 27 | Hidden global state |
| `setState` in largest screen | 39 | 4,706-line `accountability_screen.dart` |
| `GoogleFonts.` call sites | 147 | Runtime font fetching by default |
| Eager `ListView(` vs `ListView.builder` | 15 vs 10 | Long lists built eagerly |
| `Image.network` vs `CachedNetworkImage` | 10 vs 1 | Repeated network/decode work |
| `Semantics` / `Tooltip` widgets | 3 / 3 | Very low accessibility coverage |
| Hard-coded `fontSize:` values | 458 | Poor text-scale and theme behavior |
| Fixed `Colors.white` / `Colors.black` | 255 | Dark-mode and contrast risk |

### 3.2 Findings by severity

| Severity | Count | Share |
|---|---:|---:|
| Critical | 7 | 11.9% |
| High | 20 | 33.9% |
| Medium | 18 | 30.5% |
| Low | 14 | 23.7% |
| **Total** | **59** | **100%** |

### 3.3 Domain scorecard

| Domain | Rating | Reason |
|---|---|---|
| Secrets and signing | **Critical** | Live cloud key and upload keystore in public history |
| Firebase authorization | **Critical** | Partnership forgery, invite claim, self-approval |
| Privacy and data protection | **High** | Undisclosed AI processors, EXIF GPS, unencrypted local data, weak backup recovery |
| Monetization | **Critical** | Purchase flow unreachable; no entitlement writer; no gated features |
| Reliability and data safety | **High** | Backup overwrite, startup crash path, broken expiry/notification features |
| Platform and store compliance | **High** | No account deletion, no Sign in with Apple, broad permissions |
| CI/CD and supply chain | **High** | Production publish without tests, secrets in artifacts, tag-pinned actions |
| Testing | **High** | 10.4% coverage; 3 rules assertions; critical paths untested |
| Performance and UI/UX | **Medium** | Very large screens, rebuild storms, eager lists, low accessibility |
| Code quality | **Medium** | Error swallowing, 3,467-line service, duplicate notification stacks |

### 3.4 Firestore collection coverage

| Collection used by the client | Has rules? | Notes |
|---|---|---|
| `users` | Yes | World-readable to any signed-in user (AUTH-05) |
| `partnerships` (+ `messages`) | Yes | One-sided accepted creation and unclaimed-invite claim (AUTH-01/02) |
| `partner_reviews` | Yes | Any signed-in user may review any subject (AUTH-04) |
| `public_progress` (+ `days`) | Yes | Reader list is client-maintained; derives from unverified partnerships |
| `accountability_tasks` | Yes | Create has no field whitelist; proof reviewer role inverted (AUTH-03/06) |
| `invitations` | Yes | Update has no field whitelist (AUTH-07) |
| `invite_codes` | Yes | Listable by any signed-in user (AUTH-02) |
| `entitlements` | Yes | Read-only; **no server writer exists** (MON-01) |
| `user_data` | Yes | Owner-only; key recovery is broken (DATA-01) |
| `task_collaborators` | Yes | Owner/collaborator read; owner write |
| `fcm_notifications` | Yes | Participant-validated create; recipient read |
| `accountability_notifications` | **No** | Client writes/reads are denied by default (FUNC-01) |
| `streak_actions` | **No** | Client writes/reads are denied by default (FUNC-01) |
| Cloud Storage (`task_proofs`, `profile_avatars`) | **No `storage.rules`** | Bucket posture unknown (INFRA-01) |

### 3.5 Dependency drift (direct dependencies)

| Package | Resolved | Latest | Gap |
|---|---:|---:|---|
| `firebase_core` | 3.15.2 | 5.1.0 | 2 major |
| `firebase_auth` | 5.7.0 | 7.0.1 | 2 major |
| `cloud_firestore` | 5.6.12 | 7.1.0 | 2 major |
| `firebase_analytics` | 11.6.0 | 13.0.1 | 2 major |
| `firebase_crashlytics` | 4.3.10 | 6.0.1 | 2 major |
| `firebase_messaging` | 15.2.10 | 17.0.1 | 2 major |
| `firebase_storage` | 12.4.10 | 14.0.1 | 2 major |
| `intl` | 0.19.0 | 0.20.3 | 1 minor (breaking for some APIs) |
| `cached_network_image` | 3.4.1 | 4.0.5 | 1 major |
| `equatable` | 2.0.7 | 3.0.0 | 1 major |
| `animated_text_kit` | 4.2.3 | 4.3.0 | 1 minor |
| `connectivity_plus` | 7.3.1 | 7.3.2 | patch |
| `cupertino_icons` | 1.0.8 | 2.0.0 | 1 major |

The Firebase family is two major versions behind. That is not automatically a
CVE, but it means the app is not receiving the current security fixes, is
exposed to platform/target-SDK incompatibilities, and will face a much larger
migration later. There is no Dependabot or Renovate configuration.

---

## 4. Emergency actions — next 72 hours

These are ordered by risk reduction per hour. Do them before any feature work.

| # | Action | Why | Owner | Time |
|---|---|---|---|---|
| 1 | **Revoke/delete the leaked GCP service-account key** in IAM → Service Accounts → Keys. Remove all IAM roles from the account; delete it if unused. | The private key is in public history. Deletion of the file did not revoke it. | Cloud admin | 15 min |
| 2 | **Audit Cloud Audit Logs** for that service account over the last 90 days: token creation, `SetIamPolicy`, Firestore/Storage reads, Play Developer API calls, billing changes. | Determine whether the key was already used. | Cloud admin | 1–2 h |
| 3 | **Rotate the Android upload key** in Play Console → App integrity → App signing → request upload key reset. Generate a new keystore with strong passwords; update CI secrets. | The keystore is byte-identical to the leaked blob. | Android lead | 1–2 h + Google review |
| 4 | **Confirm Play App Signing status.** If it is not enabled, escalate immediately: the upload key may be the app signing key. | Determines whether malicious updates can be signed. | Android lead | 15 min |
| 5 | **Make the repository private** until history is purged and secrets are rotated. | Every clone/fork retains the old blobs. | Owner | 5 min |
| 6 | **Disable the APK artifact upload** in `.github/workflows/dart.yml` or remove the `NVIDIA_API_KEY` define. Delete existing artifacts. | The artifact embeds a billable API key. | DevOps | 15 min |
| 7 | **Rotate `NVIDIA_API_KEY`, `GEMINI_API_KEY`, `API_NINJAS_KEY`** and any Cloudinary/Play/Teams secrets that may have been exposed. | Assume all build-time secrets in the public repo are compromised. | Owner | 1 h |
| 8 | **Fix the partnership create/claim rules and the proof reviewer role** (AUTH-01/02/03), then deploy rules and add regression tests. | These are remotely exploitable by any signed-in user today. | Backend | 1–2 days |
| 9 | **Add `storage.rules` and deploy** after verifying the bucket's current posture. | Proof photos and avatars currently have no declared authorization. | Backend | 2–4 h |
| 10 | **Freeze production publishing** from Codemagic until tests/analyze are gates. | A tag currently ships straight to production/TestFlight. | Release manager | 15 min |

> **Do not** simply run `git rm` and commit. That leaves the blobs in history.
> Use `git filter-repo` (or BFG) and force-push, then ask GitHub Support to
> purge cached views and forks. Rotate the credentials **first**; history
> rewriting is not a revocation mechanism.

---

## 5. Detailed findings

### 5.1 Secrets, signing and supply chain

#### SEC-01 · Live GCP service-account private key published in public git history

**Severity:** Critical · **Confidence:** High · **Effort:** 4–8 hours emergency, 1–2 days verification
**Indicative CVSS 3.1:** 9.1–9.8 (scope depends on the service account's IAM roles)

**Evidence**

- Commit `b45e07d04cc3711761df2713b9e577c6dabbd87b` (2026-03-12 17:24:46 +0530)
  added `dayschallenge-485316-17a730d184c4.json`, a Google Cloud service-account
  key.
- Commit `f3c8a896dc2669f1b70247b1a2e5663f4a3d5aba` removed it **59 seconds
  later**. The blob remains in `.git` and is reachable from the public commit.
- The repository is public and had **2 forks** at the time of review. Forks and
  clones retain the object even after a force-push.
- The current local `service-account-base64.txt` (untracked, gitignored)
  decodes to the same identity: `project_id: dayschallenge-485316`,
  `private_key_id: 17a730d184c4...`, `client_email:
  id-5dayschallenge@dayschallenge-485316.iam.gserviceaccount.com`. The private
  key itself is **not reproduced in this report**.
- There is no evidence in the repository that the key was revoked. Absence of
  evidence is not evidence of revocation; treat it as live until the IAM console
  proves otherwise.

**Description**

A service-account JSON key contains an RSA private key that can be exchanged for
OAuth 2.0 access tokens without any user interaction, MFA, or device binding. It
does not expire unless it is explicitly revoked. Committing it once is
equivalent to publishing a password that never changes.

**Exploit path**

1. Clone the public repository or download the commit tarball.
2. Extract `dayschallenge-485316-17a730d184c4.json` from the commit tree.
3. `gcloud auth activate-service-account --key-file key.json`.
4. Enumerate accessible projects and resources (`gcloud projects list`,
   `gcloud firestore databases list`, `gcloud storage buckets list`).
5. Read, modify or delete data according to the account's IAM roles; create
   additional keys or service accounts if `iam.serviceAccountKeys.create` is
   allowed; publish to Play if the account has Play Developer permissions.

**Impact**

- **Confidentiality:** Firestore documents, Storage objects, backups, user PII.
- **Integrity:** modification or deletion of user data; IAM persistence.
- **Availability:** project/resource deletion; billing abuse.
- **Supply chain:** if the same credential is used by Codemagic's
  `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` for Play publishing, an attacker could
  attempt a malicious release (subject to Play Console permissions and review).
- **Regulatory:** a personal-data breach requiring notification under GDPR/DPDP.

The project ID (`dayschallenge-485316`) differs from the current Firebase
project (`dailymettle`), which may limit blast radius. That is **not** a reason
to delay: the key may have organization-level roles, may be reused by CI, or may
still have access to shared resources. Verify, do not assume.

**Remediation**

1. **Revoke now:** IAM → Service Accounts → select the account → Keys → delete
   key `17a730d184c4...`. If the account is not needed, delete the account.
2. **Remove IAM bindings** from the account and review organization-level
   inheritance.
3. **Audit logs:** filter `protoPayload.authenticationInfo.principalEmail` for
   the service account over 90 days. Look for `GenerateAccessToken`,
   `SetIamPolicy`, `CreateServiceAccountKey`, Firestore/Storage data access,
   Play Developer API calls, and billing changes. Preserve the logs.
4. **Rotate downstream secrets** that were stored in the same project or CI
   group: Codemagic `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`, any Cloudinary secret,
   Play service-account JSON, Teams webhook.
5. **Purge history** with `git filter-repo --path
   dayschallenge-485316-17a730d184c4.json --invert-paths` (and the base64
   variants), force-push all branches/tags, and ask GitHub Support to purge
   cached views and forks. Re-run secret scanning afterwards.
6. **Prevent recurrence:** enable GitHub secret scanning and push protection;
   add `gitleaks` to pre-commit and CI; add a `.gitignore` rule for
   `*service-account*.json`, `*-base64*.txt`, `*.jks`, `*.keystore`,
   `key.properties`; use workload identity federation or OIDC instead of static
   keys.
7. **Consider a full history rewrite** for the repository (M9), since the
   same commit also contains the keystore and build docs.

**Verification**

- `gcloud iam service-accounts keys list --iam-account=<sa>` shows only the new
  key (or none).
- `git log --all -- dayschallenge-485316-17a730d184c4.json` returns nothing
  after the rewrite.
- GitHub secret-scanning alerts are closed and push protection is on.
- A fresh `git clone` followed by `grep -R "private_key"` finds nothing.
- Audit-log review is documented and signed off.

---

#### SEC-02 · Android upload keystore published in public git history

**Severity:** Critical · **Confidence:** High · **Effort:** 1–3 days plus Google review
**Indicative CVSS 3.1:** 8.1–9.1 (depends on Play App Signing enrolment)

**Evidence**

- Commit `b45e07d0` added `keystore-base64.txt`,
  `keystore-base64-single-line.txt` and `keystore-clean.txt`.
- The current workspace `upload-keystore.jks` is **byte-identical** (SHA-256
  match) to the blob obtained by base64-decoding the historical
  `keystore-base64.txt`.
- The same commit added `KEYSTORE_SETUP.md`, which documents the key alias
  (`upload`), the CI variable names, and the fact that the file is the upload
  keystore.
- `.gitignore` now ignores `*.jks` and `*.keystore`, but the objects remain in
  history and in every existing clone/fork.
- `upload_certificate.pem` is still tracked in `HEAD` (public certificate only;
  low sensitivity, but it confirms the signing identity and should be removed).

**Description**

An Android keystore contains the private key used to sign app bundles. If an
attacker has the keystore and its passwords, they can sign code that Android
treats as coming from the same developer identity. The repository does not
contain the passwords in plaintext, but the key material is exposed; password
strength is now the only barrier and is not an acceptable control.

**Impact depends on Play App Signing**

- **If Play App Signing is enabled (recommended):** Google holds the app signing
  key; the uploaded keystore is only an upload key. An attacker cannot publish
  to your Play listing without Play Console credentials. They can still sign
  APKs with the upload key and distribute them outside Play; devices that
  installed those APKs may accept updates signed with the same key. The upload
  key must be reset.
- **If Play App Signing is not enabled:** the upload key **is** the app signing
  key. An attacker can sign a malicious update that existing users' devices will
  accept, and you may be unable to ship a legitimate update without a key
  rotation or a new package. This is an existential supply-chain risk.

**Exploit path**

1. Recover `keystore-base64.txt` from the public commit.
2. Base64-decode to `upload-keystore.jks`.
3. Recover or brute-force the store/key password (the alias is documented; weak
   passwords are common).
4. Build a modified AAB/APK, sign it, and distribute it via phishing, third-party
   stores, or a compromised update channel. If Play signing is not enabled, the
   signature matches the production app.

**Remediation**

1. Check Play Console → Setup → App integrity. Record whether Play App Signing
   is enabled and whether the upload certificate matches the leaked keystore.
2. Request an **upload key reset** through Play Console. Generate a new keystore
   with a long random password stored in a secrets manager, not in a text file.
3. Update Codemagic `CM_KEYSTORE`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_PASSWORD`,
   `CM_KEY_ALIAS` and GitHub `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
   `KEY_PASSWORD`, `KEY_ALIAS`.
4. Verify the old key is rejected by Play and that a new AAB can be uploaded.
5. If Play App Signing is not enabled, follow Google's app signing key rotation
   process; expect additional review and possibly a new package name.
6. Purge the keystore from git history (same rewrite as SEC-01).
7. Remove `upload_certificate.pem` from tracking; keep certificates in a private
   archive.
8. Audit releases and installs for unexpected builds; monitor Play Console for
   unauthorized uploads.

**Verification**

- Play Console shows a new upload certificate and the old one is revoked.
- A build signed with the old keystore is rejected.
- `git log --all -- '*keystore*'` is empty after the rewrite.
- CI secrets are rotated and access is limited to release managers.

---

#### SEC-03 · Billable AI API key embedded in release APKs and CI artifacts

**Severity:** High · **Confidence:** High · **Effort:** 3–5 days

**Evidence**

- `.github/workflows/dart.yml:65-67` builds a **release APK** with
  `--dart-define=NVIDIA_API_KEY=${{ secrets.NVIDIA_API_KEY }}`.
- Lines 74–79 upload `app-release.apk` as a downloadable Actions artifact with
  30-day retention.
- `lib/core/constants/api_constants.dart:37-45` reads `NVIDIA_API_KEY` via
  `String.fromEnvironment`; `lib/features/ai_accountability/data/services/tron_ai_service.dart:47-70`
  puts it in an `Authorization: Bearer` header.
- `GeminiService` places its key in the **URL query string**
  (`gemini_service.dart:22-25`), which is more likely to be captured by proxies,
  logs and crash reports.
- No Firebase App Check, attestation, per-user quota, or server-side proxy is
  used.

**Description**

`--dart-define` values are compiled into the application binary. Obfuscation
renames symbols; it does not encrypt string constants. An attacker can run
`strings`, `jadx`, `apktool`, or `blutter` on the APK and recover the key. The
CI artifact makes this even easier: it is a ready-made release binary with the
key inside, downloadable by anyone with repository Actions access.

**Impact**

- Direct financial loss from stolen inference quota.
- Denial of service for legitimate users when the quota is exhausted.
- Forced key rotation, which breaks older app versions.
- Terms-of-service violation with the AI provider.
- If the key is shared with other services, lateral access.

**Remediation**

1. Remove all provider keys from client builds. Route AI calls through a Cloud
   Function/Cloud Run service that holds the key in Secret Manager.
2. Require Firebase Auth, App Check (Play Integrity/DeviceCheck), per-user rate
   limits, request size limits, and prompt validation at the proxy.
3. Rotate the NVIDIA and Gemini keys now; invalidate old artifacts.
4. Stop uploading release APKs as artifacts, or build a keyless variant for
   artifacts.
5. Never put secrets in URLs; use headers and redact logs.
6. Add a CI check that scans the built APK/AAB for known secret patterns before
   upload.

**Verification**

- `strings app-release.apk | grep -E 'nvapi|AIza'` returns nothing.
- The proxy rejects unauthenticated and over-quota requests.
- Artifacts no longer contain billable credentials.

---

#### M9 · Repository history and internal documents are bloated and leak IP

**Severity:** Medium · **Effort:** 1–2 days (after secret purge)

Summary: `.git` is **4.0 GB** for a 47k-line app,
with 58,725 objects and repeated ~170 KB revisions of
`accountability_screen.dart`. The repository tracks 40 Markdown files and 45
`.kiro` files, including AI prompts, specs, `FINAL_SUMMARY.txt`,
`debug_changes.patch` and `img.png`. This increases clone time, CI cost, secret
surface, and exposes internal product/engineering reasoning.

---

### 5.2 Firebase authorization and data access

The rule set is unusually ambitious for a Flutter app: most task updates are
field-whitelisted, votes are append-only, and entitlements are server-only. The
failures below are not "Firebase is insecure"; they are specific missing
predicates and missing whitelists in an otherwise thoughtful rule set.

The common root cause is that **the client is trusted to assert
relationships**. A partnership, a review, a task assignment and an invitation
are all created by writing a document that *claims* a relationship, and the
rules verify only that the writer stamped their own UID — not that the other
party consented or that the relationship already exists.

#### AUTH-01 · Any user can forge an accepted partnership with any victim

**Severity:** Critical · **Confidence:** High · **Effort:** 2–3 days
**Indicative CVSS 3.1:** 8.1–8.8 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N)

**Evidence**

- `firestore.rules:207-209` — creation validates only the owner field:

  ```
  match /partnerships/{partnershipId} {
    allow create: if request.auth != null
                  && request.resource.data.ownerUid == request.auth.uid;
  ```

  `partnerUid`, `status`, `partnerEmail`, `role`, `ownerName` and `partnerName`
  are all attacker-chosen. Nothing requires the other party to exist, consent,
  or even be a registered user.
- `lib/features/human_accountability/data/datasource/accountability_service.dart:734-795`
  (`ensurePartnership`) **upgrades an existing pending partnership to
  `accepted`** without checking which side the caller is:

  ```
  await _db.collection('partnerships').doc(existing.id).update({
    'status': 'accepted',
    'acceptedAt': now.toIso8601String(),
    'partnerName': otherName,
    'ownerName': currentUserDisplayName,
    'ownerEmail': _myEmail,
  });
  ```

  This is called when assigning a task or adding a collaborator, so a single
  user action can complete a partnership one-sidedly, without the other party
  accepting anything.
- `_acceptedPartnerUids()` (`accountability_service.dart:590-601`) reads every
  partnership where the current user is `ownerUid` or `partnerUid` with
  `status == 'accepted'`, including forged ones.
- `_syncAllowedReaders()` (`accountability_service.dart:614-625`) writes that
  list into `public_progress/{uid}.allowedReaders`.
- `firestore.rules:277-284` then authorises anyone in `allowedReaders` to read
  the victim's aggregate progress, and `:285-288` authorises the `days`
  subcollection (per-day completion, task names and notes).
- `fetchMyPartnerships()` merges owner-side and partner-side queries
  (`accountability_service.dart:515-560`), so the victim's UI treats the forged
  document as a real partner.

**Exploit path**

1. Attacker A signs in and reads victim V's UID and email (AUTH-05 makes this
   trivial).
2. A creates a partnership document:

   ```json
   {
     "ownerUid": "A",
     "partnerUid": "V",
     "partnerEmail": "v@example.com",
     "partnerName": "V",
     "ownerName": "A",
     "status": "accepted",
     "acceptedAt": <now>,
     "role": "accountability_partner"
   }
   ```

   The create rule passes because `ownerUid == A`.
3. V's app loads partnerships where `partnerUid == V`; the forged document is
   included and displayed as an accepted partner.
4. On V's next progress publish, `_acceptedPartnerUids()` includes A and
   `_syncAllowedReaders()` writes A into `public_progress/V.allowedReaders`.
   Nothing asks V to confirm.
5. A reads `public_progress/V` and `public_progress/V/days/*`: completion
   history, task names, notes, streak state.
6. A can also post into the partnership chat (`partnerships/{id}/messages`),
   which V sees as a message from their "partner", and can trigger review
   prompts and task assignments against V.

**Impact**

- **Confidentiality:** unauthorised access to another user's habit, task and
  journal-adjacent data. Task names and notes frequently contain health,
  relationship and work information.
- **Integrity:** the attacker can send messages, create tasks and inject
  reviews into the victim's accountability surface.
- **Safety:** an attacker can insert themselves into a vulnerable user's
  support network — stalking and harassment risk, not just data exposure.
- **Scale:** the attack is scriptable against every UID in the `users`
  collection; no invitation, email, or code is required.

**Remediation**

1. Partnership creation must produce a **pending** request with
   `partnerUid: null` and no privileged fields:
   `status == 'pending'`, `createdBy == auth.uid`, `ownerUid == auth.uid`,
   `partnerEmail` verified as a syntactically valid address.
2. Acceptance must be a separate transition performed by the invited party:
   `resource.data.status == 'pending'`
   && `resource.data.partnerEmail == request.auth.token.email`
   && `request.auth.token.email_verified == true`
   && `request.resource.data.status == 'accepted'`
   && `request.resource.data.partnerUid == request.auth.uid`
   && `affectedKeys().hasOnly(['partnerUid','status','acceptedAt'])`.
3. Delete the `ensurePartnership` status upgrade. If a pending document exists,
   return it and let the invitee accept through the proper flow. Rename it to
   `findPartnership` to make the side-effect-free contract clear.
4. Write `allowedReaders` from a Cloud Function that recomputes it from
   accepted partnerships, not from the client. Until then, add a rule that
   prevents a client from adding a UID that is not an accepted partner.
5. Add a "block/report partner" control and a visible partner list with
   accepted-on dates, so an unexpected partner is noticeable.
6. Add emulator tests: forged accepted create → `403`; pending create by a
   non-owner → `403`; accept by the wrong email → `403`; `allowedReaders`
   injection → `403`.
7. Notify both parties when a partnership is created or accepted, with the
   other party's name and email, so silent additions are visible.

**Verification**

- Creating a partnership with `status: 'accepted'` and a non-null `partnerUid`
  is rejected.
- Only the invited email can move a request to accepted.
- `public_progress.allowedReaders` contains only UIDs with an accepted,
  two-sided partnership.
- The victim's partner list shows a pending request that they can decline.

---

#### AUTH-02 · Any signed-in user can list invite codes and claim any pending partnership

**Severity:** Critical · **Confidence:** High · **Effort:** 2 days
**Indicative CVSS 3.1:** 8.1–8.8 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N)

**Evidence**

- `firestore.rules:11-19` makes the entire `invite_codes` collection readable
  by any authenticated user:

  ```
  match /invite_codes/{code} {
    allow read: if request.auth != null;
    allow create: if request.auth != null
                  && request.resource.data.ownerUid == request.auth.uid;
    allow delete: if request.auth != null
                  && resource.data.ownerUid == request.auth.uid;
  }
  ```

  A collection-level read permits `list`, so an attacker does not need to guess
  a code.
- `firestore.rules:227-234` lets **any** caller claim a pending partnership:

  ```
  || (resource.data.partnerUid == null
      && request.resource.data.partnerUid == request.auth.uid
      && request.resource.data.status == 'accepted')
  || (resource.data.partnerUid == ''
      && request.resource.data.partnerUid == request.auth.uid
      && request.resource.data.status == 'accepted')
  ```

  There is no check that the caller knows the invite code, matches
  `partnerEmail`, or was invited.
- `lib/features/human_accountability/data/datasource/accountability_service.dart:2220-2300`
  (`acceptInvitation`) deliberately performs an update-only claim without
  reading the pending document, which is why the rule was written this way.
- Codes are six characters generated from a small alphabet
  (`accountability_service.dart:73`), but guessing is unnecessary because the
  collection is listable.

**Exploit path**

1. Sign in as attacker A.
2. `db.collection('invite_codes').get()` → every code and its `partnershipId`.
3. Optionally filter by `ownerUid` to target a specific user.
4. Update the corresponding `partnerships/{id}` with
   `partnerUid: A`, `status: 'accepted'`, `acceptedAt: now`.
5. The rule permits the update; A is now a member. A can read the chat, appears
   as the victim's partner, and receives shared progress.
6. The legitimate invitee is locked out: the document is already claimed, and
   the owner has no signal that the wrong person joined.

**Impact**

- **Partnership hijacking:** the attacker becomes the accountability partner of
  any user with a pending invite.
- **Chat and progress access:** messages, task assignments, daily completion
  data and any content the victim shares with "their partner".
- **Social engineering:** the attacker now has a trusted channel and can ask
  for money, credentials or personal information.
- **Denial of service:** the real invitee cannot accept; the owner must notice
  and remove the attacker.
- **Privacy:** the invite-code list also reveals which users are actively
  inviting partners and when.

**Remediation**

1. Remove collection listing. `allow get: if request.auth != null` is acceptable
   only if codes are unguessable; better, do not expose codes at all. Resolve a
   code through a callable Cloud Function that rate-limits attempts and returns
   only the partnership ID.
2. Store `codeHash = SHA-256(code + per-code salt)` rather than the code, or
   keep the code server-side only.
3. Make codes single-use with `usedAt`, `usedBy`, `expiresAt` (for example
   7 days), and mark them consumed in the same transaction as the claim.
4. Require the claim to prove possession:
   `request.resource.data.inviteCode == code` **and** the code document is
   unexpired/unused **and** the partnership is still pending. Do not rely on
   `partnerUid == null` as proof of authorization.
5. Prefer email-bound invites: acceptance requires
   `partnerEmail == request.auth.token.email` and `email_verified == true`.
6. Add an owner-visible "who joined" confirmation and a revoke control.
7. Add emulator tests: list denied; claim without code denied; claim with a
   used/expired code denied; claim by the wrong email denied.

**Verification**

- `invite_codes` list → `403`.
- Claim with the correct code succeeds once; a replay fails.
- Claim without the code or with the wrong email → `403`.
- The owner sees the accepted partner's identity.

---

#### AUTH-03 · The accountable doer can approve their own proof

**Severity:** Critical · **Confidence:** High · **Effort:** 1 day
**Indicative CVSS 3.1:** 7.5–8.1 (AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)

**Evidence**

- `firestore.rules:99-105`:

  ```
  function isProofReviewer() {
    return resource.data.assignedByUid != request.auth.uid
        && (resource.data.partnerUid == request.auth.uid
            || resource.data.accountableUid == request.auth.uid
            || (resource.data.accountableUserIds is list
                && request.auth.uid in resource.data.accountableUserIds));
  }
  ```

  The only exclusion is `assignedByUid`. The **doer** (`accountableUid` or a
  member of `accountableUserIds`) is explicitly included.
- The approval branch (`firestore.rules:136-160`) requires
  `isProofReviewer()`, a single vote append, and quorum. With the default
  `requiredApprovals == 1`, the doer's own vote is sufficient to finalise.
- The file's own comment contradicts the implementation:
  `firestore.rules:450-452` says "it cannot touch review fields, so the doer can
  never self-approve."
- The Dart client blocks self-approval (`_isReviewerOf`,
  `accountability_service.dart:3237-3245`, returns false when
  `accountableUid == uid`), but the client is not the security boundary. An
  attacker can call the Firestore REST API or the SDK directly.

**Exploit path**

1. A partner assigns a task to doer D (`assignedByUid = partner`,
   `accountableUid = D`, `requiredApprovals = 1`).
2. D submits any proof (including a blank or unrelated image).
3. D sends a single update:

   ```json
   {
     "approvalUids": [D],
     "approvals": [{"uid": "D", "at": <now>, "comment": "done"}],
     "proofReviewedAt": <now>,
     "status": "approved",
     "proofStatus": "approved",
     "reviewDecision": "approved",
     "reviewedAt": <now>,
     "completedAt": <now>
   }
   ```

   `isProofReviewer()` returns true because `accountableUid == D` and
   `assignedByUid != D`. The append-only and quorum checks pass.
4. The task is marked complete. The partner sees an approved task with D's own
   approval recorded as if it came from a reviewer.

**Impact**

- The accountability product's central promise — that a partner verifies the
  work — is bypassable by the person being verified.
- Streak, completion and discipline-score integrity are compromised; a user can
  claim a perfect 75 days without doing the tasks.
- Partners cannot trust the approval record; the audit trail attributes the
  approval to the doer, but the UI presents it as a completed review.
- If the product is sold on "verified accountability", this is a core-value
  defect, not a minor bug.

**Remediation**

1. Define the reviewer set explicitly and exclude the doer:

   ```
   function isProofReviewer() {
     return resource.data.assignedByUid != request.auth.uid
         && request.auth.uid != resource.data.accountableUid
         && !(resource.data.accountableUserIds is list
              && request.auth.uid in resource.data.accountableUserIds)
         && (resource.data.partnerUid == request.auth.uid
             || resource.data.assignedByUid == request.auth.uid);
   }
   ```

   Decide whether `accountableUserIds` should ever review; if multiple doers
   exist, reviewers must be disjoint from that set.
2. Enforce `requiredApprovals >= 1` and
   `approvalUids.size() >= requiredApprovals` with all UIDs distinct and none
   equal to the doer.
3. Add a `reviewerRole` field (`owner`/`partner`) at assignment time and check
   it in the rule, rather than inferring the role from mutable UIDs.
4. Move finalisation to a Cloud Function that validates the transition and
   writes an immutable `reviewEvents` record.
5. Update the misleading comment and add a test that asserts a doer's approval
   is denied for every combination of `accountableUid`/`accountableUserIds`.
6. Audit existing tasks: count approvals where `approvalUids` intersects the
   doer set, and flag them for partner review.

**Verification**

- Doer approval → `403` in the emulator.
- Partner approval → `200`.
- A task with `requiredApprovals: 2` requires two distinct non-doer UIDs.
- Historical tasks with self-approval are listed in an audit report.

---

#### AUTH-04 · Any signed-in user can write a review for any other user

**Severity:** High · **Confidence:** High · **Effort:** 1 day (rules + tests)

**Evidence**

- `firestore.rules:293-301`:

  ```
  match /partner_reviews/{reviewId} {
    allow create: if request.auth != null
                  && request.resource.data.reviewerUid == request.auth.uid;
    allow read: if request.auth != null
                && (resource.data.subjectUid == request.auth.uid
                    || resource.data.reviewerUid == request.auth.uid);
    allow delete: if request.auth != null
                  && resource.data.reviewerUid == request.auth.uid;
  }
  ```

- There is no check that the reviewer and subject are partners, no check that
  `subjectUid != reviewerUid`, no field whitelist, no enum validation, no
  length limit and no rate limit.
- The victim's client displays these documents as review history:
  `lib/features/human_accountability/data/datasource/accountability_service.dart:975-1005`
  (`fetchMyReviews` queries `where('subjectUid', isEqualTo: uid)`), rendered by
  `lib/features/human_accountability/presentation/widgets/reviews_tab.dart`.
- The reviewer's display name is taken from the document
  (`reviewerName`), not resolved from `users`, so it can be set to anything.

**Exploit path**

1. Sign in with any Google account (no invitation required).
2. Write a document to `partner_reviews` with `subjectUid` = the victim's UID,
   `reviewerUid` = the attacker's UID, `decision` = `rejected`,
   `reviewerName` = `"DailyMettle Trust & Safety"`, and an arbitrary `comment`
   (for example, "Your account is restricted — verify at
   `dailymettle-verify.example`").
3. Repeat for any `dateKey`. The victim's Reviews tab now shows a forged,
   abusive or phishing review history that the victim cannot delete (only the
   reviewer can delete).
4. Use the same primitive to fill the collection for many victims; there is no
   per-user quota.

**Impact**

- Targeted harassment and reputational damage inside the product.
- Phishing surface: an attacker-controlled `reviewerName` and `comment` are
  displayed by a trusted app.
- Corruption of the review history that the product uses to justify streak
  outcomes; any future scoring that consumes `partner_reviews` inherits the
  tampering.
- Storage and cost abuse (unbounded writes, arbitrary string sizes).
- The `read` rule lets the subject read every forged review, so the attack is
  guaranteed to be seen.

**Remediation**

1. Require an existing accepted partnership between reviewer and subject:

   ```
   function isAcceptedPartnerOf(otherUid) {
     return exists(/databases/$(database)/documents/partnerships/$(pairId))
       && get(...).data.status == 'accepted'
       && ((get(...).data.ownerUid == request.auth.uid
            && get(...).data.partnerUid == otherUid)
        || (get(...).data.ownerUid == otherUid
            && get(...).data.partnerUid == request.auth.uid));
   }
   ```

   Because partnership IDs are random, add a deterministic
   `partnership_members/{uid_pair}` index or denormalise the accepted pair into
   both users' documents so the rule can be a single `get()`.
2. Enforce `subjectUid != reviewerUid`, `decision in ['approved','rejected']`,
   `comment.size() <= 1000`, and a whitelist of
   `['subjectUid','reviewerUid','reviewerName','dateKey','decision','comment','createdAt']`.
3. Use a deterministic document ID (`{reviewerUid}_{subjectUid}_{dateKey}`) so a
   reviewer can only create one review per subject per day.
4. Stamp `createdAt` with `request.time` and reject client timestamps.
5. Add an emulator test: a stranger's create is denied; a partner's create is
   allowed; a duplicate create is denied.

**Verification**

- Stranger create → `403`.
- Partner create → `200`; duplicate → `403`.
- `subjectUid == reviewerUid` → `403`.
- A 10 KB comment → `403`.

---

#### AUTH-05 · The `users` collection exposes the entire user directory

**Severity:** High · **Confidence:** High · **Effort:** 2–3 days (data-model split)

**Evidence**

- `firestore.rules:303-311`:

  ```
  // Any signed-in user can read the users collection — needed for the
  // email-based partner lookup (findUserByEmail queries by email field).
  match /users/{uid} {
    allow read: if request.auth != null;
    allow create, update: if request.auth != null
                           && request.auth.uid == uid;
  }
  ```

  A collection-level `allow read` also authorises **`list`**, not just `get`.
- The documents contain more than a display name. `CloudSyncService._upsertUserProfile`
  writes `uid`, `id`, `name`, `displayName`, `email`, `photoUrl`,
  `lastLoginAt` (`lib/core/services/cloud_sync_service.dart:345-366`), and
  `FcmService._persistToken` adds `fcmTokens` and `fcmTokenUpdatedAt`
  (`lib/core/services/fcm_service.dart:183-186`).
- `AccountabilityService.findUserByEmail` performs a single-field equality query
  on `email` (`lib/features/human_accountability/data/datasource/accountability_service.dart:1887-1924`),
  and the UI exposes an email lookup as a normal feature.
- The `email` field is **client-writable**. The rule has no field whitelist and
  never checks `request.auth.token.email_verified`.

**Exploit path**

1. Sign in. Call
   `firestore.collection('users').limit(1000).get()` repeatedly with
   `startAfterDocument` to page through the directory.
2. Harvest `email`, `displayName`, `photoUrl`, `lastLoginAt` and `fcmTokens`.
3. Use the email list for credential stuffing, phishing, or to identify
   high-value users (recent `lastLoginAt` = active).
4. Set your own `users/{uid}.email` to a victim's address. Because
   `findUserByEmail` returns the first matching document, an invitation
   addressed to the victim's email can resolve to the attacker's UID in the
   sender's UI. The attacker then receives the partnership request and the
   victim's shared progress.
5. Optionally set `isPremium`, `role` or similar fields on your own document.
   Nothing reads them today, but the rule permits it and future code will.

**Impact**

- **Privacy:** a complete, enumerable directory of names, email addresses,
  profile photos and activity timestamps. This is a serious GDPR/CCPA
  personal-data exposure and a direct contradiction of the in-app claim that
  the app does not collect more than necessary.
- **Phishing:** verified-looking emails addressed by name, from a product the
  user actually uses.
- **Identity spoofing:** client-writable `email` + email-based partner lookup.
- **Push-token exposure:** FCM registration tokens should never be readable by
  other clients; combined with any future server-key leak they enable targeted
  push.
- **Enumeration of UIDs**, which is the missing ingredient for PRIV-02 (legacy
  backup key derivation).

**Remediation**

1. Split the model:
   - `users/{uid}` — owner-only read/write; contains email, FCM tokens,
     entitlement hints, preferences.
   - `public_profiles/{uid}` — `displayName`, `photoUrl`, `uid` only; readable
     by signed-in users.
2. Remove email lookup from the client. Replace it with a Cloud Function
   `lookupPartner(email)` that requires authentication and App Check, returns
   only `{uid, displayName, photoUrl}` for an exact match, rate-limits per
   caller (for example 10/hour), and never confirms whether an email is
   registered to unauthenticated callers.
3. Move `fcmTokens` to `users/{uid}/devices/{deviceId}` with owner-write and
   server-only read.
4. Add a field whitelist to the `users` update rule and reject `email` changes
   unless `request.auth.token.email == request.resource.data.email` and
   `email_verified == true`.
5. Deploy the new rules, then delete the legacy fields from existing documents
   with a one-off admin script.
6. Add emulator tests for `list` denial, cross-user `get` denial, and email
   tampering denial.

**Verification**

- `users` list as a normal user → `403`.
- `public_profiles` get by UID → `200`, with no email or token fields.
- Set `email` to another address → `403`.
- Function returns `404`-equivalent for unknown emails, with no timing
  difference that distinguishes "not registered" from "rate-limited".

---

#### AUTH-06 · Task creation has no schema or field whitelist

**Severity:** High · **Confidence:** High · **Effort:** 2 days

**Evidence**

- `firestore.rules:397-412`:

  ```
  allow create: if request.auth != null
                && request.resource.data.assignedByUid == request.auth.uid
                && request.resource.data.get('approvals', []) == []
                && request.resource.data.get('rejections', []) == []
                && request.resource.data.get('approvalUids', []) == []
                && request.resource.data.get('rejectionUids', []) == [];
  ```

  Only four vote arrays are constrained. Every other field is attacker-chosen:
  `title`, `notes`, `status`, `proofStatus`, `proofUrl`, `accountableUid`,
  `accountableEmail`, `accountableUserIds`, `partnerUid`, `challengeId`,
  `expiresAt`, `requiredApprovals`, `points`, `createdAt`, and any extra keys.
- Update rules are strict, but they operate on whatever the create allowed. A
  forged initial state never needs an update.
- Read access is granted to `accountableUid`, `partnerUid`,
  `accountableUserIds` and `accountableEmail`
  (`firestore.rules:398-406`), so a forged task is delivered straight into the
  victim's task list.
- The client renders task titles, notes and proof images without a trust
  boundary (`accountability_screen.dart`, `daily_task_card.dart`).

**Exploit path**

1. Sign in as attacker A.
2. Create a task with:
   - `assignedByUid`: A (satisfies the rule)
   - `accountableUid`: victim V
   - `partnerUid`: victim V (or a third party)
   - `status`: `"approved"`, `proofStatus`: `"approved"`
   - `title`: `"ACTION REQUIRED: re-verify your DailyMettle account"`
   - `notes`: a phishing URL
   - `proofUrl`: an attacker-hosted image
   - `challengeId`: any value, including another user's challenge ID
   - `expiresAt`: any timestamp
   - `requiredApprovals`: `99`
3. V's client reads the task because `accountableUid == V`, and shows it as an
   approved task with attacker content.
4. Variants:
   - `status: "pendingReview"` with a past `expiresAt` to drive V's expiry
     service and generate state transitions.
   - `partnerUid: V` on thousands of tasks to flood V's review queue.
   - `requiredApprovals: 99` to create an un-completable task that blocks V's
     streak.
   - Extremely long strings to hit the 1 MiB document limit and degrade the UI.
5. No rate limit exists, so the attacker can repeat at Firestore write cost.

**Impact**

- Cross-tenant content injection into another user's private task list.
- UI spoofing/phishing inside a trusted surface.
- Integrity of completion, streak and discipline-score calculations if the
  client trusts forged `status`, `points` or `completedAt`.
- Review-queue denial of service and support burden.
- Unbounded write cost.

**Remediation**

1. Replace the create rule with a strict whitelist and forced initial state:

   ```
   allow create: if request.auth != null
     && request.resource.data.keys().hasOnly([...])
     && request.resource.data.assignedByUid == request.auth.uid
     && request.resource.data.status == 'pending'
     && request.resource.data.proofStatus == 'not_required'
     && request.resource.data.proofUrl == null
     && request.resource.data.title is string
     && request.resource.data.title.size() > 0
     && request.resource.data.title.size() <= 120
     && request.resource.data.notes.size() <= 2000
     && request.resource.data.requiredApprovals is int
     && request.resource.data.requiredApprovals >= 1
     && request.resource.data.requiredApprovals <= 5
     && (request.resource.data.accountableUid == request.auth.uid
         || isAcceptedPartnerOf(request.resource.data.accountableUid))
     && (request.resource.data.partnerUid == null
         || isAcceptedPartnerOf(request.resource.data.partnerUid))
     && request.resource.data.createdAt == request.time;
   ```

2. Never accept `completedAt`, `reviewedAt`, `approvalUids` or `proofUrl` at
   create time.
3. Validate `challengeId` belongs to the caller (or is null).
4. Add a per-user create rate limit (Cloud Function counter or App Check
   quota).
5. Add emulator tests for each forged-field case.

**Verification**

- Create with `status: "approved"` → `403`.
- Create with a non-partner `accountableUid` → `403`.
- Create with `requiredApprovals: 0` or `99` → `403`.
- Create with an extra field → `403`.
- Bulk create beyond the limit → `429`/`403`.

---

#### AUTH-07 · Invitation and partnership updates have no field whitelist

**Severity:** High · **Confidence:** High · **Effort:** 2 days

**Evidence**

- `firestore.rules:352-360` allows the recipient to update an invitation with
  **any** field:

  ```
  allow update: if request.auth != null
                && (resource.data.toUid == request.auth.uid
                    || resource.data.toEmail == request.auth.token.email);
  ```

- `firestore.rules:220-242` allows a partnership member, a claimant, or the
  invited email holder to update with **any** fields. The claim branches only
  constrain `partnerUid` and `status`; they do not use
  `diff().affectedKeys().hasOnly([...])`.
- `firestore.rules:208-209` allows creation with `ownerUid == self`, but does
  not constrain `partnerUid`, `status`, `partnerEmail` or `role`. Combined with
  `ensurePartnership` (which writes `status: 'accepted'` directly, see AUTH-01),
  the initial state of a partnership is entirely client-controlled.
- `isPartnershipMember()` (`firestore.rules:22-27`) authorises chat reads and
  writes from `ownerUid`/`partnerUid`, so rewriting either field silently
  changes who can read the conversation.

**Exploit path**

1. **Invitation tampering.** As the recipient of any invitation, update it to
   change `fromUid`, `fromName`, `fromEmail`, `partnershipId`, `role`, `message`
   or `status`. The sender's UI and any downstream notification now show
   attacker-controlled identity text, and `partnershipId` can be pointed at a
   partnership the attacker owns.
2. **Partnership identity rewrite.** As a member of a partnership, update
   `ownerUid` to a victim's UID while keeping `partnerUid` as yourself. The
   document now claims the victim is the owner; `isPartnershipMember` still
   returns true for the attacker, and the victim's client may accept the
   document as a real partnership.
3. **Status manipulation.** Set `status` back to `pending` or `declined` to
   re-trigger invites/notifications, or rewrite `acceptedAt` to backdate the
   relationship.
4. **Claim-time injection.** Claim an unclaimed partnership (AUTH-02) and, in
   the same update, set `partnerName`, `ownerName`, `ownerEmail`, `role` and
   `inviteCode` to arbitrary values. The claim rule only checks `partnerUid`
   and `status`.
5. **Partnership transfer.** Change `partnerUid` to a third account, moving
   access to the chat and shared progress to that account.

**Impact**

- Identity spoofing in invitations and chat.
- Authorization-state manipulation: who is a partner, who can read the chat,
  and whether a partnership is active.
- Audit-trail corruption (`acceptedAt`, `status`, names).
- Combined with AUTH-01/02, an attacker can make a forged partnership look
  legitimate to the victim's UI.

**Remediation**

1. Add `diff().affectedKeys().hasOnly([...])` to every update branch:
   - claim: `['partnerUid','status','acceptedAt','partnerName']` (and only
     allow `partnerName` when it is currently empty, as the self-heal case);
   - email-holder accept/decline: `['status','acceptedAt','respondedAt']`;
   - member metadata update: `['partnerName','role']` only, with enum
     validation for `role`.
2. Make `ownerUid`, `partnerUid`, `ownerEmail`, `fromUid`, `fromEmail`,
   `fromName`, `partnershipId` and `createdAt` immutable after create.
3. Validate `status in ['pending','accepted','declined']` and require
   `acceptedAt == request.time` when transitioning to `accepted`.
4. Reject `partnerEmail` changes after create, or require the new email to be
   verified by the new holder.
5. Add emulator tests that attempt each forbidden field rewrite.

**Verification**

- Recipient rewrites `fromUid` → `403`.
- Member rewrites `ownerUid` → `403`.
- Claim sets `partnerName` on a non-empty name → `403`.
- Claim sets `status: 'pending'` → `403`.
- Legitimate accept/decline still succeeds.

---

#### AUTH-08 · A doer can reset a proof round and erase rejection history

**Severity:** High · **Confidence:** High · **Effort:** 1–2 days

**Evidence**

- `firestore.rules:120-135` (the "new proof round" branch of
  `canUpdateProof`):

  ```
  ((resource.data.assignedByUid == request.auth.uid
    || resource.data.accountableUid == request.auth.uid)
    && resource.data.get('proofStatus', 'not_required') != 'submitted'
    && resource.data.status in ['pending', 'rejected', 'completed', 'approved']
    && changes.hasOnly(['proofStatus','proofUrl','proofSubmittedAt','status',
                        'submittedAt','expiresAt','approvals','rejections',
                        'approvalUids','rejectionUids'])
    && proofStatus == 'submitted'
    && request.resource.data.approvals == []
    && request.resource.data.rejections == []
    && request.resource.data.approvalUids == []
    && request.resource.data.rejectionUids == []
    && (!changes.hasAny(['status'])
        || (status == 'pendingReview' && hasValidReviewWindow())))
  ```

- The branch explicitly includes `accountableUid` (the doer) and explicitly
  clears `approvals`, `rejections`, `approvalUids` and `rejectionUids`.
- It is reachable whenever `proofStatus != 'submitted'`, which includes
  `rejected` **and** `approved`.
- `completedAt` is not in the whitelist, so it is not cleared. A task can be
  moved from `approved` back to `pendingReview` while retaining
  `completedAt`, producing an inconsistent record.
- The comment at `firestore.rules:161-162` states that rejection is
  "immediate and terminal". The reset branch makes it neither.

**Exploit path**

1. Submit a proof that is rejected. `proofStatus == 'rejected'`,
   `status == 'rejected'`, and `rejectionUids` contains the reviewer.
2. Call the same "submit proof" path again with an empty vote history and
   `status: 'pendingReview'`.
3. The rejection arrays are wiped; the task looks like a first submission.
   The reviewer's history no longer records the rejection, and the partner sees
   a clean review queue.
4. Repeat until a reviewer approves out of fatigue. The doer never accumulates
   a rejection.
5. On an approved task, use the same branch to move it back to
   `pendingReview` and re-complete it, inflating completion counts while
   `completedAt` remains set.
6. Because the votes are erased, the "one vote per reviewer" and quorum logic
   can be replayed; combined with AUTH-03 the doer can self-approve each round.

**Impact**

- The core accountability guarantee — that a rejected proof is recorded — is
  bypassable by the person being reviewed.
- Audit trail destruction: the partner cannot prove what happened.
- Streak/completion manipulation and inconsistent task state.
- Partner trust erosion; a reviewer who rejects repeatedly sees the rejection
  disappear.

**Remediation**

1. Add an append-only `reviewHistory` array (or a
   `accountability_tasks/{taskId}/reviews/{round}` subcollection) that records
   every submission, decision, reviewer UID and timestamp. Never allow it to be
   cleared by the client.
2. Split the transitions:
   - `resubmitAfterRejection`: allowed only when `resource.data.status == 'rejected'`,
     increments `reviewRound`, and does not touch prior vote arrays;
   - first submission: allowed only when `resource.data.proofStatus in
     ['not_required', null]` and no votes exist.
3. Forbid the reset branch when `resource.data.status in ['approved','completed']`.
4. Make `completedAt`, `reviewedAt` and `proofReviewedAt` immutable once set.
5. Require a reviewer notification on resubmission and record it in analytics.
6. Add emulator tests: rejected → resubmit preserves history; approved →
   reset denied; doer cannot clear votes.

**Verification**

- Rejected task resubmission retains the prior rejection in `reviewHistory`.
- Approved task reset → `403`.
- Doer attempts to clear `rejectionUids` → `403`.
- Reviewer UI shows every round.

---

### 5.3 Privacy and data protection

The privacy story in the product is better than average on paper — backups are
authenticated-encrypted, analytics excludes content, and photos are described
honestly. The failures are in the gap between the story and the code, and in
the places where convenience silently overrode consent.

#### DATA-01 · The backup key cannot be recovered, and a later sync overwrites the only copy

**Severity:** Critical · **Confidence:** High · **Effort:** 3–5 days
**Indicative impact:** certain, unrecoverable loss of the user's entire history

**Evidence**

- `lib/core/services/cloud_backup_key_store.dart:44-112` — one random 256-bit
  key per account, stored only in platform secure storage. There is **no
  export, no print, no passphrase, no escrow and no recovery code**.
- `lib/core/services/cloud_backup_key_store.dart:114-116` claims:

  > "Sign-out does not call this; retaining the key allows that same account to
  > restore its backups after a later sign-in while still isolating it from
  > other accounts."

  That is true only while the app's data survives. On Android, uninstalling the
  app or clearing app data removes the Keystore-backed value; on iOS, Keychain
  items may survive a reinstall but are not guaranteed across device migration.
- `CloudSyncService._readUserHeldKey` calls `_keyStore.getOrCreateKey(uid)`
  (`cloud_sync_service.dart:147-155`). If the old key is gone, a **new random
  key is silently created**.
- `_syncToCloud` (`cloud_sync_service.dart:470-537`) reads the existing
  document, preserves only a *legacy UID-derived* envelope
  (`if (_isLegacyBackup(oldData))`), then overwrites `enc` and `nonce` with
  ciphertext under the new key. There is no `keyId` comparison and no
  "can the new key decrypt the old ciphertext?" check.
- `_runAutoSync` (`cloud_sync_service.dart:427-435`) runs on every resume and
  reconnect for a signed-in, consented user. It does not skip an empty local
  dataset.
- Startup restore (`main.dart:555-625`) only attempts a restore when
  `hasLocalData == false`. If the user has already created a new challenge or a
  task, the restore is skipped and the next auto-sync overwrites the cloud
  backup.
- The privacy policy admits the gap: "If you uninstall the app, secure-storage
  keys may be removed; export a recovery key when that feature is available
  before relying on restore after reinstall"
  (`lib/screens/privacy_policy_screen.dart:51`). The feature is **not
  available**.

**Realistic user path (no attacker required)**

1. User completes 60 days of a 75-day challenge with daily journal entries.
2. They replace their phone, or uninstall/reinstall to free space, or clear app
   data to troubleshoot a bug.
3. They sign in with the same Google account. Firebase Auth is restored, but the
   random backup key is gone; `getOrCreateKey` creates a new one.
4. The app fails to decrypt the old backup (correctly — it does not have the
   key), and because the user now has some local data, the restore path is
   skipped.
5. On the next resume/reconnect, auto-sync uploads the new local data encrypted
   with the new key, replacing `enc`/`nonce`. The old ciphertext is gone.
6. The 60 days of history, journal and completion records are permanently
   unrecoverable. Support cannot help; the key never left the device.

**Impact**

- **Certain data loss** for any user who reinstalls, changes device, clears app
  data, or has secure storage reset (Android backup/restore, OEM cleaner,
  biometric/Keystore reset).
- Loss of the product's core asset: a 75-day streak and its journal. This is
  the most churn-inducing failure a habit app can have.
- Refund requests, 1-star reviews, and a plausible "data loss" regulatory
  complaint (GDPR Art. 5(1)(f) integrity/availability, Art. 32).
- The encrypted-backup feature creates a false expectation of durability; a
  user who never enabled backup might have been safer with local export.

**Remediation**

1. **Add a recovery key.** On first backup, generate a human-transcribable
   recovery code (for example 24 words or a Base32 string with a checksum) that
   wraps the random data key. Show it once, require the user to confirm it, and
   store only the wrapped key.
2. **Add passphrase-based wrapping.** Derive a wrapping key with Argon2id
   (memory-hard) from a user passphrase and store
   `wrappedKey = AEAD(dataKey, wrappingKey)` in `user_data/{uid}` alongside the
   ciphertext. The server never sees the passphrase or the data key.
3. **Version the envelope.** Add `keyId` (a random UUID or fingerprint) and
   `wrappedKeys: {keyId: ...}`. On sync, if the remote `keyId` is unknown and
   the remote ciphertext is non-empty, **refuse to overwrite** and prompt for
   recovery instead.
4. **Never auto-sync an empty or new-key dataset over a non-empty remote.**
   Require an explicit "replace cloud backup" confirmation with a diff summary
   (dates, sessions, entries).
5. **Restore-first on sign-in.** If the remote has data and the local key cannot
   decrypt it, block the sync and show a recovery screen before any write.
6. **Export/import.** Add "Export encrypted backup" and "Restore from file" so a
   user can move devices without the cloud.
7. **Test the matrix:** Android uninstall/reinstall, Android clear-data, iOS
   reinstall, iOS device-to-device migration, secure-storage reset, wrong
   recovery code, corrupted ciphertext, concurrent sync. Automate at least the
   key-lifecycle cases.
8. **Instrument** `backup_restore_failed` with a reason code (no key, wrong key,
   tampered, missing remote) and alert on spikes.
9. Correct the policy to state the recovery options that actually exist, and
   warn before sign-out if no recovery key has been exported.

**Verification**

- Reinstall on Android, sign in, enter the recovery code → full history restored.
- Reinstall without the recovery code → sync is blocked with a clear message;
  the remote ciphertext is unchanged.
- A new key cannot overwrite an existing backup until the user confirms.
- `user_data` contains `keyId` and a wrapped key, but no plaintext key material.
- The privacy policy matches the implemented flow.

---

#### PRIV-01 · Journal text reaches NVIDIA, and font requests reach Google, without disclosure or consent

**Severity:** High · **Confidence:** High · **Effort:** 2–4 days

**Evidence**

- `lib/widgets/voice_input.dart:236-262` — the "Tron AI" button sends the
  current journal text to `TronAiService().polishDictation(text)`.
- `lib/features/ai_accountability/data/services/tron_ai_service.dart:11-18, 40-95`
  — posts that text to `https://integrate.api.nvidia.com/v1/chat/completions`
  with `Authorization: Bearer ${ApiConstants.tronApiKey}` and the system prompt
  "You clean up dictated journal entries…". The model is
  `meta/llama-3.1-8b-instruct`.
- `lib/core/constants/api_constants.dart:44-53` — the key is a build-time
  `--dart-define` and the base URL is NVIDIA's hosted API.
- `lib/features/ai_accountability/data/services/gemini_service.dart` — the
  Gemini key is placed in the request **URL query string**, and the (currently
  unreachable) `AiCompanionScreen` sends the current challenge day, streak, task
  name and the user's chat message.
- Voice input uses the OS speech recognizer (`speech_to_text`), which on many
  Android and iOS configurations streams audio to Google or Apple for
  transcription. The app declares `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` but does not explain the transfer.
- `lib/screens/privacy_policy_screen.dart:81` lists the processors:

  > "Firebase Authentication, Firestore, Analytics, Crashlytics, and Cloud
  > Messaging (Google); Cloudinary for hosting photos; a public quotes API"

  **NVIDIA is not listed. Gemini is not listed. Google Fonts is not listed.**
- `google_fonts` is used at 147 call sites; by default it fetches font files
  from `fonts.gstatic.com` at runtime, disclosing the device IP and app usage to
  Google even when the user never signs in.
- In-app claims contradict the data flows:
  - `lib/screens/onboarding_screen.dart:505-517` states that the encryption key
    is derived from the account ID and that the provider cannot read content.
  - `lib/screens/profile_screen.dart:914-916` says "Only you can decrypt" and
    "We cannot read your content."
  - Both are false for AI-processed journal text, partner-visible progress,
    analytics, and any server-side operator with Firestore access.

**Exploit / misuse path**

This is primarily a compliance and trust failure, not an attacker primitive.
The realistic paths are:

1. A user dictates a journal entry containing health, relationship or
   financial information, then taps "✨ Tron AI" to clean it up. The full text
   leaves the device to NVIDIA with no notice.
2. A user in the EU/UK/India exercises a subject-access request. The company
   cannot accurately answer "where did my journal text go?" because the policy
   omits NVIDIA and the OS speech provider.
3. A regulator or store reviewer compares the policy to the network traffic and
   finds undisclosed processors and an undisclosed international transfer.
4. The Gemini key in a URL is captured by a proxy, a crash report or a log
   aggregator, exposing the key and the prompt.

**Impact**

- GDPR Art. 13/14 (transparency), Art. 6 (lawful basis), Art. 44 (international
  transfer), CCPA "notice at collection", India DPDP §5 notice.
- Play Data Safety and App Store privacy labels are inaccurate.
- The marketing claim of private, encrypted journaling is misleading — a
  consumer-protection and potentially FTC §5 issue.
- Reputational damage if a user discovers their journal was sent to a
  third-party model provider.

**Remediation**

1. **Disclose** every processor in the privacy policy and in a short in-context
   notice the first time the user taps Tron AI: what is sent, to whom, why,
   retention, and how to opt out.
2. **Consent** before the first AI call. Store the consent decision with a
   timestamp and policy version; make withdrawal as easy as granting.
3. Move AI calls behind a backend proxy so the provider key is not in the app
   (see SEC-03), and so prompts can be logged/redacted under a retention policy.
4. Add a "Journal AI" toggle in Settings (default **off**) and a per-entry
   "don't send" option.
5. Replace runtime `google_fonts` fetching with bundled fonts, or disclose the
   transfer and make it opt-in.
6. Disclose the OS speech recognizer and offer on-device-only transcription
   where the platform supports it.
7. Correct every "we cannot read your content" claim to match the actual
   architecture: encrypted at rest for backups, but partner-shared and
   AI-processed content is readable by design.
8. Update the Play Data Safety form and `PrivacyInfo.xcprivacy` to include
   "User Content" and "Audio Data" where applicable (see M6 and M13).

**Verification**

- A network capture of a fresh install shows no requests to `nvidia.com`,
  `googleapis.com` font endpoints or Gemini unless the user has consented.
- The policy names every endpoint in the capture.
- Consent records exist and are queryable per user.
- A subject-access request can enumerate every processor and retention period.

---

#### PRIV-02 · Legacy backups are encrypted with a key anyone can derive from a public UID

**Severity:** High · **Confidence:** High · **Effort:** 3–5 days (migration + deadline)

**Evidence**

- `lib/core/services/cloud_sync_service.dart:76-77`:

  ```
  static const String _legacyUidKeySource = 'uid-derived-v3';
  static const String _legacyBackupField = 'legacyBackup';
  ```

- `lib/core/services/cloud_sync_service.dart:105-122` derives the legacy key
  with HKDF-SHA256 over the UID and a **hard-coded public salt**:

  ```
  final salt = utf8.encode('dailymettle-v3-stable-key');
  final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest());
  hkdf.init(pc.HkdfParameters(..., Uint8List.fromList(salt)));
  hkdf.deriveKey(null, 0, keyBytes, 0);
  ```

  There is no secret input. The key is a deterministic function of the UID.
- `syncFromCloud` still attempts the legacy key as a fallback and records
  `_lastRestoreUsedLegacyKey` (`cloud_sync_service.dart:550-640`).
- UIDs are enumerable through the `users` collection (AUTH-05), and the same
  UIDs appear in `partnerships`, `partner_reviews` and `public_progress`.
- The encrypted blob lives in `user_data/{uid}`. The rules restrict reads to the
  owner, but the leaked GCP service account (SEC-01) bypasses rules entirely,
  and any Firestore export, support tool or backup contains the ciphertext.

**Exploit path**

1. Obtain the target's UID (trivial via AUTH-05) and their `user_data/{uid}`
   document (via the leaked service account, a misconfigured export, a support
   console, or physical/backup extraction).
2. Derive the key: `HKDF-SHA256(uid, salt="dailymettle-v3-stable-key")`.
3. Decrypt the AES-256-GCM envelope. The tag verifies because the key is
   correct; there is no attacker-visible failure.
4. Read challenge history, journal notes, task names and completion records.

Even without the service account, the design means the encryption-at-rest
control is **not** a confidentiality control against the provider or any party
that can read Firestore. It only protects against a network eavesdropper, which
TLS already does.

**Impact**

- False sense of security: "AES-256 encrypted" is technically true but
  cryptographically meaningless without a secret.
- Any historical backup produced before the secure-key migration is readable by
  anyone with the ciphertext and the UID.
- The in-app policy says "older backups may use the legacy account-derived
  migration format" — users are not told that this format is not confidential.
- Regulatory exposure: the backup contains journal content and health-adjacent
  habit data.

**Remediation**

1. Set a hard migration deadline (for example 90 days). On every successful
   sign-in, if the backup is legacy, decrypt it locally with the legacy key,
   re-encrypt it with the random secure-storage key, write it, and mark the
   document `schemaVersion: 4`.
2. After the deadline, remove the legacy decryption path from the client and
   delete `legacyBackup` fields server-side.
3. Refuse to create new legacy backups (already true) and add a telemetry event
   for "legacy restore used" so the migration can be tracked.
4. Add a user-facing recovery/export flow for the new key (see DATA-01). Without
   it, removing the legacy path makes reinstall data loss permanent.
5. Document in the policy that legacy backups are less protected and will be
   migrated or deleted.
6. Consider per-user KMS envelope encryption with the data key wrapped by a
   Cloud KMS key, so a Firestore-only compromise does not expose plaintext.

**Verification**

- A fresh backup has `schemaVersion: 4` and no `legacyBackup` field.
- The legacy code path is unreachable after the deadline (unit test asserts
  `_legacyBackupField` is not read when the schema is current).
- A support export of `user_data` contains no decryptable legacy content.

---

#### PRIV-03 · Proof photos retain GPS EXIF and use predictable object names

**Severity:** High · **Confidence:** High · **Effort:** 2–3 days

**Evidence**

- `lib/core/services/photo_sync_service.dart:155-175` compresses with
  `keepExif: true`:

  ```
  final compressedXFile = await FlutterImageCompress.compressAndGetFile(
    imageFile.path,
    ...,
    quality: 92,
    keepExif: true,
  );
  ```

  The compressed file is what gets uploaded, so camera GPS, timestamp, device
  make/model and orientation survive.
- Cloudinary path: `lib/core/services/photo_sync_service.dart:210-240` builds a
  `public_id` from `${challengeId}_$proofDate`. `challengeId` is a
  `millisecondsSinceEpoch` string in several creation paths
  (`lib/widgets/create_task_sheet.dart:279, 315`), which is guessable.
- Firebase Storage fallback: `lib/core/services/photo_sync_service.dart:345-365`
  uploads to `task_proofs/${challengeId}_$proofDate.jpg` — a **global**
  namespace with no UID or task ID.
- The resulting URL is written to `accountability_tasks.proofUrl`, which is
  readable by the partner, the accountable user and reviewers
  (`firestore.rules:398-406`).
- `getDownloadURL()` tokens are bearer credentials with no expiry.
- No image sanitisation, content-type validation or size limit exists beyond
  client-side compression.

**Exploit / misuse path**

1. **Location disclosure.** A user photographs a workout at home. The GPS
   coordinates are uploaded to Cloudinary/Firebase and shared with the partner
   and any reviewer. A partner (or a compromised partner account) can extract
   the coordinates from the downloaded image.
2. **Object-name collision / overwrite.** Because the name is
   `{challengeId}_{date}` with no user or task component, two users who create
   challenges in the same millisecond (or an attacker who guesses a challenge
   ID) can collide. If the storage rules or Cloudinary signer allow writes to
   that name, one user's proof replaces another's; the approved image is not
   the image displayed later.
3. **Enumeration.** Sequential `challengeId` values plus a fixed date format
   make object names predictable, and `getDownloadURL()` links are stable.
4. **Orphaned retention.** Deleting a task or challenge does not delete the
   object; there is no lifecycle rule and no account-deletion path (COMP-01).

**Impact**

- Home, workplace and routine location disclosure to another user and to two
  processors.
- Integrity failure if proofs can be overwritten.
- Unbounded retention of face/location images.
- GDPR special-category inference risk (health, religion, sexual orientation
  can be inferred from images and locations).

**Remediation**

1. Set `keepExif: false`, or strip GPS explicitly while preserving orientation.
   Verify with `exiftool` in CI on a fixture image.
2. Use a random UUID for `public_id` and the Storage object name:
   `task_proofs/{uid}/{taskId}/{uuid}.jpg`. Never use timestamps as identifiers.
3. Make objects private; deliver through short-lived signed URLs or a
   Cloud Function that checks partnership membership at request time.
4. Enforce `contentType` matches `image/(jpeg|png|heic)`, a maximum size
   (for example 10 MB) and a maximum dimension in `storage.rules`.
5. Delete objects when the task, challenge or account is deleted; add a
   lifecycle rule for orphans.
6. Warn users before upload if the image contains location metadata, and offer
   "remove location" as the default.
7. Do not log full URLs; log object IDs.

**Verification**

- `exiftool` on an uploaded fixture shows no GPS tags.
- Two uploads for the same challenge/date produce different object names.
- An unauthenticated GET of an object URL fails; a signed URL expires.
- Deleting the task removes the object within the lifecycle window.

---

#### PRIV-04 · Analytics and Crashlytics run before consent and are not gated

**Severity:** High · **Confidence:** High · **Effort:** 2 days

**Evidence**

- `lib/main.dart:529` calls `_recordAppOpen()` during startup, before any
  consent screen and regardless of user choice.
- `lib/core/services/analytics_service.dart:149-180` logs events with no consent
  check. There is no `consent`, `optedOut` or `setAnalyticsCollectionEnabled`
  reference in the file.
- Firebase Analytics and Crashlytics are initialised from
  `Firebase.initializeApp`; collection is enabled by default on Android and
  iOS. `FirebaseCrashlytics.instance.recordError` is called at
  `analytics_service.dart:507`.
- Consent exists only for cloud sync: `CloudSyncService.hasConsentBeenGiven` /
  `recordConsent` (`cloud_sync_service.dart:383-393`), triggered from the
  onboarding/profile sign-in flow. It is not connected to analytics.
- The privacy policy (`privacy_policy_screen.dart:66`) describes analytics as
  "associated with your app installation" but does not state that it starts
  before consent or how to opt out.
- No ATT prompt exists on iOS (`NSUserTrackingUsageDescription` absent), which
  is correct only if there is no tracking; the analytics SDK still collects
  device and usage data.

**Impact**

- EEA/UK: analytics identifiers and usage events before consent are a likely
  ePrivacy/GDPR violation.
- India DPDP: notice and consent before processing.
- Play Data Safety and App Store privacy labels must declare analytics and
  crash data; the current labels (see `PrivacyInfo.xcprivacy`) omit several
  categories.
- A regulator complaint or store rejection is plausible; remediation after the
  fact is harder than a consent gate now.

**Remediation**

1. On first launch, call
   `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false)` and
   `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false)`
   **before** `runApp`.
2. Show a consent screen (analytics and crash reporting as separate toggles)
   before the first event. Persist the decision with a policy version.
3. Gate `_logEvent` and `recordError` on the stored decision; queue nothing
   while disabled.
4. Provide an opt-out in Settings and apply it immediately.
5. Update the policy and store labels to match; add a "Data we collect" section
   with retention.
6. If the product does not need analytics, remove the SDK — the smallest data
   footprint is the best compliance posture.

**Verification**

- A fresh install with consent denied generates zero Analytics/Crashlytics
  network calls (proxy capture).
- Accepting analytics starts events; revoking stops them.
- Store Data Safety answers match the proxy capture.

---

#### PRIV-05 · Local journal and habit data is unencrypted and included in device backups

**Severity:** High · **Confidence:** High · **Effort:** 3–5 days

**Evidence**

- Hive boxes are opened without an encryption cipher:
  - `lib/repositories/database_repository.dart:23-25` — `challenge_sessions`,
    `daily_progress`, `settings`;
  - `lib/repositories/regular_task_repository.dart:17-19` — regular tasks and
    completions;
  - `lib/services/simple_background_check_service.dart:30-33` reopens the same
    boxes.
- `daily_progress` contains journal entries (`JournalEntry` is serialised into
  `DailyProgress`), task notes and completion maps — the most sensitive content
  in the app.
- `android/app/src/main/AndroidManifest.xml:32-34`:

  ```
  android:allowBackup="true"
  android:requestLegacyExternalStorage="true"
  android:networkSecurityConfig="@xml/network_security_config"
  ```

  There is no `android:fullBackupContent` or `android:dataExtractionRules`
  attribute, so Android Auto Backup uses its defaults and uploads the Hive
  boxes and SharedPreferences to the user's Google Drive. The repository does
  contain `res/xml/backup_rules.xml` and `res/xml/data_extraction_rules.xml`,
  but they are **not referenced** by the manifest — and their content explicitly
  *includes* `domain="file"` and `domain="database"`, so wiring them up without
  changes would not help.
- `lib/screens/profile_screen.dart:82` caches the account email in
  SharedPreferences, which is also backed up.
- On iOS the app container is included in iCloud/iTunes backups by default and
  no file is marked `NSURLIsExcludedFromBackupKey`.
- No `FLAG_SECURE` is set on journal, proof or partner screens, so screenshots
  and the recent-apps thumbnail expose content.

**Exploit / misuse path**

1. **Device backup extraction.** An attacker with the user's Google account
   (or a forensic tool with the backup) restores the app backup and reads the
   Hive files directly. Hive stores values in a documented binary format; no
   key is needed.
2. **Shared/lost device.** A person with brief physical access can copy the app
   container on a rooted/jailbroken device, or read the recent-apps snapshot.
3. **ADB backup** on older Android versions with `allowBackup=true`.
4. **Cloud backup exfiltration.** The backup lands in Google Drive under the
   user's account; a compromised Google account exposes it.

**Impact**

- Journal entries (mental health, relationships, finances), habit failures and
  location-tagged photos are readable at rest.
- The product's privacy claim focuses on cloud encryption while the local copy
  is plaintext — a misleading emphasis.
- GDPR/CCPA/DPDP confidentiality expectations are not met for a lost device.

**Remediation**

1. Encrypt Hive with `HiveAesCipher` using a 256-bit key stored in the platform
   keystore (`flutter_secure_storage`), with a documented rotation and
   migration path. Alternatively move to SQLCipher or Drift with SQLCipher.
2. Set `android:allowBackup="false"` **or** provide
   `android:dataExtractionRules` that exclude the Hive directory,
   SharedPreferences and the secure-storage key. Excluding the key while
   backing up the ciphertext makes restore impossible, so exclude both.
3. On iOS, mark the Hive directory and journal files with
   `NSURLIsExcludedFromBackupKey`.
4. Set `FLAG_SECURE` on journal, proof-capture and partner-chat screens
   (configurable if users need screenshots).
5. Remove `android:requestLegacyExternalStorage` (obsolete at targetSdk 36).
6. Add a "Clear local data" action and secure-deletion semantics on sign-out
   (already partially present via `clearLocalData`).
7. Document local retention and the device-backup choice in the policy.

**Verification**

- A device backup no longer contains `*.hive` files or the cached email.
- Opening a Hive file with a hex viewer shows ciphertext, not JSON.
- `adb shell screencap` on a journal screen is blocked.
- Uninstall/reinstall with backup disabled does not restore stale local data.

---

### 5.4 Backend, monetization and reliability

#### MON-01 · Premium is dead code: no purchase UI, no entitlement writer, no feature gate

**Severity:** Critical (business) · **Confidence:** High · **Effort:** 2–3 weeks

**Evidence**

- `lib/core/services/premium_purchase_service.dart` implements a complete
  `in_app_purchase` flow: `loadProducts` (line 77), `purchase` (line 111), `restore`
  (line 140), `refreshServerEntitlement` (line 159), `completePurchase`
  (line 193), a purchase stream, and analytics events.
- `grep -rn "PremiumPurchaseService" lib --include='*.dart'` returns **only the
  file itself**. The class is never constructed, and no screen references it.
- `PremiumEntitlementService` is referenced only by
  `premium_purchase_service.dart`. `getIsPremium`, `watchIsPremium`,
  `PremiumFeature` and `PremiumFeatureX.isAvailable` have **no call sites in the
  UI**.
- There is no paywall, upgrade, products or restore-purchases screen:
  `find lib -iname '*premium*' -o -iname '*paywall*' -o -iname '*upgrade*'`
  returns only the two service files.
- `firestore.rules:316-319` is correct — `entitlements/{uid}` is read-only to
  the client (`allow write: if false`) — but **nothing writes it**. There is no
  Cloud Function, no Admin SDK script and no console process in the repository.
- The only "premium" UI is `_buildPremiumStatsGrid`
  (`lib/screens/profile_screen.dart:640-700`), which is a statistics grid, not a
  purchase or entitlement surface.
- `ProfileScreen` has no subscription status, manage-subscription link,
  restore-purchase button or upgrade CTA.

**Why this is Critical**

This is not "a missing nice-to-have". The repository contains a complete purchase
integration, a server-authoritative entitlement model, and README documentation
that describes premium as server-controlled — but a user **cannot buy anything**,
and the app would not recognize a purchase if they could. The business
consequence is zero revenue plus a support and review risk if a paid store
listing goes live.

There is also a security trap in the obvious quick fix: if a developer wires
`refreshServerEntitlement` to a client-written field, or trusts
`purchase.pendingCompletePurchase` without server verification, entitlements
become forgeable. The service currently calls `completePurchase` locally
(`premium_purchase_service.dart:193`) without a receipt-verification step — the
in-app-purchase plugin does not verify receipts.

**Impact**

- **Revenue:** no path from install to payment. Every day of launch is lost
  revenue.
- **Trust:** if a paywall is shown but the purchase flow is unreachable, users
  see a broken product.
- **Compliance:** App Store/Play require a working restore-purchases flow and a
  manage-subscription link for auto-renewable subscriptions.
- **Diligence:** an acquirer or investor will treat "monetization is a stub" as
  a material defect.
- **Security debt:** the fastest fix (client-side entitlement flag) creates a
  new Critical vulnerability if not paired with server verification.

**Remediation**

1. **Decide the model:** subscription (monthly/annual) vs one-time unlock vs
   feature packs. The current `PremiumFeature` enum
   (`unlimitedChallenges`, `advancedInsights`, `customThemes`) suggests a
   subscription.
2. **Create the products** in App Store Connect and Play Console with stable
   IDs; add them to a single `PremiumCatalog` in the app.
3. **Build the paywall:** value proposition, feature comparison, price,
   trial terms, restore, terms/privacy links, and a "not now" path. Show it
   from the gated features, not only from Settings.
4. **Verify server-side:** a Cloud Function receives the purchase token/receipt,
   calls the Play Developer API / App Store Server API, validates the product
   and expiry, and writes `entitlements/{uid}` with `status`, `productId`,
   `expiresAt`, `source`, `environment`, `updatedAt` and `lastVerifiedAt`.
5. **Gate features** through one widget/service:
   `PremiumGate(feature: ..., child: ...)` backed by
   `watchIsPremium`; fail closed on error.
6. **Handle lifecycle:** restore purchases, pending purchases, cancellations,
   refunds/chargebacks, grace periods, billing retry, account hold, family
   sharing, and store-server notifications (Play RTDN / App Store Server
   Notifications) to revoke access.
7. **Add analytics** for paywall view, purchase start, success, failure, restore
   and cancellation — without sending receipt data.
8. **Add tests:** entitlement parser for malformed/expired/revoked docs; gate
   shows/hides correctly; restore flow; server verification happy path and
   invalid receipt.
9. **Update the policy and store metadata** to describe the subscription,
   renewal, cancellation and refund terms.

**Verification**

- A sandbox purchase writes an entitlement and unlocks a gated feature within
  5 seconds.
- A canceled/refunded subscription loses access at expiry.
- Restore purchases works on a clean install.
- A forged client-side entitlement write is denied by rules.
- The paywall and restore flow pass App Store/Play review checklists.

---

#### INFRA-01 · Firebase Storage has no rules file and proof objects share a global namespace

**Severity:** High · **Confidence:** Medium-High · **Effort:** 1–2 days

**Evidence**

- `firebase.json` configures Firestore rules and indexes but has **no
  `"storage"` section**; `storage.rules` does not exist in the repository.
- Uploads still happen:
  - `lib/core/services/photo_sync_service.dart:345-365` —
    `FirebaseStorage.instance.ref().child('task_proofs').child('${challengeId}_$proofDate.jpg')`
  - `lib/core/services/photo_sync_service.dart:373-392` —
    `profile_avatars/$uid.jpg`
- `getDownloadURL()` returns a tokenised bearer URL; the token does not expire
  unless it is revoked, and the URL is copied into `proofUrl`, logs and
  partner-visible documents.
- Because there is no rules file in source control, the bucket's authorization
  is whatever was last configured in the console — unknown, unaudited and not
  reproducible. New Firebase Storage buckets historically ship with a
  permissive "authenticated users" default, and there is no evidence it was
  tightened.
- Paths contain no owner UID for proofs. Any write rule that allows
  "authenticated users" therefore allows **any user to overwrite any other
  user's proof** for a known `challengeId` and date.

**Exploit path (conditional on the console rules)**

1. If the bucket allows authenticated reads: enumerate/guess
   `task_proofs/{challengeId}_{date}.jpg`, or use a leaked `getDownloadURL()`
   link, to read other users' proof photos.
2. If the bucket allows authenticated writes: upload a replacement image to a
   victim's object name. The database still points at the same URL, so the
   reviewer sees the new image while the approval record refers to the old one.
3. If the bucket allows authenticated deletes: delete proofs, breaking review
   history and partner trust.
4. If the bucket is public: everything above without authentication.

**Impact**

- Confidentiality of face/location photos (PRIV-03).
- Integrity of the proof-of-work product: a reviewer can be shown a different
  image than the one approved.
- Availability: proof deletion.
- Unknown compliance posture — cannot answer "who can read this bucket?".

**Remediation**

1. Add `storage.rules` and wire it into `firebase.json`:

   ```
   service firebase.storage {
     match /b/{bucket}/o {
       match /task_proofs/{uid}/{taskId}/{fileName} {
         allow read: if request.auth != null
                     && (request.auth.uid == uid
                         || isPartnerOrReviewer(taskId));
         allow write: if request.auth != null
                      && request.auth.uid == uid
                      && request.resource.size < 10 * 1024 * 1024
                      && request.resource.contentType.matches('image/.*');
         allow delete: if request.auth != null && request.auth.uid == uid;
       }
       match /profile_avatars/{uid}/{fileName} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == uid
                      && request.resource.size < 5 * 1024 * 1024
                      && request.resource.contentType.matches('image/.*');
       }
       match /{allPaths=**} { allow read, write: if false; }
     }
   }
   ```

2. Change the upload path to include the owner UID and a random object name;
   migrate existing objects or accept a one-time break.
3. Check the console now: `gsutil iam get gs://dailymettle.firebasestorage.app`
   and the Firebase Storage rules tab. Record the current state before changing
   it.
4. Disable the Firebase Storage fallback in production if Cloudinary is the
   intended provider; two providers doubles the attack surface and retention.
5. Enable App Check for Storage and Firestore.
6. Add object lifecycle rules and delete media on task/account deletion.

**Verification**

- `firebase deploy --only storage` succeeds and the rules are visible in the
  console with a deploy timestamp.
- A non-owner read/write/delete → `403`.
- A 20 MB file or `text/html` upload → `403`.
- A second user cannot overwrite the first user's object name.

---

#### INFRA-02 · There is no backend, so entitlements, push, expiry and abuse controls are all client-side

**Severity:** High · **Confidence:** High · **Effort:** 4–8 weeks (phase 1: 1–2 weeks)

**Evidence**

- A `functions/` directory exists at the repository root but contains only empty
  directories (`functions/node_modules`) — **zero files**, no `index.js`, no
  `package.json`, no deployable code. `firebase.json` has no `"functions"` key,
  so there is no deploy target and no function has ever been deployed from this
  repository.
- `entitlements/{uid}` is `allow write: if false`
  (`firestore.rules:316-319`) and **no code anywhere writes it**. The only
  readers are `PremiumEntitlementService` (`getIsPremium`, `watchIsPremium`),
  which is itself never called by the UI.
- `PremiumPurchaseService` has **zero call sites outside its own file**
  (`grep -rn "PremiumPurchaseService" lib` returns only the class itself).
  There is no paywall, no product list screen, no purchase button and no
  feature gate.
- Partner "push" is a Firestore document write:
  `AccountabilityNotificationService.sendNotification` only calls
  `_db.collection('fcm_notifications').add(...)`
  (`accountability_notification_service.dart:94-129`). Nothing sends an FCM
  message. `FcmService`'s comment says "Functions" but no function exists
  (`fcm_service.dart:26`), and `NotificationDispatchListener` only fires while
  the recipient's app process is alive (`notification_dispatch_listener.dart:40-60`).
- `fcm_notifications` create is participant-checked but the `title` and `body`
  are fully client-controlled (`firestore.rules:603-615`), so a partner can
  send arbitrary text that looks like a system notification.
- Expiry is a client timer (`review_expiry_service.dart`), so it only runs while
  the app is open and can be avoided by not opening the app.
- No rate limiting, no App Check, no server-side validation of purchase
  receipts, no server-side account deletion, no scheduled jobs.

**Impact**

1. **Revenue:** premium cannot be purchased or enforced. If a paywall is added
   without a backend, `refreshServerEntitlement` reads a document nobody writes
   and every user stays non-premium — or, if someone flips the field manually,
   every user can be premium.
2. **Core feature failure:** partner notifications do not arrive when the app is
   closed, which is the main moment an accountability nudge matters. Users will
   conclude the feature is broken.
3. **Integrity:** expiry, streak actions, review reminders and notification
   fan-out are all skippable.
4. **Abuse:** no server-side quota on reviews, tasks, messages or AI calls.
5. **Trust:** client-written notification titles enable in-app phishing between
   partners.
6. **Compliance:** no server-side deletion or export pipeline (COMP-01).

**Remediation (phased)**

**Phase 1 — 1–2 weeks, unblock revenue and notifications**

1. Create a Cloud Functions (2nd gen) codebase with:
   - `onDocumentCreated('fcm_notifications/{id}')` → validate the sender,
     look up `users/{recipient}.fcmTokens`, send a real FCM message, mark
     `delivered: true`, delete the token on `UNREGISTERED`.
   - `onCall('verifyPurchase')` → verify the Play/App Store receipt with the
     store API, write `entitlements/{uid}` with `status`, `productId`,
     `expiresAt`, `source`, `updatedAt` and an audit record.
   - `onCall('deleteAccount')` → delete Firestore documents, Storage objects,
     the Auth user, and write an audit record.
   - `onCall('lookupPartner')` → rate-limited email lookup (AUTH-05).
   - Scheduled `expireReviews` (every 15 minutes) and
     `sendReviewReminders` (hourly).
2. Add App Check enforcement to Firestore, Storage and Functions.
3. Add per-user counters in Firestore or Redis for AI calls, invites and
   reviews.

**Phase 2 — 2–4 weeks, harden and monetize**

4. Build the paywall UI, product catalogue, restore-purchases flow, and gate
   features through one `PremiumGate` widget backed by
   `PremiumEntitlementService`.
5. Add server-side receipt validation, refund/chargeback handling, and
   entitlement revocation.
6. Move AI provider calls behind the same backend (SEC-03/PRIV-01).

**Phase 3 — ongoing**

7. Add alerting on function errors, FCM failures, purchase verification
   failures and entitlement drift.
8. Add a dead-letter queue and idempotency keys for notifications.

**Verification**

- Kill the app, have a partner send a message, receive a push within 10 s.
- Purchase a sandbox product; `entitlements/{uid}` is written by the function
  and the UI unlocks.
- Refund the purchase; entitlement is revoked on the next refresh.
- Delete an account; Firestore, Storage and Auth are empty for that UID.
- App Check blocks a request from a client without attestation.

---

#### FUNC-01 · Streak escalation and in-app notifications fail silently by design

**Severity:** High · **Confidence:** High · **Effort:** 1–2 days (rules) + 3 days (UX)

**Evidence**

- There are **no rules** for `accountability_notifications` or `streak_actions`.
  The rules cover 13 collection paths (11 top-level plus the `messages` and
  `days` subcollections). The client references 15 collection paths
  (`grep -rhoE "collection\('[a-z_]+'\)" lib`); 13 of those are covered, and
  the two uncovered ones are exactly `accountability_notifications` and
  `streak_actions`. Firestore denies unmatched paths by default.
- The code knows this:
  - `accountability_extension_service.dart:95-96` —
    "`accountability_notifications` has no Firestore rules (writes are blocked
    and swallowed)…"
  - `accountability_extension_service.dart:196-208` writes a notification and
    catches the error.
  - `accountability_extension_service.dart:327-338` writes a `streak_actions`
    document in a `try/catch` that returns `null` on failure.
- The UI reports success even when the write fails:
  `streak_escalation_screen.dart:69-115` only shows a snackbar when
  `result != null`; when `result == null` it shows **nothing**. The button
  simply stops spinning.
- `fetchStreakActions` returns `[]` on error
  (`accountability_extension_service.dart`), which the screen renders as
  "no history" — indistinguishable from a genuinely empty history.

**Exploit / user path**

1. A partner taps "Flag streak" and enters a reason.
2. The write is denied. The screen silently returns to idle.
3. The partner assumes the flag was recorded. The subject is never notified.
4. The partner repeats the action, or escalates outside the app.
5. The audit history stays empty, so neither party can tell what happened.

**Impact**

- A headline accountability feature does not work.
- Users lose trust and stop using the partner feature.
- Support burden: "I flagged it and nothing happened."
- Silent failure also hides real outages (quota, rules drift, network).

**Remediation**

1. Add rules for both collections (see the appendix for a starting point):
   - `streak_actions`: create only by an accepted partner of `subjectUid`;
     read by subject and initiator; no update/delete.
   - `accountability_notifications`: create only by a participant of the
     referenced task/partnership; read/update/delete only by `recipientUid`.
2. Stop swallowing errors. Return a typed result
   (`Success | Denied | NetworkError`) and show a specific message.
3. Add an optimistic UI state that reverts on failure, with a retry action.
4. Add an offline outbox for these writes, reusing `OfflineTaskOutbox`.
5. Add a Firestore rules test for both collections.
6. Add a dashboard metric for denied writes (log to Crashlytics non-fatally).

**Verification**

- A partner flags a streak; the subject receives a notification and the entry
  appears in history.
- A stranger attempts the same write → `403` and the UI shows an error.
- Airplane mode → queued, then delivered on reconnect.

---

#### FUNC-02 · Review expiry depends on a missing index and only runs while the app is open

**Severity:** High · **Confidence:** High · **Effort:** 2–3 days

**Evidence**

- `lib/features/human_accountability/data/datasource/review_expiry_service.dart:44-53`
  runs two queries:

  ```
  .where('status', isEqualTo: 'pendingReview')
  .where('expiresAt', isLessThan: now)
  .where('accountableUid', isEqualTo: uid)

  .where('status', isEqualTo: 'pendingReview')
  .where('expiresAt', isLessThan: now)
  .where('assignedByUid', isEqualTo: uid)
  ```

- `firestore.indexes.json` has 17 indexes. For `accountability_tasks` it has
  `accountableUid + status + expiresAt` (lines 99-107), so the first query is
  supported. It has **no `assignedByUid + status + expiresAt` index**, so the
  second query fails with `FAILED_PRECONDITION`. Because the two queries run
  inside `Future.wait` (`review_expiry_service.dart:39-54`), that failure aborts
  the whole batch: the first query's results are discarded too, and **no**
  overdue task expires.
- The exception is rethrown by `checkAndExpireTasks` and then caught by
  `_checkAndExpireTasksSafely`, which only writes a debug log
  (`review_expiry_service.dart:88-101`). The feature therefore looks healthy
  while doing nothing.
- `main.dart:132-136` starts the timer only when
  `FirebaseAuth.instance.currentUser != null` at cold start. A user who signs
  in later in the session never starts it; there is no auth-state listener.
- `ReviewExpiryService.startPeriodicCheck()` uses a `Timer.periodic`; the timer
  is suspended when the app is backgrounded or killed. A `dispose()` method
  exists (`review_expiry_service.dart:139-145`) but is never called;
  `AccountabilityBloc.close()` only calls `cancelPreciseTimer()`
  (`accountability_bloc.dart:126-137`), so the periodic timer survives
  sign-out.
- Expiry also depends on the device clock (`DateTime.now()`), while the rules
  compare `request.time`; a skewed clock yields writes the rules reject.

**Impact**

- Overdue reviews never expire, so tasks stay `pendingReview` forever.
- Streak calculations and completion stats stall.
- A doer can avoid a review outcome by never opening the app.
- The 5-minute timer keeps running after sign-out, wasting battery and
  generating permission-denied errors.
- Silent failure means no one notices until users complain.

**Remediation**

1. Add the missing composite index. The `accountableUid` variant already exists
   (`firestore.indexes.json:99-107`); the second query needs:

   ```
   { "collectionGroup": "accountability_tasks",
     "queryScope": "COLLECTION",
     "fields": [
       { "fieldPath": "assignedByUid", "order": "ASCENDING" },
       { "fieldPath": "status", "order": "ASCENDING" },
       { "fieldPath": "expiresAt", "order": "ASCENDING" }
     ]}
   ```

2. Deploy the indexes before the next release and add a CI check that runs the
   queries against the emulator with `--only firestore` so a missing index fails
   the build.
3. Move expiry to a scheduled Cloud Function (the authoritative fix). Keep the
   client timer as a best-effort UX refresh only.
4. Start the client timer on `authStateChanges` (signed in) and cancel it on
   sign-out; call `dispose()` from the app lifecycle.
5. Surface expiring-soon and expired states in the UI instead of silent state
   changes.
6. Use `FieldValue.serverTimestamp()` and `request.time` semantics; do not
   compare against the local clock for authorization decisions.

**Verification**

- `firebase deploy --only firestore:indexes` creates both indexes and the
  console shows them `Enabled`.
- An overdue task transitions to `expired` within one scheduler run.
- Sign-in mid-session starts the timer.
- Sign-out cancels it; no permission-denied logs afterwards.

---

#### FUNC-03 · A Firebase initialization failure crashes startup after the splash is frozen

**Severity:** High · **Confidence:** Medium-High · **Effort:** 1 day

**Evidence**

- `lib/main.dart:88-104` wraps `Firebase.initializeApp`,
  `GoogleSignIn.initialize` and `connectivity.initFirebase()` in a `try/catch`
  that only prints in debug mode:

  ```
  } catch (e) {
    if (kDebugMode) print('Firebase init failed (app works offline): $e');
  }
  ```

- Immediately afterwards, outside the `try`, `lib/main.dart:134` does:

  ```
  if (FirebaseAuth.instance.currentUser != null) {
    ReviewExpiryService().startPeriodicCheck();
  }
  ```

  `FirebaseAuth.instance` throws `[core/no-app] No Firebase App '[DEFAULT]' has
  been created` when initialization failed.
- `ReviewExpiryService` also has field initializers that touch
  `FirebaseAuth.instance` / `FirebaseFirestore.instance`, so even constructing
  it throws before `startPeriodicCheck` is called.
- The same pattern exists in many singletons and widgets:
  `AccountabilityService`, `AccountabilityExtensionService`,
  `CloudSyncService`, `FcmService`, `home_screen.dart:174`, and
  `daily_task_card.dart:352` all dereference `FirebaseAuth.instance` or
  `FirebaseFirestore.instance` at construction/build time.
- `FlutterNativeSplash.preserve()` runs at line 69 and is only removed later in
  the widget tree. If `main()` throws before `runApp`, the native splash is
  never removed — the user sees a frozen splash, not an error.

**Trigger conditions**

- Missing or mismatched `google-services.json` / `GoogleService-Info.plist`.
- A build variant without the Firebase config (for example a CI artifact built
  without the file).
- A device/emulator without Google Play services.
- A platform where the Firebase plugin is unavailable (desktop, web).
- A corrupted Firebase installation or an unsupported Android API level.

**Impact**

- The app is unusable with no diagnostic, no retry and no offline mode — despite
  the comment claiming "app works offline".
- Store reviewers on unusual devices may reject the build.
- Crash reports are not captured because Crashlytics is also unavailable.

**Remediation**

1. Track initialization success in a boolean (`_firebaseReady`). If it fails,
   run the app in a clearly-labeled offline mode and disable auth/partner/AI
   surfaces.
2. Never dereference `FirebaseAuth.instance` at field-initializer or build
   time. Inject an `AuthGateway`/`FirestoreGateway` that returns `null`/`empty`
   when Firebase is unavailable, or guard every access with a try/catch.
3. Wrap `ReviewExpiryService` startup in a guard and start it from an auth-state
   listener, not at cold start.
4. Add a startup error screen with "Continue offline" and "Retry", and remove
   the splash in a `finally`.
5. Add a widget test that constructs `MyApp` with Firebase unavailable and
   asserts the offline screen renders.
6. Add a CI smoke test that builds and launches without the Firebase config
   files (or with an intentionally invalid one) and checks for a non-crashing
   start.

**Verification**

- Launch with `google-services.json` renamed → offline banner, no crash.
- Launch with a valid config → normal flow.
- `flutter test` covers the no-Firebase path.
- Crashlytics reports no startup `no-app` errors after release.

---

### 5.5 Platform and store compliance

#### COMP-01 · There is no in-app account deletion

**Severity:** High · **Confidence:** High · **Effort:** 3–5 days

**Evidence**

- `grep -rn "deleteAccount\|deleteUser\|user.delete" lib` returns **nothing**.
- `lib/screens/settings_screen.dart` offers Export Data, App Version, Privacy
  Policy, Terms, Daily Motivation and Reset Challenge — no account deletion.
- `lib/screens/profile_screen.dart:1002-1078` offers "Back up & sign out", which
  keeps the account and all cloud data.
- The privacy policy defers deletion to email:
  `lib/screens/privacy_policy_screen.dart:86` —
  "you can request deletion of your account and associated cloud data by
  contacting us at the address below"; and `:106` gives
  `hello@thecodershub.in`.
- Deletion would need to cover: `users/{uid}`, `user_data/{uid}`,
  `public_progress/{uid}` (+ `days`), `entitlements/{uid}`, partnerships where
  the user is owner or partner (+ `messages`), `partner_reviews` as subject and
  reviewer, `accountability_tasks` as creator/assignee/reviewer,
  `invitations`, `invite_codes`, `task_collaborators`, `fcm_notifications`,
  `accountability_notifications`, `streak_actions`, Storage objects
  (`task_proofs`, `profile_avatars`), the FCM token and the Firebase Auth user.
  None of this exists.

**Why this is a release blocker**

- **Apple App Store Review Guideline 5.1.1(v):** apps that support account
  creation must let users delete their account in-app. An email-only process is
  not sufficient.
- **Google Play Data deletion policy:** apps with accounts must provide an
  in-app deletion path **and** a web-accessible deletion request URL declared in
  the Data Safety form.
- **GDPR Art. 17 / CCPA / India DPDP:** deletion must be effective, not a
  mailbox. A manual email process with no SLA and no verification is a
  compliance gap.
- **Data minimisation:** the app retains backups, proofs and partner-share
  records indefinitely after a user stops using it.

**Remediation**

1. Add Settings → Account → "Delete account" with a two-step confirmation that
   explains exactly what will be deleted and what will be retained (for
   example, legally required transaction records — none apply here).
2. Require recent re-authentication (`reauthenticateWithCredential`) before
   deletion. For Google Sign-In, force a fresh sign-in.
3. Implement deletion in a Cloud Function (see INFRA-02) so it is atomic,
   auditable and cannot be half-completed by a client crash:
   - revoke entitlements and cancel subscriptions (or instruct the user to
     cancel in the store);
   - delete Storage objects by prefix;
   - delete or anonymise documents where the user is a counterparty (for
     example, replace the name in a partner's review history with "Deleted
     user");
   - delete the Auth user last;
   - write an audit record with a timestamp and a deletion receipt ID.
4. Send a confirmation email and show an in-app receipt.
5. Publish a web deletion URL for Play.
6. Add a retention policy for orphaned media and inactive accounts (for example
   24 months).
7. Test the flow end-to-end on a staging project, including the case where the
   user is a partner in an active challenge.

**Verification**

- A test account can be deleted in-app in under two minutes.
- Firestore, Storage and Auth contain no documents/objects for the UID.
- Counterparties see "Deleted user" rather than a broken reference.
- The Play Data Safety form links to a working web deletion page.
- An App Store reviewer can find the control without reading the policy.

---

#### COMP-02 · No Sign in with Apple, and the policy claims an email login that does not exist

**Severity:** High · **Confidence:** High · **Effort:** 2–3 days

**Evidence**

- Only Google Sign-In is implemented:
  - `lib/core/services/cloud_sync_service.dart:176-210` (`signInWithGoogle`);
  - `lib/screens/login_screen.dart:21-30`;
  - `lib/screens/onboarding_screen.dart:393-460`;
  - `lib/screens/profile_screen.dart:963`.
- `pubspec.yaml` has no `sign_in_with_apple` dependency, and `ios/Runner` has
  no Apple sign-in entitlement.
- The privacy policy says: "you sign in with Google or email"
  (`privacy_policy_screen.dart:46`). There is no email/password flow. This is a
  factual misstatement in a legal document.
- The iOS app declares a Google client ID (`Info.plist:38`) and uses the Google
  SDK, so Apple's third-party-login rule applies.

**Why this is a release blocker**

- **App Store Review Guideline 4.8:** an app that uses a third-party login
  service for its primary account must also offer an equivalent option that
  limits data collection to name and email — in practice, Sign in with Apple.
  Exceptions are narrow (for example, exclusively using the company's own
  account system), and none apply here.
- A rejection costs a release cycle and may block a coordinated marketing launch.
- An email-only fallback would also satisfy the guideline, but it requires a
  full password-reset, verification and abuse-prevention flow — more work than
  Sign in with Apple.

**Remediation**

1. Add `sign_in_with_apple`, the `com.apple.developer.applesignin`
   entitlement, and a "Continue with Apple" button on every auth surface
   (onboarding, login, profile upgrade).
2. Handle Apple's private relay email: treat it as an opaque verified address;
   do not require a domain or attempt to derive a name from it.
3. Handle the "hide my email" case in the partner invitation flow (the relay
   address must be usable as `toEmail`).
4. Link an existing account if the same person signs in with Apple and Google
   (Firebase `linkWithCredential`) and explain the choice.
5. Update the privacy policy to list Apple as an identity provider and correct
   the "Google or email" statement.
6. Add a widget test for the Apple button and a manual QA checklist for the
   relay-email path.

**Verification**

- A reviewer can create an account with Apple on a clean device.
- The account appears in Firebase Auth with `apple.com` provider data.
- Partner invitations work with a private relay address.
- The policy matches the available sign-in methods.

---

#### Legal observations that are not scored

These items are outside the engineering severity model because they depend on
marketing copy and counsel's analysis, but they can block a launch:

- **"75 Hard" naming.** The repository, internal documents and this report's
  working title use "75 Hard", the name of a well-known paid fitness programme.
  The current store label is "DailyMettle: Habit & Challenge"
  (`AndroidManifest.xml:30`), which reduces but does not remove the risk. If the
  store listing, screenshots, keywords or website use "75 Hard", counsel should
  confirm that the use is nominative and not likely to cause confusion, and be
  prepared for a trademark complaint. Do not rely on the repository name being
  private.
- **Health claims.** A 75-day discipline challenge is adjacent to fitness and
  mental health. Avoid claims that the app treats, prevents or cures any
  condition, and avoid presenting streak failure as a health outcome. Journal
  content can reveal health data, which may be special-category data under GDPR
  Art. 9 even though the app is not a HIPAA covered entity.
- **Subscription disclosures.** When the paywall in MON-01 is built, it must
  show price, renewal period, cancellation path and restore-purchases before
  purchase, on both stores. This is a review requirement, not a growth tactic.

---

### 5.6 CI/CD, dependencies and testing

#### CICD-01 · A version tag ships straight to production with no test gate

**Severity:** High · **Confidence:** High · **Effort:** 2–3 days

**Evidence**

- `codemagic.yaml:7-13` and `:87-93` trigger both workflows on any `v*.*.*`
  tag.
- `codemagic.yaml:25-63` (Android) runs: set up keystore, local.properties,
  `flutter pub get`, `flutter build appbundle`. There is **no**
  `flutter analyze`, **no** `flutter test`, **no** rules test and **no** manual
  approval.
- `codemagic.yaml:77-80` publishes with `track: production` and
  `submit_as_draft: false` — a tag goes to all users, with no staged rollout.
- The build passes **no** `--dart-define` values for `CLOUDINARY_*`,
  `GEMINI_API_KEY` or `NVIDIA_API_KEY`. Production therefore silently falls
  back to Firebase Storage for photos and has no AI features, while the debug
  build behaves differently.
- `--build-name=1.0.$BUILD_NUMBER` overrides the pubspec version, so the store
  version and the repository version drift.
- No `--obfuscate --split-debug-info`; the Dart symbols are easier to read.
- The iOS workflow (`codemagic.yaml:82-134`) publishes to TestFlight on the same
  tag with no tests.
- `.github/workflows/dart.yml` does run analyze and tests, but:
  - `flutter analyze --no-fatal-infos` downgrades info-level findings;
  - the build embeds `NVIDIA_API_KEY` and uploads the APK as a public artifact
    (SEC-03);
  - actions are pinned to tags (`@v4`, `@v2`), not commit SHAs;
  - there is no `permissions:` block, so the default `GITHUB_TOKEN` scope
    applies;
  - there is no CodeQL, dependency review, secret scanning or SBOM step.

**Impact**

- A regression, a broken rules deploy or a dependency compromise can reach
  production users with no automated check.
- The production artifact differs from the tested artifact because of missing
  defines.
- A compromised action tag can exfiltrate secrets.
- Store versioning becomes unauditable.
- No staged rollout means a bad release reaches 100% of users at once.

**Remediation**

1. Add a required `quality` job to Codemagic:
   `flutter analyze --fatal-infos`, `dart format --set-exit-if-changed`,
   `flutter test --coverage`, rules tests, and a coverage threshold.
2. Make the publish step depend on that job and require manual approval for
   production. Use `submit_as_draft: true` plus a staged rollout (for example
   5% → 20% → 50% → 100%).
3. Pass the same `--dart-define`s in every environment, sourced from
   environment groups. Fail the build if a required define is empty.
4. Derive the version from `pubspec.yaml` (`--build-name` from
   `flutter pub get` output or `sed`), or bump both in one script.
5. Add `--obfuscate --split-debug-info=build/symbols` and upload symbols to
   Crashlytics.
6. Pin GitHub Actions to full commit SHAs and add
   `permissions: contents: read` at the workflow level.
7. Add CodeQL, `flutter pub outdated` (fail on known-vulnerable packages),
   `osv-scanner`, secret scanning and a generated SBOM.
8. Stop uploading signed release APKs as artifacts; publish only to the store.
9. Sign Android App Bundles, not APKs, for production; keep APKs for internal
   QA only.
10. Add a release checklist that includes the rules deploy and index deploy.

**Verification**

- A tag with a failing test does not reach Codemagic publishing.
- The production AAB contains the Cloudinary and AI defines (verified by a
  runtime smoke test), or the features are explicitly disabled.
- The store version matches the git tag.
- `zizmor`/`actionlint` reports no unpinned actions or broad permissions.
- A canary rollout reaches 5% before 100%.

---

#### TEST-01 · Coverage is 10.4% and the critical paths have no tests

**Severity:** High · **Confidence:** High · **Effort:** 3–4 weeks (ongoing)

**Evidence**

- `flutter test --coverage` → **1,843 / 17,673 lines = 10.43%** across 120
  measured files.
- The denominator is only 17,673 of the 47,380 lines in `lib/` — **29,707 lines
  (62.7%) are never loaded by any test**, so their coverage is effectively
  zero. The largest and most security-relevant files are in that set:
  - `accountability_screen.dart` — 4,706 lines
  - `accountability_service.dart` — 3,467 lines
  - `onboarding_screen.dart` — 2,094 lines
  - `home_screen.dart` — 1,422 lines
  - `challenge_bloc.dart` — 1,242 lines
- There is no `integration_test/` directory and no golden tests.
- `rules-tests/firestore_rules_smoke.js` has **3** `expectDenied` assertions in
  163 lines. It does not test partnership forgery, invite claiming, self-approval,
  review spam, user enumeration or task-create injection.
- Tests pass despite visible Firebase failures. A test run prints
  `[core/no-app] No Firebase App '[DEFAULT]' has been created` and
  `Compression failed: UnimplementedError`, then reports success — the error
  paths are swallowed, not asserted.
- No coverage threshold is configured in CI; 10% and 0% are treated the same.

**Impact**

- The regression that reintroduces AUTH-01..08 would not be caught.
- Payment, deletion, backup restore, migration and multi-account isolation are
  untested — exactly the flows where a bug is unrecoverable.
- The green test badge creates false confidence for the owner and for a future
  acquirer or auditor.
- Refactoring the 3,467-line service is unsafe without a safety net.

**Remediation**

1. **Set a ratchet, not a moonshot.** Add a CI check that fails if coverage
   drops below the current value plus 1 point, and raise it every sprint.
   Target 40% in 90 days, 60% in 6 months.
2. Write emulator rules tests for every finding in §5.2. This is the highest
   return on effort: a single test file can cover AUTH-01..08.
3. Add unit tests for:
   - `CloudSyncService` encrypt/decrypt round-trip, legacy migration, wrong-key
     failure, tamper detection, concurrent sync;
   - `CloudBackupKeyStore` create/rotate/delete/missing-key;
   - `ReviewExpiryService` query construction and clock skew;
   - `Trial`/entitlement parsing for malformed, expired and revoked documents;
   - `RegularTaskRepository` migration and ID repair;
   - `OfflineTaskOutbox` ordering, retry and account isolation.
4. Add integration tests (Firebase emulator + `integration_test`) for:
   sign-in → invite → accept → task → proof → review → expiry → sign-out;
   purchase → entitlement → gate; delete account → data gone.
5. Add widget tests for the paywall, onboarding, settings and account deletion.
6. Add golden tests for the three highest-traffic screens to catch layout
   regressions at large text scales.
7. Make tests fail on unhandled Firebase errors: initialise a fake app or a
   strict mock, and assert on `FlutterError.onError`.
8. Track coverage in the README badge and review it in every release.

**Verification**

- `flutter test --coverage` reports ≥ 40% and CI enforces it.
- The rules test suite has ≥ 30 assertions covering every deny path.
- A deliberately reintroduced AUTH-03 bug fails CI.
- No test output contains an unasserted `no-app` error.

---

### 5.7 Performance, UI/UX and accessibility

The app looks polished in screenshots and the design tokens in
`lib/core/theme/` are a good foundation. The problems are scale: a handful of
screens and services have absorbed most of the product, and the UI layer
bypasses the design system almost everywhere. None of these are launch blockers
on their own; together they produce jank, battery drain and an accessibility
gap that will show up in reviews.

#### 5.7.1 Measured indicators

| Indicator | Value | Why it matters |
|---|---:|---|
| Largest screen | `accountability_screen.dart`, **4,706 lines** | Rebuilds the whole subtree; impossible to test |
| `setState` calls in that screen | **39** | Each one can rebuild a large subtree |
| Eager `ListView(` vs `ListView.builder` | **15 vs 10** | Long lists build every child up front |
| `Image.network` vs `CachedNetworkImage` | **10 vs 1** | Re-download and re-decode on every rebuild |
| `GoogleFonts.` call sites | **147** | Runtime font fetch; first-frame jank and offline fallback |
| Hard-coded `fontSize:` values | **458** | Ignores theme, text scale and design tokens |
| Fixed `Colors.white` / `Colors.black` | **255** | Dark-mode contrast failures |
| `Semantics(` widgets | **3** | Screen readers get almost no labels |
| `Tooltip(` widgets | **3** | Icon-only actions are unexplained |
| `textScaleFactor` / `textScaler` handling | **0** | Large-text users can overflow layouts |
| Localization setup (`flutter_localizations`, `l10n/`) | **none** | Every string is hard-coded English |
| `SafeArea(` / `SingleChildScrollView` | 28 / 19 | Good baseline, but not universal |
| `shrinkWrap: true` | 1 | Nested scrolling risk in that list |
| Blocking work before `runApp` | Hive, notifications, Firebase, GoogleSignIn, connectivity, 2 repositories, session read, migration | Cold start is serial and fail-open |

#### 5.7.2 What users will feel

1. **Silent failure.** Streak flags, in-app notifications, expiry and cloud sync
   can fail without any visible message (FUNC-01/FUNC-02). A spinner that stops
   with no result is worse than an error.
2. **A promise gap.** The AI coach screen exists but is unreachable
   (`AiCompanionScreen` has no navigator entry), and premium has no purchase
   path (MON-01). Users who read the store listing or onboarding will look for
   features that are not there.
3. **English-only in an India-first product.** The AI prompt explicitly
   supports Marathi and Hindi journaling, but the UI has no localization
   delegates and no `l10n/` directory. Every label is an English string
   literal.
4. **Accessibility.** Three `Semantics` widgets and three tooltips across 139
   files means most icon buttons, progress rings and status chips are opaque to
   TalkBack/VoiceOver. Fixed font sizes and 255 hard-coded colors make large
   text and high-contrast modes unreliable.
5. **Startup.** `main()` performs every initialization serially before
   `runApp`, while the native splash is preserved. On a cold start with a large
   Hive database and a slow network, the splash can sit for seconds; if any
   step throws outside a guard, it never leaves (FUNC-03).
6. **List and image performance.** Eager `ListView`s and `Image.network` in
   scrolling surfaces cause repeated decoding and memory spikes, especially on
   low-end Android devices common in the target market.
7. **Keyboard and small screens.** `MediaQuery.viewInsets` is handled in only a
   few sheets; several forms rely on `resizeToAvoidBottomInset` defaults and can
   hide the submit button behind the keyboard.
8. **No offline/error design system.** There is a connectivity service, but no
   consistent offline banner, retry component or empty-state illustration. Each
   screen improvises.
9. **Destructive-action inconsistency.** "Reset Challenge" has a confirmation
   dialog, but account deletion does not exist (COMP-01) and partner removal has
   no undo.
10. **Localization of dates and numbers.** `intl` is used in places, but not
    consistently; some dates are formatted manually, which will break for
    non-Gregorian locales and 12/24-hour preferences.

#### 5.7.3 Priority fixes

| Priority | Fix | Effort |
|---|---|---|
| P1 | Split `accountability_screen.dart` into tab widgets with `BlocSelector`; replace `setState` with bloc state | 5–8 days |
| P1 | Replace eager lists with `ListView.builder` + `itemExtent`/`prototypeItem` where possible | 1–2 days |
| P1 | Replace `Image.network` with `CachedNetworkImage` and a memory cache policy | 1 day |
| P1 | Add a global `AsyncStateView` (loading/empty/error/retry) and use it on every network screen | 3 days |
| P2 | Bundle fonts and remove runtime `GoogleFonts` fetching (also a privacy fix, PRIV-01) | 1–2 days |
| P2 | Move hard-coded sizes/colors onto `figma_tokens.dart` and `Theme.of(context)` | 5–10 days |
| P2 | Add `Semantics` labels to every icon-only control and progress indicator | 3–5 days |
| P2 | Add `textScaler` clamp tests at 1.3×, 1.6× and 2.0×; fix overflows | 3 days |
| P3 | Add `flutter_localizations` + ARB files for English, Hindi and Marathi | 5–8 days |
| P3 | Add golden tests for the top five screens at two sizes and two text scales | 3 days |

---

### 5.8 Code quality and maintainability

#### 5.8.1 Structure

The codebase is split across two architectures:

- `lib/features/<feature>/{data,domain,presentation}` — the intended clean
  layering, used by the accountability feature.
- `lib/screens`, `lib/services`, `lib/repositories`, `lib/widgets` — the older
  layer-first structure, still holding the largest files
  (`accountability_screen.dart` lives under `features` but imports from both).

This is not cosmetic. It means there are two ways to reach Firestore, two ways
to show a notification, two ways to model a user, and no single place to enforce
a rule.

#### 5.8.2 Measured indicators

| Indicator | Value | Comment |
|---|---:|---|
| Dart files / lines in `lib/` | 139 / 47,380 | 166 files including tests |
| Largest file | 4,706 lines | 10% of the codebase in one widget |
| Largest service | 3,467 lines | Auth + Firestore + email + notifications + reviews |
| Singletons (`_instance`, factory) | 27 | Hidden global state, hard to test |
| `dynamic` usages | 178 | Weak typing at Firestore/JSON boundaries |
| `late` fields | 45 | Initialization-order risk |
| Empty catches | 35 | Failures disappear |
| `catch (_)` | 78 | No type, no message, no telemetry |
| `TODO`/`FIXME`/`HACK` comments | 0 | No tracked debt markers; the four case-insensitive matches are identifiers such as `toDouble()` and an icon keyword |
| `print`/`debugPrint` sites | 294 | Some unguarded and PII-bearing |
| Unreachable/dead features | 2 major | `AiCompanionScreen`, `PremiumPurchaseService` |
| Firebase singleton access in widgets | 10+ | `FirebaseAuth.instance` in `build()` paths |

#### 5.8.3 Specific defects

1. **`AccountabilityService` is a god object.** It owns authentication,
   partnership lifecycle, invite codes, email lookup, task CRUD, proof review,
   notifications, scoring inputs and clock handling. A single change to review
   rules requires editing a 3,467-line file with no seam for a unit test.
2. **Two sources of truth for reviewer rules.** `_isReviewerOf` in Dart
   (`accountability_service.dart:3237-3245`) and `isProofReviewer` in rules
   (`firestore.rules:99-105`) disagree — the Dart version excludes the doer, the
   rules version includes them (AUTH-03). Duplicated authorization logic always
   drifts.
3. **Rule logic is not testable in isolation.** There is no shared model of
   "who may review", no generated rules tests from a table, and only three
   emulator assertions. The rules are the most security-critical code in the
   product and the least tested.
4. **Side effects in getters.** `RegularTaskRepository.getActiveTasks()` is a
   synchronous getter that writes to Hive (`regular_task_repository.dart:50-63`).
   It can throw if the box is null, performs unawaited writes, and is called
   from bloc handlers during UI work.
5. **Error handling is inconsistent.** Some services return `null`, some return
   `[]`, some throw, some log and continue. Callers cannot distinguish "empty"
   from "denied" from "offline". This is the root of FUNC-01 and much of the
   silent-failure UX.
6. **The domain model overloads "owner".** In `accountability_tasks`,
   `assignedByUid` is the creator/reviewer and `accountableUid` is the doer; in
   partnerships, `ownerUid` is the inviter. The UI uses "owner" for both. This
   ambiguity is visible in the rules and is a direct contributor to AUTH-01 and
   AUTH-03.
7. **Model duplication.** `AppUser` and Firebase `User`, `PartnerReview` and
   task review fields, and two notification models
   (`AccountabilityNotification`, `fcm_notifications` payloads) overlap without a
   single mapping layer.
8. **Comments assert guarantees the code does not provide.** "the doer can never
   self-approve" (rules), "We cannot read your content" (UI), "export a recovery
   key when that feature is available" (policy). Comments are not tests; these
   should be removed or enforced.
9. **No dependency injection for Firebase.** `FirebaseAuth.instance` is called
   inside widgets, services and field initializers. Only `CloudSyncService` has
   a `forTesting` constructor. This makes the 62.7% of untested code hard to
   test and encourages the `no-app` failures seen in the test log.
10. **No static analysis beyond `flutter_lints`.** There are no
    `strict-casts`, `strict-raw-types`, `strict-inference` flags, no
    `custom_lint`, and `flutter analyze --no-fatal-infos` in CI (L10).

#### 5.8.4 Recommended refactor sequence

1. Extract `PartnershipRepository`, `TaskRepository`, `ReviewRepository` and
   `InviteRepository` behind interfaces; keep `AccountabilityService` as a thin
   facade for one release.
2. Move all authorization decisions into a single `Policy` module that both the
   client and the rules tests reference conceptually (the rules cannot import
   Dart, but the test table can).
3. Introduce `AuthGateway`/`FirestoreGateway` interfaces and inject them; remove
   `FirebaseAuth.instance` from widgets.
4. Standardize results as `Result<T, AppError>` and delete the 35 empty catches.
5. Split the 4,706-line screen by tab and by feature; target < 500 lines per
   widget file.
6. Add `strict-casts`/`strict-raw-types` and fix the 178 `dynamic` sites
   incrementally.
7. Delete dead code (`AiCompanionScreen`, `PremiumPurchaseService` until MON-01
   is funded) or wire it deliberately.

---

### 5.9 Medium and low findings register

The findings below are real but lower-leverage than §5.1–§5.6. They are grouped
here so the remediation roadmap can schedule them without diluting the Critical
and High work. Every row is evidence-linked; the notes after the table explain
the ones that need context.

#### 5.9.1 Medium findings (M1–M18)

| ID | Finding | Evidence | Impact | Effort |
|---|---|---|---|---|
| M1 | Direct dependencies are 1–2 major versions behind and there is no update automation | `pubspec.lock`: `firebase_core 3.15.2` vs 5.1.0, `firebase_auth 5.7.0` vs 7.0.1, `cloud_firestore 5.6.12` vs 7.1.0; no Dependabot/Renovate config | Missed security fixes, larger future migration, target-SDK incompatibility | 5–8 days |
| M2 | Large screens, eager lists, uncached images and runtime font fetching | §5.7; `accountability_screen.dart` 4,706 lines, 39 `setState`; 15 eager `ListView`; 10 `Image.network` vs 1 cached; 147 `GoogleFonts` | Jank, battery drain, memory spikes on low-end devices | 10–15 days |
| M3 | Accessibility coverage is minimal | 3 `Semantics`, 3 `Tooltip`, 0 `textScaler`, 458 fixed font sizes, 255 fixed colors | Screen-reader and large-text users cannot use core flows | 8–12 days |
| M4 | UI/UX state handling is inconsistent; no localization | §5.7; no `flutter_localizations`/`l10n`; ad-hoc loading/empty/error states; silent failures | Confusing failures, English-only product, store-review risk | 8–12 days |
| M5 | Android permissions and lock-screen behavior are over-broad | `AndroidManifest.xml:3-26` (14 permissions incl. `USE_EXACT_ALARM`, `ACCESS_NOTIFICATION_POLICY`, `USE_FULL_SCREEN_INTENT`, `RECORD_AUDIO`, `READ/WRITE_EXTERNAL_STORAGE`); `showWhenLocked`/`turnScreenOn` on `MainActivity` | Play policy rejection, privacy review friction, lock-screen exposure | 2–3 days |
| M6 | iOS privacy manifest omits user content and health data | `ios/Runner/PrivacyInfo.xcprivacy` lists Crash, Performance, ProductInteraction, Email, UserID, Photos/Videos; no `NSPrivacyCollectedDataTypeUserContent` or Health/Fitness | App Store privacy-label mismatch; rejection risk | 1–2 days |
| M7 | No abuse controls, rate limits or App Check | `grep -rn "AppCheck" lib` → none; no counters/quotas; client-writable reviews/tasks/messages | Spam, cost abuse, scraping, bot traffic | 3–5 days (with backend) |
| M8 | Error handling is inconsistent and early/async failures are not captured | 35 empty catches, 78 `catch (_)`; `FlutterError.onError` is installed only after Firebase init (`connectivity_service.dart:86-95`); no `PlatformDispatcher.instance.onError` or `runZonedGuarded`; Crashlytics only otherwise via `AnalyticsService.recordError` | Pre-init and uncaught async failures vanish; blank screens, slow diagnosis | 3–5 days |
| M9 | Repository history and internal documents are bloated and expose IP | `.git` = **4.0 GB**, 58,725 objects, 221 commits; 40 tracked Markdown, 45 `.kiro` files incl. prompts/specs; local checkout 12 GB (`ios/` 6.9 GB of Pods/build output, `build/` 1.0 GB) | Clone/CI cost, secret surface, leaked product reasoning | 1–2 days |
| M10 | Partnership streams are owner-side only | `accountability_service.dart:1042-1052` — "Stream owner-side partnerships; partner-side requires a separate stream"; the comment admits the gap | Partner-side updates are stale until a manual refresh | 1–2 days |
| M11 | A synchronous getter performs unawaited Hive writes | `regular_task_repository.dart:50-63` — `getActiveTasks()` mutates and deletes records; called from `regular_task_bloc.dart:40,133` | Data loss if the write fails, exceptions during build, non-deterministic state | 1–2 days |
| M12 | Five overlapping notification stacks | `SmartNotificationService`, `NotificationService`, `FcmService`, `NotificationDispatchListener`, `AccountabilityNotificationService`; two Firestore collections (`fcm_notifications`, `accountability_notifications`) | Duplicate notifications, inconsistent channels/preferences, hard to reason about delivery | 4–6 days |
| M13 | Documentation and in-app policy drift from behavior | `privacy_policy_screen.dart:46` ("Google or email" — only Google exists), `:51` ("export a recovery key when that feature is available" — it is not), `:81` (omits NVIDIA/Gemini/Google Fonts); README describes premium as server-controlled, but no backend writes entitlements (MON-01) | Legal/compliance risk, user mistrust | 2 days |
| M14 | Brand and identity are inconsistent across platforms | App "DailyMettle", repo `seventy_five_hard_tracker`, iOS bundle `com.seventyfive.hard.challenge`, Android namespace `com.example.seventy_five_hard_tracker`, Firebase project `dailymettle`, contact `hello@thecodershub.in` | Store listing confusion, support misrouting, hard-to-reverse namespace | 2–4 days |
| M15 | Offline and conflict handling only covers task writes | `OfflineTaskOutbox` handles tasks; reviews, notifications, streak actions and invites are fire-and-forget; expiry uses the device clock | Lost writes on flaky networks, inconsistent state after reconnect | 5–8 days |
| M16 | No observability, alerting or SLOs | No dashboards, alerts or runbooks; failures mostly go to `debugPrint`; Crashlytics captures framework fatals but nothing alerts on them | Outages and abuse are discovered by users | 3–5 days |
| M17 | The Cloudinary signer does not bind the object to the caller | `photo_sync_service.dart:215-230` signs client-chosen `folder` and `public_id` (`${challengeId}_$proofDate`); avatar `public_id` is the UID | Cross-user overwrite if the signer does not independently authorize the path | 2–3 days |
| M18 | Development and production share one Firebase project | `lib/firebase_options.dart` and `google-services.json` are a single `dailymettle` project; no flavors or `applicationIdSuffix` | Debug/test data pollutes production; accidents are irreversible | 2–3 days |

##### Notes on selected Medium findings

**M1 — dependency drift.** The Firebase family is two majors behind. That is
not automatically a CVE, but it means the app is not receiving current security
fixes and will face a much larger migration under pressure. Add Renovate or
Dependabot with grouped PRs, pin to exact versions, and schedule a Firebase
upgrade sprint after the Critical work. Test on a branch with the emulator
suite; do not combine the upgrade with a feature release.

**M5 — permissions.** `USE_EXACT_ALARM` and `SCHEDULE_EXACT_ALARM` are
restricted to alarm/calendar-class apps on Google Play; a habit tracker is
likely to be rejected or asked to justify them. `ACCESS_NOTIFICATION_POLICY`
(DND bypass) and `USE_FULL_SCREEN_INTENT` are similarly restricted. Remove
them and use inexact alarms/WorkManager for reminders, plus a normal
notification channel. `READ/WRITE_EXTERNAL_STORAGE` should be replaced by the
Photo Picker and scoped media APIs. `RECORD_AUDIO` should be requested only
when the user taps the microphone, with a clear rationale. Remove
`showWhenLocked`/`turnScreenOn` unless a genuine alarm feature requires them —
otherwise the app can appear over the lock screen.

**M6 — privacy manifest.** The manifest has the required-reason API categories
(UserDefaults, file timestamp, disk space, system boot time) and six collected
types, but it is missing the categories that matter most for this app:
`NSPrivacyCollectedDataTypeUserContent` (journal notes, task names, chat),
`NSPrivacyCollectedDataTypeHealth`/`Fitness` if habit/health inferences are
made, and `NSPrivacyCollectedDataTypeAudioData` if speech audio leaves the
device. Align the manifest with the Play Data Safety form and the actual
network capture. Apple compares the manifest, the App Store Connect privacy
answers and observed traffic; mismatches cause rejection or post-release
takedown risk.

**M8 — error handling.** `connectivity_service.dart:86-95` does install
`FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`,
but only after Firebase initialises successfully. Errors before that point, and
uncaught asynchronous errors outside the Flutter framework, are not captured:
`PlatformDispatcher.instance.onError` and `runZonedGuarded` are absent.
Crashlytics is otherwise invoked only from `AnalyticsService.recordError`, which
requires the caller to remember to call it. Install both global handlers in
`main` before `runApp`, forward non-fatals with context, and add a user-visible
fallback for unhandled errors in critical flows.

**M10 — stream scoping.** `fetchMyPartnerships()` does two queries and merges
them, so the initial load is correct. The live stream is owner-only, so when a
partner accepts an invite or sends a message, the inviter's Squad list does not
update until the screen is rebuilt/refreshed. Model membership as a
`members: [uid]` array and stream `where('members', arrayContains: uid)`, or
merge two streams with `StreamGroup.merge`.

**M11 — getter side effects.** `getActiveTasks()` repairs empty IDs by writing
to Hive and deleting the `''` key. Because the method is synchronous, the
writes are not awaited and errors are unhandled. If the box is not initialized,
`_tasksBox!` throws. Move the repair to `init()` as an awaited migration, make
the getter pure, and add a test with legacy empty-ID data.

**M12 — notification stacks.** There are at least five notification-related
services and two Firestore collections. Some paths write both
`fcm_notifications` and `accountability_notifications`; others write only one.
Channels are created in multiple places. Consolidate behind one
`NotificationFacade` with a channel registry, a single delivery queue and one
preference model. Until then, add a table in the README that maps each event to
its transport.

**M17 — Cloudinary signer.** The signer is a separate service, so this finding
is conditional: if the endpoint independently checks that the caller owns the
`challengeId`/`uid` in `public_id`, the risk is contained. The repository does
not contain the signer implementation, so the contract cannot be verified. Treat
it as unverified: the client sends `folder=task_proofs` and
`public_id={challengeId}_{date}`; a malicious client can send any values. The
signer must derive the path from the authenticated Firebase ID token, ignore
client-supplied `folder`/`public_id`, enforce a short timestamp window, and log
every signature with the caller UID.

**M18 — one Firebase project.** Debug builds, CI artifacts and production all
use `dailymettle`. A developer testing account deletion or a destructive
migration can delete real data. Create `dailymettle-dev` and
`dailymettle-staging`, add Android product flavors and iOS schemes, and make
the production config available only to the release pipeline.

#### 5.9.2 Low findings (L1–L14)

| ID | Finding | Evidence | Why it matters | Fix |
|---|---|---|---|---|
| L1 | The upload certificate is tracked in `HEAD` | `git ls-files` → `upload_certificate.pem`; certificate only, not the private key | Confirms signing identity; unnecessary public artifact | Remove from tracking and history |
| L2 | Obsolete or over-broad manifest attributes | `requestLegacyExternalStorage="true"` (ignored at targetSdk 36), `taskAffinity=""`, `resizeableActivity="true"`, no `enableOnBackInvokedCallback` | Confusing behavior, future Android compatibility | Clean up with the M5 permission work |
| L3 | iOS background mode is unused and FCM background mode is missing | `Info.plist` declares `UIBackgroundModes: fetch`; no background fetch implementation; no `remote-notification` | App Store may question the mode; background pushes will not wake the app | Remove `fetch`; add `remote-notification` only when a server sends pushes |
| L4 | Export-compliance declaration is likely wrong | `ITSAppUsesNonExemptEncryption=false` while the app implements AES-256-GCM | App Store Connect export compliance mismatch; possible review delay | Set `true` and file the self-classification report, or document the exemption with counsel |
| L5 | Android namespace still uses `com.example` | `android/app/build.gradle`: `namespace = "com.example.seventy_five_hard_tracker"` vs `applicationId com.seventyfive.hard.challenge` | Unprofessional package identity; R-class/naming confusion; hard to change later | Rename before the next release |
| L6 | No deep-link/universal-link verification | No `assetlinks.json` or `apple-app-site-association`; custom schemes in the manifest | Invite links can be hijacked by another app; poor onboarding | Add App Links/Universal Links with verification |
| L7 | IDs are timestamps | `millisecondsSinceEpoch` used for sessions, tasks, journal entries, regular tasks (`challenge_bloc.dart:19,230`; `journal_entry.dart:30`; `create_task_sheet.dart:279`) | Collisions on rapid creation or clock changes; unstable IDs across restores | Use UUIDv4/ULID; keep timestamps as metadata only |
| L8 | `email_verified` is never checked | `firestore.rules` uses `request.auth.token.email` in invitations/partnerships/tasks; no `email_verified` predicate; `users.email` is client-writable | Weakens email-bound authorization; allows unverified-email edge cases | Require `email_verified == true` wherever email is an authorization factor |
| L9 | Sign-out is blocked when backup fails | `profile_screen.dart:1003-1078`; `SignOutPreparationStatus.keepsLocalData` | A user on a shared/lost device cannot sign out without a working network/backup | Offer "sign out and discard local data" with an explicit confirmation |
| L10 | Lint configuration is minimal | `analysis_options.yaml` uses only `flutter_lints`; no `strict-casts`, `strict-raw-types`, `strict-inference`; CI uses `--no-fatal-infos` | Type and null-safety issues survive review; 178 `dynamic` sites persist | Enable strict flags incrementally; make infos fatal in CI |
| L11 | No license, security policy or contribution guide | `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS` all absent | Unclear usage rights; no vulnerability disclosure path; bus-factor risk | Add all four; enable private vulnerability reporting |
| L12 | The web build is disabled and the Docker preview stage is dead | `Dockerfile`: `# RUN flutter build web --release`, preview stage serves an empty `/srv` | Misleading deployment artifact; wasted CI/maintenance | Remove the preview stage or implement a supported target |
| L13 | Developer documentation drifts from the code | `README.md` describes Cloudinary/premium behavior that depends on build defines never passed in Codemagic; no architecture diagram; setup steps incomplete | Onboarding cost; repeated misconfiguration | Treat docs as code; add a build matrix and architecture diagram |
| L14 | Debug logging is verbose and occasionally PII-bearing | 294 `print`/`debugPrint` sites; `photo_sync_service.dart:122` logs the full Cloudinary URL; accountability logs include UIDs/emails | Log leakage in debug builds and CI artifacts; noisy support | Use a logger with levels/redaction; strip logs in release |

##### Notes on selected Low findings

**L4 — export compliance.** `ITSAppUsesNonExemptEncryption=false` tells Apple
the app uses no non-exempt encryption. The app implements AES-256-GCM for
backups and TLS for transit. Whether the AES use is "non-exempt" depends on the
legal analysis (the standard exemption for authentication/DRM does not
obviously apply to user-data encryption). The safe engineering position is to
set `true`, file the annual self-classification report, and document the
analysis. This is a paperwork fix, not a code fix, but it can hold a release.

**L7 — timestamp IDs.** `millisecondsSinceEpoch` is fine for a single-user local
app, but it is used as a primary key in Firestore documents and Hive boxes. Two
tasks created in the same millisecond, a clock rollback, or a restore from a
backup with a different clock can collide. Use a UUID and keep the timestamp as
a separate field. This also makes the Cloudinary `public_id` collision (PRIV-03)
worse.

**L9 — sign-out trade-off.** The current design prioritizes data safety: if the
backup fails, the user stays signed in and the local data is kept. That is the
right default for a personal device, but wrong for a shared or lost device. Add
a secondary action: "Sign out and delete data on this device" with a warning
that unsynced changes will be lost, and require a typed confirmation.

**L14 — logging.** `debugPrint` is not stripped in release. Most calls are
guarded by `kDebugMode`, but several are not, and CI artifacts are debug-signed
or release-signed builds with logs enabled. Replace with a `Logger` that
redacts emails, UIDs, tokens and URLs, and set the level to `warn` in release.

---

## 6. Prioritized remediation roadmap

### 6.1 Sequencing principles

The order is deliberate:

1. **Contain** credentials and release channels first. Rotating a key is hours;
   rewriting history is days; a malicious release is unrecoverable.
2. **Close remotely exploitable authorization** before touching UX. A stranger
   can read another user's progress today; a prettier screen does not help.
3. **Stop data loss** before adding features. The backup overwrite is the only
   finding that destroys data without an attacker.
4. **Restore compliance** before the next store submission. Account deletion and
   Sign in with Apple are binary review gates.
5. **Build the backend** before monetization. A paywall without receipt
   verification is worse than no paywall.
6. **Improve quality** continuously, with a coverage ratchet and a performance
   budget.

Calendar estimates below assume **two mobile engineers and one backend
engineer**. A solo developer should roughly double them. Effort is in
person-days (pd) and excludes review, QA and store review latency.

### 6.2 Days 0–30 — contain, close Critical, stop data loss

| # | Workstream | Actions | IDs | Effort | Exit criteria |
|---|---|---|---|---|---|
| 1 | Credentials | Revoke the GCP key; review 90 days of audit logs; rotate Codemagic/GitHub/Cloudinary/AI secrets; make the repo private | SEC-01 | 3 pd | Key revoked; audit review signed; no live secret in any clone |
| 2 | Android signing | Confirm Play App Signing; request upload-key reset; rotate CI keystore secrets; remove the PEM | SEC-02, L1 | 3 pd + Google | Old key rejected; new AAB accepted |
| 3 | Build artifacts | Remove `NVIDIA_API_KEY` from the release build; stop uploading APKs; delete existing artifacts; rotate the key | SEC-03 | 1 pd | `strings` finds no provider key in any artifact |
| 4 | Release freeze | Disable Codemagic tag publishing until tests are gates; switch to draft + staged rollout | CICD-01 | 0.5 pd | A tag no longer ships to production |
| 5 | Partnership authz | Rewrite create/claim/accept; remove `ensurePartnership` upgrade; require verified email; add tests | AUTH-01, AUTH-02 | 5 pd | Forged partnership and invite claim denied in emulator and staging |
| 6 | Review authz | Remove the doer from the reviewer set; enforce distinct votes; add tests | AUTH-03 | 2 pd | Doer approval denied; partner approval works |
| 7 | Remaining rules | Close review spam, user enumeration, task-create injection and update whitelists | AUTH-04..08 | 6 pd | All §5.2 tests pass; no `users` list |
| 8 | Storage | Add `storage.rules`; per-user random object paths; size/type limits; deploy and verify | INFRA-01, M17 | 4 pd | Non-owner read/write/delete denied; no collisions |
| 9 | Backup safety | Add `keyId`; block overwrite when the remote key is unknown; restore-first on sign-in; ship a recovery-key export | DATA-01 (quick guard) | 5 pd | Reinstall with recovery code restores; without it, remote is untouched |
| 10 | Startup and silent failures | Guard Firebase init; start expiry on auth changes; add rules for notifications/streak actions; show errors | FUNC-01..03 | 5 pd | Offline start works; partner flag succeeds or shows a real error |
| 11 | Privacy quick wins | Add consent gates for analytics and AI; strip EXIF; disclose processors | PRIV-01, PRIV-03, PRIV-04 | 5 pd | No AI/analytics traffic before consent; no GPS in uploads |
| 12 | CI gates | Require analyze/tests/rules tests/coverage ratchet; pin actions; add CodeQL and secret scanning | CICD-01, TEST-01 (foundation), L10 | 4 pd | A failing test blocks the release |

**Total: ~44 pd.** With three engineers this fits in four working weeks if
workstreams 5–7 are staffed in parallel with 1–4.

### 6.3 Days 31–60 — backend, monetization, compliance

| # | Workstream | Actions | IDs | Effort | Exit criteria |
|---|---|---|---|---|---|
| 13 | Cloud Functions foundation | Functions project, deploy pipeline, secrets, App Check, logging/alerting | INFRA-02 (phase 1) | 8 pd | Functions deploy from CI; App Check enforced |
| 14 | Real push | `onDocumentCreated(fcm_notifications)` → FCM; token lifecycle; delivered/dead-letter states | INFRA-02, FUNC-01 | 5 pd | Partner message arrives with the app killed |
| 15 | Scheduled jobs | Expire reviews every 15 min; reminders; cleanup of orphaned media | FUNC-02, INFRA-01 | 4 pd | Expiry works without the app open |
| 16 | Purchase verification | Play/App Store receipt validation → `entitlements/{uid}`; RTDN/server notifications | MON-01 | 8 pd | Sandbox purchase writes an entitlement; refund revokes it |
| 17 | Paywall and gates | Products, paywall UI, restore, manage subscription, `PremiumGate` | MON-01 | 6 pd | A gated feature unlocks only for entitled users |
| 18 | Account deletion | In-app flow, re-auth, function that deletes Firestore/Storage/Auth, web deletion URL | COMP-01 | 5 pd | Account gone in under 2 minutes; receipt issued |
| 19 | Sign in with Apple | SDK, entitlement, button, relay-email handling, account linking | COMP-02, M13 | 3 pd | Reviewer can sign up with Apple |
| 20 | Disclosure and consent | Policy update, in-context AI notice, consent records, opt-out | PRIV-01, PRIV-04, M13 | 4 pd | Policy matches the network capture |
| 21 | Dependency upgrade | Firebase family, `intl`, `cached_network_image`, `equatable`; Renovate | M1 | 6 pd | Upgrade on a branch with all tests green |
| 22 | Test expansion | Emulator rules suite to 40+ assertions; integration tests for the core loop | TEST-01 | 8 pd | Coverage ≥ 25%; critical paths covered |

**Total: ~57 pd.** This is the phase where a solo developer typically slips;
protect the backend hire or contract.

### 6.4 Days 61–90 — quality, performance, accessibility, Medium/Low

| # | Workstream | Actions | IDs | Effort | Exit criteria |
|---|---|---|---|---|---|
| 23 | Screen decomposition | Split the 4,706-line screen; `BlocSelector`; remove `setState` storms | M2 | 8 pd | No widget file > 800 lines; frame budget met |
| 24 | Lists, images, fonts | Builder lists, cached images, bundled fonts, `const` widgets | M2, PRIV-01 | 4 pd | No jank on a low-end Android device; no runtime font fetch |
| 25 | Accessibility | Semantics labels, text-scale tests, contrast audit, touch targets | M3 | 8 pd | TalkBack/VoiceOver can complete the core loop |
| 26 | Localization | `flutter_localizations`, ARB for English/Hindi/Marathi, RTL-ready layout | M4 | 6 pd | Language switch works; no hard-coded UI strings |
| 27 | Permissions and manifest | Remove restricted permissions; Photo Picker; lock-screen cleanup | M5, L2, L3 | 3 pd | Play policy check passes; fewer scary prompts |
| 28 | Notification consolidation | One facade, channel registry, queue, preference model | M12 | 5 pd | One notification per event; channels documented |
| 29 | Offline and conflict | Outbox for reviews/notifications/invites; server timestamps; conflict policy | M15, M10 | 6 pd | Airplane-mode actions converge after reconnect |
| 30 | Observability | Global error handlers, Crashlytics non-fatals, dashboards, alerts, SLOs | M8, M16 | 4 pd | Alert fires within 5 min of a rules denial spike |
| 31 | Repo and brand | History purge, remove internal docs/build artifacts, namespace rename, environments | M9, M14, M18, L5 | 5 pd | Clone < 200 MB; `com.dailymettle.*`; dev/staging/prod split |
| 32 | Low batch | PEM, export compliance, deep links, UUIDs, `email_verified`, sign-out option, docs | L1, L4, L6–L14 | 8 pd | All Low items closed or explicitly accepted |

**Total: ~57 pd.** At this point the app is materially safer and the remaining
work is product polish, not existential risk.

### 6.5 Effort summary

| Track | Person-days | Share |
|---|---:|---:|
| Containment and credentials | 7 | 4% |
| Authorization and rules | 13 | 8% |
| Storage and media | 6 | 4% |
| Data safety and recovery | 10 | 6% |
| Backend and reliability | 22 | 14% |
| Monetization | 14 | 9% |
| Compliance | 8 | 5% |
| Privacy | 9 | 6% |
| CI/CD and testing | 12 | 8% |
| Performance, UX and accessibility | 26 | 16% |
| Medium/Low cleanup | 31 | 20% |
| **Total** | **158** | **100%** |

Category allocation is indicative: each workstream is charged to its primary
track, and a few items (release freeze, dependency upgrade, media handling)
straddle two tracks. The phase totals in §6.2–§6.4 are authoritative;
rounding explains the 0.5-day difference in phase 1.

An MVP that closes only the Critical and High **security/privacy** findings
(not monetization or performance) is approximately **40–50 person-days**. That
is the number to quote if the question is "what is the minimum to make this safe
to ship?"

### 6.6 What not to do

- **Do not `git rm` the secrets and call it done.** The blobs remain in history
  and in forks. Rotate first, then rewrite.
- **Do not rewrite `firestore.rules` from scratch.** The field-level transition
  logic is good; patch the specific predicates and add tests. A rewrite will
  regress the parts that work.
- **Do not add a paywall before server-side receipt verification.** It creates a
  new Critical finding and a refund/chargeback problem.
- **Do not disable authentication to "simplify" review.** It converts every
  High into a Critical.
- **Do not rely on client-side checks for accountability.** The doer controls
  the client; the rules and the backend are the boundary.
- **Do not ship the AI feature without a proxy.** The key is in the binary and
  the journal text is unredacted.
- **Do not run a production database from a developer machine.** Create
  dev/staging projects before the next schema change.
- **Do not treat the 197 passing tests as coverage.** They cover 10.4% of the
  code and none of the attack paths.

---

## 7. Retest and verification plan

### 7.1 Closure criteria by severity

| Severity | Closure requirement | Target |
|---|---|---|
| Critical | Fix deployed to production; regression test merged; independent retest with evidence; credential rotation confirmed | 7 days |
| High | Fix deployed; automated test or documented manual test; retest by someone other than the author | 30 days |
| Medium | Fix merged; test where feasible; accepted risk recorded if deferred | 90 days |
| Low | Fixed or explicitly accepted in the risk register | 180 days |

A finding is **not closed** because code was written. It is closed when the
test that would have caught it now fails on the old code and passes on the new
code.

### 7.2 Retest matrix

| ID | Test | Method | Pass criteria |
|---|---|---|---|
| SEC-01 | Key is revoked | `gcloud iam service-accounts keys list`; attempt `gcloud auth activate-service-account` with the old key | Old key rejected; audit log review documented |
| SEC-01 | History is clean | Fresh clone + `gitleaks detect --no-git` + `git log --all -S "private_key"` | No secret found; forks purged or acknowledged |
| SEC-02 | Upload key is rotated | Play Console → App integrity; upload an AAB signed with the new key | New certificate active; old key rejected |
| SEC-03 | No key in artifacts | `strings app-release.apk`/`.aab` and `unzip -p` scan for `nvapi`, `AIza`, `sk-` | No match |
| AUTH-01 | Forged partnership denied | Emulator: create with `status: accepted`, `partnerUid: victim` | `403` |
| AUTH-01 | One-sided upgrade denied | Call `ensurePartnership` against a pending doc as the wrong party | Status remains `pending` |
| AUTH-02 | Invite list denied | Emulator: `invite_codes` list | `403` |
| AUTH-02 | Claim without code denied | Emulator: update a pending partnership without the code | `403` |
| AUTH-03 | Self-approval denied | Emulator: doer appends own vote and finalises | `403` |
| AUTH-04 | Review spam denied | Emulator: stranger creates `partner_reviews` for a victim | `403` |
| AUTH-05 | Directory enumeration denied | Emulator: `users` list; `public_profiles` get | `403` / minimal fields only |
| AUTH-06 | Task injection denied | Emulator: create with `status: approved` or a non-partner assignee | `403` |
| AUTH-07 | Field tampering denied | Emulator: rewrite `ownerUid`/`fromUid` | `403` |
| AUTH-08 | History erasure denied | Emulator: reset an approved proof; resubmit a rejected one | `403` / history preserved |
| DATA-01 | Reinstall recovery | Android: uninstall, reinstall, sign in, enter recovery code | Full history restored |
| DATA-01 | No silent overwrite | Reinstall without the code; trigger auto-sync | Remote ciphertext unchanged; user prompted |
| PRIV-01 | No undisclosed traffic | Proxy capture of a fresh install + Tron AI tap | Traffic matches the policy; consent recorded |
| PRIV-03 | EXIF stripped | Upload a GPS-tagged fixture; `exiftool` the object | No GPS tags |
| PRIV-04 | Analytics consent | Fresh install, deny consent, capture traffic | Zero Analytics/Crashlytics calls |
| PRIV-05 | Backup exclusion | Android backup extract; inspect `*.hive` and prefs | No plaintext journal data |
| INFRA-01 | Storage authorization | Non-owner read/write/delete; 20 MB upload; `text/html` upload | All denied |
| INFRA-02 | Push delivery | Kill the app; partner sends a message | Push arrives < 10 s |
| MON-01 | Purchase and refund | Sandbox purchase; refund; restore | Entitlement written, then revoked; restore works |
| COMP-01 | Account deletion | In-app delete; inspect Firestore/Storage/Auth | No residual data; receipt shown |
| COMP-02 | Apple sign-in | Clean device, Sign in with Apple, relay email | Account created; invite flow works |
| CICD-01 | Release gate | Open a PR with a failing test; tag a release | Publish blocked; no production upload |
| TEST-01 | Coverage ratchet | CI coverage report | ≥ threshold; no decrease |
| FUNC-02 | Expiry without the app | Create an overdue task; wait for the scheduler | `expired` within 15 min |
| FUNC-03 | Offline start | Launch with the Firebase config removed | Offline screen, no crash |

### 7.3 Rules tests to add (minimum set)

The current suite has three deny assertions. Add at least the following, using the
Firebase Emulator Suite and two or three authenticated users:

1. Stranger cannot create an accepted partnership.
2. Non-owner cannot create a partnership.
3. Only the invited verified email can accept.
4. `invite_codes` cannot be listed.
5. Claim without the code is denied.
6. Claim replay with a used/expired code is denied.
7. Doer cannot approve their own proof.
8. Doer cannot reject their own proof to reset a round.
9. Doer cannot clear `approvalUids`/`rejectionUids`.
10. Stranger cannot create a `partner_review`.
11. Duplicate review for the same day is denied.
12. `users` list is denied; `public_profiles` returns no PII.
13. `email` cannot be changed to another user's address.
14. Task create rejects `status: approved`, `proofUrl`, `completedAt` and extra
    fields.
15. Task create rejects a non-partner `accountableUid`/`partnerUid`.
16. Invitation recipient cannot rewrite `fromUid`, `fromName` or
    `partnershipId`.
17. Partnership member cannot rewrite `ownerUid` or `partnerUid`.
18. Approved/completed proof reset is denied.
19. Rejected proof resubmission preserves `reviewHistory`.
20. `accountability_notifications` and `streak_actions` are partner-only and
    recipient-only.
21. Storage: non-owner write, oversized file and wrong content type are denied.
22. Entitlement client write is denied.
23. Expiry queries succeed with the deployed indexes.
24. Account deletion leaves no documents or objects (integration).

### 7.4 Evidence pack for sign-off

Request and archive the following from the engineering team:

- `gcloud iam service-accounts keys list` output for the leaked account.
- Cloud Audit Logs export (90 days) with a hash and a reviewer signature.
- Play Console screenshot of App integrity, showing App Signing and the new
  upload certificate.
- `firebase deploy --only firestore:rules,storage` output with timestamps.
- Emulator test report (JUnit/XML) for the rules suite.
- `flutter test --coverage` report and the coverage threshold check.
- Proxy capture (HAR) for a fresh install, consent denied, consent granted.
- `exiftool` output for an uploaded proof fixture.
- Sandbox purchase receipt, entitlement document and refund/revocation record.
- Account-deletion receipt and a post-deletion query showing no residual data.
- App Store Connect privacy answers and the Play Data Safety form.
- A diff of the policy against the network capture.

### 7.5 Residual risk statement

After the Critical and High fixes, the following risks remain and should be
accepted in writing by the owner:

- **Client trust.** A determined user can still manipulate their own local data;
  server-side validation covers the shared and financial surfaces, not personal
  streaks.
- **Single region, single project.** A regional Firebase outage or a project
  misconfiguration is a full outage. Multi-region and disaster recovery are out
  of scope.
- **No formal security programme.** There is no SOC 2, ISO 27001, pen-test
  cadence or vulnerability disclosure SLA. Enterprise customers will ask.
- **Third-party processors.** Firebase, Cloudinary, NVIDIA, Google and the OS
  speech provider remain in the data path. Their incidents are inherited.
- **Legal review.** The policy and store labels need counsel review; this report
  is engineering evidence, not legal advice.
- **Legacy data.** Historical backups and existing tasks may contain
  self-approved reviews or forged partnerships. A data audit is required, not
  just a rules change.

### 7.6 Sign-off

| Role | Name | Decision | Date |
|---|---|---|---|
| Engineering owner | | Accept / reject residual risk | |
| Security reviewer | | Retest complete | |
| Product owner | | Release approved | |
| Legal / privacy | | Policy approved | |

---

## 8. Appendices

### 8.1 Evidence index

| Path | Findings |
|---|---|
| `firestore.rules` | AUTH-01..08, INFRA-01 (storage gap), FUNC-01, M7 |
| `firestore.indexes.json` | FUNC-02 |
| `firebase.json` | INFRA-01, INFRA-02 |
| `lib/features/human_accountability/data/datasource/accountability_service.dart` | AUTH-01..08, DATA-01, M10, M11 |
| `lib/features/human_accountability/data/datasource/accountability_extension_service.dart` | FUNC-01 |
| `lib/features/human_accountability/data/datasource/review_expiry_service.dart` | FUNC-02 |
| `lib/features/human_accountability/data/datasource/accountability_notification_service.dart` | INFRA-02, FUNC-01 |
| `lib/core/services/cloud_sync_service.dart` | DATA-01, PRIV-02, AUTH-05, SEC-03 |
| `lib/core/services/cloud_backup_key_store.dart` | DATA-01 |
| `lib/core/services/photo_sync_service.dart` | PRIV-03, INFRA-01, M17 |
| `lib/core/services/premium_purchase_service.dart` | MON-01 |
| `lib/core/services/premium_entitlement_service.dart` | MON-01 |
| `lib/core/services/analytics_service.dart` | PRIV-04, M8 |
| `lib/core/services/fcm_service.dart` | FUNC-01, INFRA-02, AUTH-05 |
| `lib/core/services/notification_dispatch_listener.dart` | INFRA-02, M12 |
| `lib/main.dart` | FUNC-03, PRIV-04, M2 |
| `lib/screens/privacy_policy_screen.dart` | PRIV-01, COMP-01, M13 |
| `lib/screens/onboarding_screen.dart` | PRIV-01, COMP-02 |
| `lib/screens/profile_screen.dart` | COMP-01, PRIV-01, L9 |
| `lib/features/ai_accountability/data/services/tron_ai_service.dart` | PRIV-01, SEC-03 |
| `lib/features/ai_accountability/data/services/gemini_service.dart` | PRIV-01, SEC-03 |
| `lib/features/ai_accountability/presentation/screens/ai_companion_screen.dart` | Dead code, PRIV-01 |
| `lib/widgets/voice_input.dart` | PRIV-01 |
| `lib/repositories/regular_task_repository.dart` | M11 |
| `lib/repositories/database_repository.dart` | PRIV-05 |
| `android/app/src/main/AndroidManifest.xml` | M5, PRIV-05, L2 |
| `android/app/build.gradle` | L5, M18 |
| `ios/Runner/Info.plist` | COMP-02, L3, L4 |
| `ios/Runner/PrivacyInfo.xcprivacy` | M6 |
| `codemagic.yaml` | CICD-01 |
| `.github/workflows/dart.yml` | SEC-03, CICD-01 |
| `rules-tests/firestore_rules_smoke.js` | TEST-01 |
| `pubspec.lock` | M1 |
| Git history (`b45e07d0`, `f3c8a896`) | SEC-01, SEC-02, M9 |

### 8.2 Reproducible commands

```bash
# Baseline
flutter --version
flutter analyze
flutter test --reporter=expanded
flutter test --coverage
python3 - <<'PY'
lf = lh = 0
for line in open('coverage/lcov.info'):
    if line.startswith('LF:'): lf += int(line[3:])
    elif line.startswith('LH:'): lh += int(line[3:])
print(f'{lh}/{lf} = {100*lh/lf:.2f}%')
PY

# Structure and code smells
find lib -name '*.dart' | wc -l
find lib -name '*.dart' -print0 | xargs -0 cat | wc -l
find lib -name '*.dart' -exec wc -l {} + | sort -rn | head -15
grep -rn "catch (_)" lib --include='*.dart' | wc -l
grep -rn "\bdynamic\b" lib --include='*.dart' | wc -l
grep -rn "Semantics(" lib --include='*.dart' | wc -l
grep -rn "textScaleFactor\|textScaler" lib --include='*.dart' | wc -l

# Secrets and history
git rev-list --count HEAD
git count-objects -vH
du -sh .git
git log --all --oneline -S 'PRIVATE KEY' -- '*.json' '*.txt'
git log --all --oneline -- '*keystore*' '*service-account*'
git ls-files | grep -Ei 'keystore|\.jks|\.pem|service-account|key\.properties'

# Dependencies
flutter pub outdated

# Rules tests (requires Java and the emulator)
firebase emulators:exec --only=auth,firestore \
  --project dailymettle-rules-test \
  "cd rules-tests && npm test"

# APK secret scan (after a build)
strings build/app/outputs/flutter-apk/app-release.apk \
  | grep -E 'nvapi|AIza|sk-|BEGIN PRIVATE KEY' || echo 'clean'
```

### 8.3 Data-flow summary

```
User device
  ├─ Hive (plaintext) ...................... challenge, journal, tasks, completions
  ├─ SharedPreferences .................... cached email, consent, sync time
  ├─ Secure storage ....................... random backup key (no recovery)
  ├─ Firebase Auth ........................ Google / (missing) Apple
  ├─ Firestore
  │   ├─ users/{uid} ...................... email, name, photo, FCM tokens (world-readable)
  │   ├─ user_data/{uid} .................. AES-GCM backup (key device-bound)
  │   ├─ partnerships/{id}/messages ....... partner chat (membership from doc)
  │   ├─ accountability_tasks/{id} ........ task + proof + votes
  │   ├─ public_progress/{uid}(/days) ..... partner-visible progress
  │   ├─ partner_reviews/{id} ............. review history (any author)
  │   ├─ invitations, invite_codes ........ invite flow
  │   ├─ entitlements/{uid} ............... server-only; no writer
  │   └─ fcm_notifications ................ client-written; no sender
  ├─ Firebase Storage ..................... proofs/avatars; no rules in repo
  ├─ Cloudinary ........................... proofs/avatars; EXIF retained; stable IDs
  ├─ NVIDIA API ........................... journal text for "Tron AI"
  ├─ Gemini API ........................... AI coach prompts (unreachable screen)
  ├─ Google Fonts ......................... runtime font fetch
  └─ OS speech recognizer ................. dictation audio (platform-dependent)
```

### 8.4 Glossary

| Term | Meaning |
|---|---|
| **Accountable doer** | The user who must complete a task and submit proof (`accountableUid`). |
| **Assigner / reviewer** | The partner who created the task and reviews the proof (`assignedByUid`/`partnerUid`). |
| **AEAD** | Authenticated encryption with associated data; here AES-256-GCM. |
| **App Check** | Firebase attestation that requests come from a genuine app instance. |
| **Composite index** | Firestore index required for queries with multiple filters/orderings. |
| **Entitlement** | A server-written record that a user has paid for a feature. |
| **EXIF** | Image metadata, including GPS coordinates and device model. |
| **Rules** | Firestore/Storage server-side authorization expressions. |
| **RTDN** | Google Play Real-Time Developer Notifications (subscription lifecycle). |
| **Staged rollout** | Releasing to a percentage of users before 100%. |
| **TOCTOU** | Time-of-check/time-of-use race; relevant to vote finalisation. |

### 8.5 Handling and distribution

- This report is **CONFIDENTIAL**. Do not commit it to the public repository,
  paste it into an issue, or attach it to a CI artifact.
- Share only with the owner, the remediation leads and legal counsel under a
  need-to-know basis.
- Store the report in a private drive with access logging. If it must live in
  the repository, add it to `.gitignore` and keep it in a private fork.
- The evidence pack in §7.4 may contain console screenshots and log excerpts;
  treat it as confidential too.
- After remediation, produce a short **closure memo** that maps each finding to
  its fix commit, test and evidence. Do not re-use this document as a
  marketing asset; it contains exploit paths.

---

### Closing assessment

DailyMettle is a real product with a solid design foundation and several
controls that are better than the category average. It is also, today, a
product that can leak a stranger into a user's accountability circle, let a user
approve their own proof, lose a 75-day history on reinstall, and ship a live
cloud key from a public repository. Those are not polish issues; they are the
difference between a product that can be trusted with someone's discipline
journey and one that cannot.

The fastest path to a shippable state is not a rewrite. It is: **rotate the
credentials, patch the eight authorization rules, add the missing index and a
`storage.rules` file, stop the backup overwrite, put a consent gate in front of
analytics and AI, and add the tests that would have caught each one.** That is
the **~44 person-day** first phase: about four working weeks for the assumed
three-person team, or six to eight weeks for two engineers once review, QA and
store latency are included. The backend and monetization work is the next
~57 person-days; the quality, accessibility and cleanup work is the ~57 after
that.

Until the Critical items are closed, the appropriate release decision is **do
not ship to production**.

---

*End of report. Prepared 25 October 2026 against commit
`575376cfc2a14aa7cd4f89723690ff88b5673c17`. No application source file was
modified during this review.*
