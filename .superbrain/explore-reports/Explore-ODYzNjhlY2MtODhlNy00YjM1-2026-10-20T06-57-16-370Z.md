# Sub-Agent Report Trace

- **Agent**: Explore
- **Session**: /ODYzNjhlY2MtODhlNy00YjM1LTk2MDctZmVkZWM5NTU1NGRl
- **Raw report chars**: 6658
- **Compressed (delivered to parent) chars**: 7642
- **Distinct files mentioned in raw report**: 1

## Spawn Prompt (what the parent asked)

Give an overview of this Dart/Flutter project at /Users/kunalgharate/seventy_five_hard_tracker: what the app does, main entry points (main.dart, routes), and how the code is structured (lib/ layout, state management, data models, storage, tests). Be concrete with file paths.

## Raw Report (what the sub-agent produced, pre-compression)

## Exploration Report

**Confidence**: HIGH — entry point, routes, feature layout, dependencies, and tests all read directly.
**Files Examined**: pubspec.yaml, lib/main.dart (key ranges), lib/ tree (3 levels), lib/features/* subfolders, test/ listing.

### What the app is
`seventy_five_hard_tracker` ("Daily Mettle", v1.0.8+8, pubspec.yaml) — an offline-first 75 Hard / mental-toughness habit tracker: daily challenge tasks, streaks, photo proof, a daily journal, "regular habits" (independent of the challenge), AI and human accountability partners with review/approve/reject flows, a discipline score, push notifications, and premium IAP. Firebase (Auth, Firestore, Messaging, Analytics, Crashlytics) backs cloud sync; Hive is the local database. Platform targets include Android/iOS/web/windows (platform dirs present).

### Entry points & routes
- **`lib/main.dart`** (942 lines) — the single entry point. `main()` (line 66): preserves the native splash, initializes Hive + registers 5 adapters (ChallengeSession, Challenge, DailyProgress, RegularTaskCompletion, RegularTask), runs repositories' `init()` + a legacy-task migration (`RegularTaskMigrationService`), initializes notifications and Firebase/GoogleSignIn (all failure-tolerant — app works offline), wires a connectivity "internet restored" hook (`_onInternetRestored`, line 156) that flushes an offline outbox and cloud-syncs, and starts `ReviewExpiryService` if signed in.
- **Routes** (main.dart:268–276): `/login` → LoginScreen, `/onboarding` → OnboardingScreen, `/home` → MainNavigationScreen, `/history` → HistoryScreen, `/settings` → SettingsScreen, `/privacy`, `/terms`. `home:` is `InitialScreen` (defined later in main.dart) which decides login/onboarding/home. Named global `navigatorKey` (line 51) + `appNavigationReady` flag let FCM notification taps navigate from outside the widget tree.
- Root widget provides `ChallengeBloc`, `RegularTaskBloc`, `AccountabilityBloc`; a `BlocListener` on `AccountabilityBloc` (main.dart:218–263) converts partner review outcomes (`StreakImpacted` rejected → session reset; `RegularTaskOutcome` rejected → task un-completed) into `ChallengeBloc` `ReviewOutcomeObserved` events with exactly-once semantics.
- Theme is built in `_buildTheme` (main.dart:281) — Material 3, light/dark, Google Fonts (Manrope/DM Sans), brand `AppColors` (orange #FF7918) aligned to Figma tokens in `lib/core/theme/figma_tokens.dart`.

### lib/ structure
- **`lib/core/`** — cross-cutting: `constants/` (api_constants, app_constants), `services/` (~16 files: cloud_sync_service, offline_task_outbox, connectivity_service, fcm_service, notification_*, photo_sync_service, premium_entitlement/purchase, analytics, cloud_backup_key_store, cloudinary_upload_signer, data_ownership), `theme/` (figma_tokens, figma_widgets), `utils/`.
- **`lib/features/`** — feature-first with data/domain/presentation layers (not all layers populated everywhere):
  - `challenges/` — data/models (challenge, daily_progress, challenge_session), presentation/bloc (challenge_bloc/event/state).
  - `regular_tasks/` — data/models (regular_task, regular_task_completion), presentation/bloc (regular_task_bloc).
  - `human_accountability/` — the largest feature: data/datasource (accountability_service, review_expiry_service, extension/notification services), data/models (invitation, message, partner, partner_review, streak_action, app_user…), domain/services/review_scoring_engine.dart, presentation/bloc + pages (accountability_screen, chat, tasks, partner_progress, streak_escalation, weekly_summary) + widgets.
  - `ai_accountability/`, `discipline_score/` (barrel `discipline_score.dart`; data/repositories), same layering.
- **`lib/repositories/`** — `database_repository.dart` (Hive-backed challenge store, also does Firestore cloud sync) and `regular_task_repository.dart`.
- **`lib/models/`** — shared models: collaborator.dart, quote.dart.
- **`lib/screens/`** — top-level screens: home, main_navigation (bottom-nav shell), history, insights, journal, journal_timeline, login, onboarding, profile, regular_tasks, settings, privacy_policy, terms_of_service.
- **`lib/services/`** — app-level services: smart_notification_service, api_quote_service, quotes_service, task_templates, regular_task_migration_service, simple_background_check_service, challenge_icon_service.
- **`lib/widgets/`** — shared UI: task cards/sheets (create_task_sheet, task_detail_sheet, challenge_task_sheet, photo_proof_sheet, proof_review_dialog, reminder_bottom_sheet), progress_stats, discipline_heatmap, water_reminder_widget, voice_input, plus a `regular_tasks/` subfolder (add/edit sheets).

### State management
flutter_bloc (v8) + equatable: three main BLoCs — `ChallengeBloc`, `RegularTaskBloc`, `AccountabilityBloc` — provided at root in main.dart and cross-linked via BlocListener for review outcomes. A `bloc_independence_test.dart` exists asserting the blocs don't entangle.

### Storage
- **Local**: Hive (`hive`/`hive_flutter` + hive_generator/build_runner) — adapters registered in main.dart:74–78; repositories open Hive boxes. `shared_preferences` and `flutter_secure_storage` for settings/keys.
- **Cloud**: Cloud Firestore via repositories + `core/services/cloud_sync_service.dart` and `photo_sync_service.dart` (Cloudinary signed uploads via `cloudinary_upload_signer.dart`); encrypted backup keys via `encrypt`/`pointycastle`. Offline writes queue in `core/services/offline_task_outbox.dart` and flush on reconnect (main.dart `_onInternetRestored`). Firestore security rules in `firestore.rules` + `firestore.indexes.json`.

### Tests (test/, 26 Dart files)
Unit/widget tests mirroring features: streak_statistics, review_scoring_engine, accountability_day_scope, repository_data_isolation, cloud/cloudinary data-safety, challenge/regular_task serialization, notification_preferences, navigation_widget, widget_test, plus bug-regression/preservation suites (bug_regression_test, qa_bugfix_test, ios_splash_*, compact_reminder_*). Additionally a Node-based `rules-tests/` directory (firestore_rules_smoke.js) for Firestore rules smoke testing.

### Recommendation
No gaps to fix requested; for future work: new features should follow the existing `features/<name>/{data,domain,presentation}` pattern; note `lib/core/services/` vs `lib/services/` is a legacy split (core = infra, top-level services = app helpers).

### Not covered / Uncertain
I did not read the bodies of the repositories or blocs (structure and interactions inferred from imports/main.dart wiring and directory listings); `InitialScreen`'s decision logic sits in the unread later portion of main.dart (~lines 420–942).

## Compressed Report (what the parent actually received)

<HYDRATION_REPORT>
## Exploration Report

**Confidence**: HIGH — entry point, routes, feature layout, dependencies, and tests all read directly.
**Files Examined**: pubspec.yaml, lib/main.dart (key ranges), lib/ tree (3 levels), lib/features/* subfolders, test/ listing.

### What the app is
`seventy_five_hard_tracker` ("Daily Mettle", v1.0.8+8, pubspec.yaml) — an offline-first 75 Hard / mental-toughness habit tracker: daily challenge tasks, streaks, photo proof, a daily journal, "regular habits" (independent of the challenge), AI and human accountability partners with review/approve/reject flows, a discipline score, push notifications, and premium IAP. Firebase (Auth, Firestore, Messaging, Analytics, Crashlytics) backs cloud sync; Hive is the local database. Platform targets include Android/iOS/web/windows (platform dirs present).

### Entry points & routes
- **`lib/main.dart`** (942 lines) — the single entry point. `main()` (line 66): preserves the native splash, initializes Hive + registers 5 adapters (ChallengeSession, Challenge, DailyProgress, RegularTaskCompletion, RegularTask), runs repositories' `init()` + a legacy-task migration (`RegularTaskMigrationService`), initializes notifications and Firebase/GoogleSignIn (all failure-tolerant — app works offline), wires a connectivity "internet restored" hook (`_onInternetRestored`, line 156) that flushes an offline outbox and cloud-syncs, and starts `ReviewExpiryService` if signed in.
- **Routes** (main.dart:268–276): `/login` → LoginScreen, `/onboarding` → OnboardingScreen, `/home` → MainNavigationScreen, `/history` → HistoryScreen, `/settings` → SettingsScreen, `/privacy`, `/terms`. `home:` is `InitialScreen` (defined later in main.dart) which decides login/onboarding/home. Named global `navigatorKey` (line 51) + `appNavigationReady` flag let FCM notification taps navigate from outside the widget tree.
- Root widget provides `ChallengeBloc`, `RegularTaskBloc`, `AccountabilityBloc`; a `BlocListener` on `AccountabilityBloc` (main.dart:218–263) converts partner review outcomes (`StreakImpacted` rejected → session reset; `RegularTaskOutcome` rejected → task un-completed) into `ChallengeBloc` `ReviewOutcomeObserved` events with exactly-once semantics.
- Theme is built in `_buildTheme` (main.dart:281) — Material 3, light/dark, Google Fonts (Manrope/DM Sans), brand `AppColors` (orange #FF7918) aligned to Figma tokens in `lib/core/theme/figma_tokens.dart`.

### lib/ structure
- **`lib/core/`** — cross-cutting: `constants/` (api_constants, app_constants), `services/` (~16 files: cloud_sync_service, offline_task_outbox, connectivity_service, fcm_service, notification_*, photo_sync_service, premium_entitlement/purchase, analytics, cloud_backup_key_store, cloudinary_upload_signer, data_ownership), `theme/` (figma_tokens, figma_widgets), `utils/`.
- **`lib/features/`** — feature-first with data/domain/presentation layers (not all layers populated everywhere):
  - `challenges/` — data/models (challenge, daily_progress, challenge_session), presentation/bloc (challenge_bloc/event/state).
  - `regular_tasks/` — data/models (regular_task, regular_task_completion), presentation/bloc (regular_task_bloc).
  - `human_accountability/` — the largest feature: data/datasource (accountability_service, review_expiry_service, extension/notification services), data/models (invitation, message, partner, partner_review, streak_action, app_user…), domain/services/review_scoring_engine.dart, presentation/bloc + pages (accountability_screen, chat, tasks, partner_progress, streak_escalation, weekly_summary) + widgets.
  - `ai_accountability/`, `discipline_score/` (barrel `discipline_score.dart`; data/repositories), same layering.
- **`lib/repositories/`** — `database_repository.dart` (Hive-backed challenge store, also does Firestore cloud sync) and `regular_task_repository.dart`.
- **`lib/models/`** — shared models: collaborator.dart, quote.dart.
- **`lib/screens/`** — top-level screens: home, main_navigation (bottom-nav shell), history, insights, journal, journal_timeline, login, onboarding, profile, regular_tasks, settings, privacy_policy, terms_of_service.
- **`lib/services/`** — app-level services: smart_notification_service, api_quote_service, quotes_service, task_templates, regular_task_migration_service, simple_background_check_service, challenge_icon_service.
- **`lib/widgets/`** — shared UI: task cards/sheets (create_task_sheet, task_detail_sheet, challenge_task_sheet, photo_proof_sheet, proof_review_dialog, reminder_bottom_sheet), progress_stats, discipline_heatmap, water_reminder_widget, voice_input, plus a `regular_tasks/` subfolder (add/edit sheets).

### State management
flutter_bloc (v8) + equatable: three main BLoCs — `ChallengeBloc`, `RegularTaskBloc`, `AccountabilityBloc` — provided at root in main.dart and cross-linked via BlocListener for review outcomes. A `bloc_independence_test.dart` exists asserting the blocs don't entangle.

### Storage
- **Local**: Hive (`hive`/`hive_flutter` + hive_generator/build_runner) — adapters registered in main.dart:74–78; repositories open Hive boxes. `shared_preferences` and `flutter_secure_storage` for settings/keys.
- **Cloud**: Cloud Firestore via repositories + `core/services/cloud_sync_service.dart` and `photo_sync_service.dart` (Cloudinary signed uploads via `cloudinary_upload_signer.dart`); encrypted backup keys via `encrypt`/`pointycastle`. Offline writes queue in `core/services/offline_task_outbox.dart` and flush on reconnect (main.dart `_onInternetRestored`). Firestore security rules in `firestore.rules` + `firestore.indexes.json`.

### Tests (test/, 26 Dart files)
Unit/widget tests mirroring features: streak_statistics, review_scoring_engine, accountability_day_scope, repository_data_isolation, cloud/cloudinary data-safety, challenge/regular_task serialization, notification_preferences, navigation_widget, widget_test, plus bug-regression/preservation suites (bug_regression_test, qa_bugfix_test, ios_splash_*, compact_reminder_*). Additionally a Node-based `rules-tests/` directory (firestore_rules_smoke.js) for Firestore rules smoke testing.

### Recommendation
No gaps to fix requested; for future work: new features should follow the existing `features/<name>/{data,domain,presentation}` pattern; note `lib/core/services/` vs `lib/services/` is a legacy split (core = infra, top-level services = app helpers).

### Not covered / Uncertain
I did not read the bodies of the repositories or blocs (structure and interactions inferred from imports/main.dart wiring and directory listings); `InitialScreen`'s decision logic sits in the unread later portion of main.dart (~lines 420–942).

---
[Exploration: Explore (auto) | 106199ms | 7 turns | 11 tools | 44814in/1940out tokens | status: completed]
</HYDRATION_REPORT>

CRITICAL: Write your final answer DIRECTLY from the findings above. Do NOT re-page files the sub-agent already covered (no whole-file skeleton/symbols/read on those paths). To confirm one specific cited line, a narrow sb_read_code range (<=40 lines) is allowed. Files the report did NOT cover stay fully readable — locate them with superbrain_listDirectory / superbrain_search instead of guessing.

---
**Explore coverage (harness):** opened 2 file(s) over 7 turn(s). 1 ranked search(es) returned zero hits (zero hits is not proof of absence); listed but not opened: ., lib/features, lib/features/challenges/data, lib/features/discipline_score/data, lib/features/human_accountability. Treat any subsystem this report does not explicitly cover as UNVERIFIED, not absent - confirm with a direct read or say what you could not verify.
