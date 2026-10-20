# DailyMettle Release Readiness

This document separates work that is implemented in the repository from work
that requires store, backend, legal, or physical-device access.

## Implemented in the repository

- Firestore security-rule smoke tests under `rules-tests/`.
- Account-scoped entitlement read rules for `entitlements/{uid}`.
- Privacy-safe analytics for onboarding, app-open retention buckets, partner
  invitations, and premium paywall/purchase/restore events.
- Platform secure-storage key foundation for new cloud backups.
- Signed Cloudinary upload client contract; unsigned uploads fail closed.
- Android cleartext traffic disabled.
- iOS TestFlight Codemagic workflow skeleton.
- Navigation-shell widget coverage.
- In-app branding disclaimer stating that DailyMettle is independent.

## Required backend work

### Premium entitlement verification

The app must not grant premium from a client purchase callback alone. Add a
trusted backend endpoint or Cloud Function that:

1. Receives a Google Play or App Store server notification / receipt.
2. Verifies the purchase with the store.
3. Writes only the verified result to `entitlements/{uid}`.
4. Stores `status`, `productId`, `source`, `expiresAt`, and a server update time.
5. Handles renewals, refunds, cancellations, grace periods, and revoked access.

Client reads are intentionally server-only and fail closed when unavailable.

### Cloud backup recovery

Platform secure storage may be removed on uninstall. Before advertising restore
after reinstall, add an explicit recovery-key flow:

- Generate a one-time recovery code from the random backup key.
- Require the user to confirm they saved it.
- Store only a verifier or wrapped key metadata server-side, never the raw key.
- Allow import after reinstall with rate limits and clear destructive warnings.
- Test wrong-code, expired-code, and account-mismatch behavior.

### Cloudinary signer

Deploy a trusted HTTPS signer endpoint. It should:

- Authenticate the Firebase user.
- Authorize the task/accountability relationship.
- Generate a short-lived Cloudinary signature.
- Restrict `folder`, `public_id`, timestamp, and upload size/type.
- Never return or log the Cloudinary API secret.

## Store declarations to complete

### Apple App Store privacy

Declare the actual current behavior:

- Email/name/user ID: authentication and app functionality.
- Photos: user-generated proof content and app functionality.
- Product interaction: Firebase Analytics.
- Crash/performance data: Firebase Crashlytics.
- No cross-company tracking.

### Google Play Data safety

Use the same declarations as Apple. Do not retain the old “no data collected”
answer while Firebase Auth, Analytics, Crashlytics, cloud backup, and photo
uploads are enabled.

### Privacy URL

The hosted privacy policy must match `lib/screens/privacy_policy_screen.dart`,
including secure-storage backup keys, Cloudinary proof photos, analytics
categories, retention, deletion, and partner sharing.

## Trademark and branding checklist

DailyMettle is positioned as an independent app inspired by the public 75 Hard
concept. Before public promotion:

- Run a trademark search in every launch territory.
- Confirm whether “75 Hard” may appear in the app name, subtitle, keywords,
  screenshots, and promotional copy.
- Keep the non-affiliation disclaimer in the app and store metadata where
  required.
- Do not use another party’s logo, screenshots, or official claims.
- Have counsel review the final store listing before paid acquisition.

## Physical-device verification matrix

These checks cannot be proven by local unit tests alone:

| Area | Android | iOS |
|---|---|---|
| Local reminders while app is terminated | Android 13+ and Samsung device | iOS 16+ device |
| Notification permission denial/re-enable | Required | Required |
| Exact alarm / battery optimization behavior | Required | Not applicable |
| Camera/gallery proof upload | Required | Required |
| Google Sign-In | Required | Required |
| Secure-storage backup key persistence | Reboot and reinstall test | Reboot and reinstall test |
| Offline task completion and reconnect sync | Required | Required |
| Time-zone and daylight-saving transition | Required | Required |
| Signed Cloudinary upload | Test signer + real account | Test signer + real account |
| TestFlight / Play release install | Required | Required |

Record device model, OS version, app build, expected result, actual result, and
evidence for every row before starting paid promotion.
