import 'package:seventy_five_hard_tracker/core/services/analytics_service.dart';
import 'package:seventy_five_hard_tracker/core/services/connectivity_service.dart';
import 'package:seventy_five_hard_tracker/services/api_quote_service.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/review_expiry_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'models/quote.dart';
import 'repositories/database_repository.dart';
import 'repositories/regular_task_repository.dart';
import 'features/challenges/presentation/bloc/challenge_bloc.dart';
import 'features/challenges/presentation/bloc/challenge_event.dart';
import 'features/challenges/data/models/challenge.dart';
import 'features/challenges/data/models/daily_progress.dart';
import 'features/challenges/data/models/challenge_session.dart';
import 'features/regular_tasks/data/models/regular_task.dart';
import 'features/regular_tasks/data/models/regular_task_completion.dart';
import 'features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'features/human_accountability/presentation/bloc/accountability_state.dart';
import 'features/discipline_score/discipline_score.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/services/offline_task_outbox.dart';
import 'core/services/data_ownership.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/figma_tokens.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Global navigator key — lets notification taps navigate from outside the
/// widget tree (see FcmService).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// True once the splash screen has pushed /home. Notification payloads
/// queued before that wait for [FcmService.flushPendingNavigation] so the
/// splash hand-off cannot replace the screen a cold-start tap asked for.
bool appNavigationReady = false;

/// App-wide theme colors — single source of truth.
/// Aligned to the Figma "Design Daily Metal App" palette.
class AppColors {
  static const primary = Color(0xFFFF7918); // Figma --orange
  static const secondary = Color(0xFFFF5449); // Figma --coral
  static const accent = Color(0xFFED356B); // Figma --pink
}

void main() async {
  // Preserve the native splash screen until we explicitly remove it.
  // This prevents the white/blank flash between native splash and Flutter UI.
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ── OFFLINE-FIRST: Core local services init first ──
  await Hive.initFlutter();
  Hive.registerAdapter(ChallengeSessionAdapter());
  Hive.registerAdapter(ChallengeAdapter());
  Hive.registerAdapter(DailyProgressAdapter());
  Hive.registerAdapter(RegularTaskCompletionAdapter());
  Hive.registerAdapter(RegularTaskAdapter());

  final smartNotifications = SmartNotificationService();
  try {
    await smartNotifications.initialize();
  } catch (e) {
    if (kDebugMode) print('Notification init failed: $e');
  }

  // ── Internet-aware Firebase init ──
  // Initialize Firebase before runApp so GoogleSignIn and
  // AccountabilityService._isReady work when the user taps Sign In.
  final connectivity = ConnectivityService();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize Google Sign-In (required before any authenticate() call)
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '496007025535-vcfvp99s1kva06b042i74rnb8cg6fhrc.apps.googleusercontent.com',
    );
    await connectivity.initFirebase();
  } catch (e) {
    if (kDebugMode) print('Firebase init failed (app works offline): $e');
  }
  // Listener starts only after the reconnect callback is installed.

  // Reconnect hook: when the device regains internet, push local changes to
  // the cloud (BUG-06) and flush any tasks queued while offline.
  connectivity.onInternetRestoredWithResult = _onInternetRestored;
  connectivity.startListening(); // retries when internet comes back

  // ── Start review expiry timer if user is signed in ──
  // Checks for overdue partner reviews every 5 minutes and on app start.
  if (FirebaseAuth.instance.currentUser != null) {
    ReviewExpiryService().startPeriodicCheck();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  Animate.restartOnHotReload = true;

  runApp(MyApp(
      smartNotifications: smartNotifications, connectivity: connectivity));
}

/// Runs once per none→internet transition (set as
/// [ConnectivityService.onInternetRestored]).
///
/// Pushes local changes to the cloud (autoSync — the missing half of the
/// old "Auto-syncs when online" promise) and flushes tasks queued for
/// creation while the device was offline.
Future<bool> _onInternetRestored() async {
  final db = DatabaseRepository();
  final taskRepo = RegularTaskRepository();
  await db.init();
  await taskRepo.init();

  final syncSucceeded =
      await CloudSyncService().autoSyncWithResult(db, taskRepo);
  final outboxResult = await OfflineTaskOutbox.instance.flushWithResult();
  return syncSucceeded && outboxResult.succeeded;
}

class MyApp extends StatelessWidget {
  final SmartNotificationService smartNotifications;
  final ConnectivityService connectivity;

  const MyApp(
      {super.key,
      required this.smartNotifications,
      required this.connectivity});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ChallengeBloc(
            repository: DatabaseRepository(),
            smartNotifications: smartNotifications,
          )..add(LoadChallengeData()),
        ),
        BlocProvider(
          create: (context) => RegularTaskBloc(
            repository: RegularTaskRepository(),
            notifications: smartNotifications,
          )..add(LoadRegularTasks()),
        ),
        BlocProvider(
          create: (context) => AccountabilityBloc(
            repository: DatabaseRepository(),
          ),
        ),
        BlocProvider(
          create: (context) => DisciplineScoreBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Daily mettle',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        // In-process bridge: a partner's review reaction carries task
        // ownership metadata. ChallengeBloc refuses to mutate a reviewer's
        // session; owner devices also observe persisted decisions through the
        // assignedByMe task stream in HomeScreen.
        //
        // A partner's review reaction drives ChallengeBloc —
        // StreakImpacted (hard tasks) resets the session on 'rejected',
        // RegularTaskOutcome (regular tasks) un-completes the task for today.
        // Exactly-once consumption is enforced in ChallengeBloc itself.
        builder: (context, child) =>
            BlocListener<AccountabilityBloc, AccountabilityState>(
          listener: (context, state) {
            if (state is StreakImpacted) {
              final outcome = state is StreakReviewOutcome ? state : null;
              if (state.reason == 'rejected') {
                context.read<ChallengeBloc>().add(ReviewOutcomeObserved(
                      taskId: outcome?.taskId,
                      challengeId: outcome?.challengeId,
                      taskOwnerUid: outcome?.taskOwnerUid,
                      taskType: outcome?.taskType ?? 'hard',
                      outcome: 'rejected',
                      newStreakDay: state.newStreakDay,
                      reviewedAt: outcome?.reviewedAt,
                      taskAssignedAt: outcome?.taskAssignedAt,
                    ));
              } else if (state.reason == 'approved') {
                // Approved needs no session mutation — register the outcome
                // so exactly-once ingestion stays symmetric.
                context.read<ChallengeBloc>().add(ReviewOutcomeObserved(
                      taskId: outcome?.taskId,
                      challengeId: outcome?.challengeId,
                      taskOwnerUid: outcome?.taskOwnerUid,
                      taskType: outcome?.taskType ?? 'hard',
                      outcome: 'approved',
                      newStreakDay: state.newStreakDay,
                      reviewedAt: outcome?.reviewedAt,
                      taskAssignedAt: outcome?.taskAssignedAt,
                    ));
              }
              // 'expired' is emitted via TasksExpired elsewhere — not consumed.
            } else if (state is RegularTaskOutcome &&
                state.outcome == 'rejected') {
              context.read<ChallengeBloc>().add(ReviewOutcomeObserved(
                    taskId: state.taskId,
                    challengeId: state.challengeId,
                    taskOwnerUid: state.taskOwnerUid,
                    reviewedAt: state.reviewedAt,
                    taskAssignedAt: state.taskAssignedAt,
                    taskType: 'regular',
                    outcome: 'rejected',
                  ));
            }
          },
          child: child,
        ),
        home: const InitialScreen(),
        navigatorObservers: connectivity.isFirebaseReady
            ? [AnalyticsService().getObserver()]
            : [],
        routes: {
          '/login': (context) => const LoginScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const MainNavigationScreen(),
          '/history': (context) => const HistoryScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/terms': (context) => const TermsOfServiceScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : Colors.black87;
    final onSurfaceMuted = isDark ? Colors.white70 : Colors.black54;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1A1618) : const Color(0xFFFAF7F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(
        // Warm-neutral surfaces that pair with the brand palette and give
        // clear contrast against white text in dark mode.
        surface: isDark ? const Color(0xFF1A1618) : Colors.white,
        onSurface: onSurface,
      ),
      cardColor: isDark ? const Color(0xFF262123) : Colors.white,
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF262123) : Colors.white,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaTokens.rCard),
          side: BorderSide(
            color: isDark ? const Color(0xFF3A3335) : const Color(0xFFEEE9E7),
          ),
        ),
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.manrope(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: onSurface,
            letterSpacing: -0.5),
        displayMedium: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: onSurface,
            letterSpacing: -0.25),
        displaySmall: GoogleFonts.manrope(
            fontSize: 24, fontWeight: FontWeight.w600, color: onSurface),
        headlineLarge: GoogleFonts.manrope(
            fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
        headlineMedium: GoogleFonts.manrope(
            fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
        headlineSmall: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
        titleLarge: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onSurface,
            letterSpacing: 0.15),
        titleMedium: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: onSurface,
            letterSpacing: 0.1),
        titleSmall: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: onSurface,
            letterSpacing: 0.1),
        bodyLarge: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: onSurface,
            letterSpacing: 0.5),
        bodyMedium: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: onSurface,
            letterSpacing: 0.25),
        bodySmall: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: onSurfaceMuted,
            letterSpacing: 0.4),
        labelLarge: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: onSurface,
            letterSpacing: 0.1),
        labelMedium: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: onSurface,
            letterSpacing: 0.5),
        labelSmall: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: onSurfaceMuted,
            letterSpacing: 0.5),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4, shape: CircleBorder()),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          thickness: 1,
          space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ── Daily Quote Splash Screen ────────────────────────────────────────────────

enum _QuoteState { loading, loaded, error }

/// Total time the splash is visible before navigating.
const Duration _kSplashDuration = Duration(seconds: 3);

/// Progress bar fills over the same duration.
const Duration _kProgressDuration = Duration(seconds: 2);

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with TickerProviderStateMixin {
  _QuoteState _quoteState = _QuoteState.loading;
  Quote? _quote;

  // Logo: elastic scale-in
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;

  // Quote card: fade + slide up
  late final AnimationController _quoteCtrl;
  late final Animation<double> _quoteFade;
  late final Animation<Offset> _quoteSlide;

  // Progress bar: linear fill over _kProgressDuration
  late final AnimationController _progressCtrl;

  // Page-exit: fade to white before pushing /home
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);

    _quoteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _quoteFade = CurvedAnimation(parent: _quoteCtrl, curve: Curves.easeIn);
    _quoteSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _quoteCtrl, curve: Curves.easeOutCubic));

    _progressCtrl = AnimationController(
      vsync: this,
      duration: _kProgressDuration,
    );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _logoCtrl.forward();
    _progressCtrl.forward();
    _initApp();

    // Remove the native splash as soon as our custom splash is drawn.
    // This prevents the double-splash effect.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _quoteCtrl.dispose();
    _progressCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // Fetch quote in background (non-blocking)
    unawaited(_fetchQuote());

    // Capture blocs/repos before any await to avoid using BuildContext across
    // an async gap (the InitialScreen can be disposed during startup awaits).
    final bloc = context.read<ChallengeBloc>();
    final taskRepo = context.read<RegularTaskBloc>().repository;

    // Request notification permission WITHOUT blocking the splash flow.
    // Awaiting this would freeze the splash behind the system permission
    // dialog until the user responds; instead we fire-and-forget so DB init
    // and navigation proceed normally.
    unawaited(
        SmartNotificationService().requestPermissions().catchError((_) {}));

    await bloc.repository.init();
    await taskRepo.init();

    // Replay Squad-task creations queued while offline (BUG-03). An
    // online-start never fires the reconnect hook, so run it here too.
    if (await ConnectivityService().hasInternet()) {
      unawaited(OfflineTaskOutbox.instance.flush().catchError((_) => 0));
    }

    // If user is signed in but has NO local data, restore from cloud.
    User? currentUser;
    try {
      currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      currentUser = null;
    }
    if (currentUser != null) {
      // Cross-account isolation: if the local data belongs to a different
      // account (e.g. the previous user never signed out on this device),
      // wipe it before it can be shown or uploaded for this account.
      final owner = await DataOwnership.read();
      if (owner != null && owner != currentUser.uid) {
        try {
          await CloudSyncService().clearLocalData(bloc.repository, taskRepo);
        } catch (_) {}
        if (mounted) {
          bloc.add(LoadChallengeData());
          context.read<RegularTaskBloc>().add(LoadRegularTasks());
        }
      }

      final hasLocalData = await bloc.repository.hasActiveSession();
      if (!hasLocalData) {
        try {
          final syncSvc = CloudSyncService();
          final cloudData = await syncSvc.syncFromCloud();
          if (cloudData != null &&
              (cloudData['sessions'] as List?)?.isNotEmpty == true) {
            await bloc.repository.restoreFromJson(cloudData);
            await taskRepo.restoreFromJson(cloudData);
            if (mounted) {
              bloc.add(LoadChallengeData());
              context.read<RegularTaskBloc>().add(LoadRegularTasks());
            }
          }
        } catch (_) {}
      }
      // Record (or adopt) which account owns the local data.
      await DataOwnership.claim(currentUser.uid);
      try {
        await bloc.repository.adoptSessionsFor(currentUser.uid);
      } catch (_) {}
    }

    // Minimum splash display time
    await Future.delayed(_kSplashDuration);
    if (!mounted) return;

    // Fade out
    await _exitCtrl.forward();
    if (!mounted) return;

    // ALWAYS go to /home. The home screen handles:
    // - Active session → shows challenges and daily tasks
    // - No session → shows "Start 75 Hard Challenge" button
    // The onboarding/setup wizard is triggered FROM home, not before it.
    Navigator.of(context).pushReplacementNamed('/home');
    appNavigationReady = true;
    unawaited(FcmService.instance.flushPendingNavigation());
  }

  Future<void> _fetchQuote() async {
    final result = await ApiNinjasQuoteService().fetchQuote();
    if (!mounted) return;
    switch (result) {
      case QuoteSuccess(:final quote):
        setState(() {
          _quote = quote;
          _quoteState = _QuoteState.loaded;
        });
      case QuoteFailure(:final message):
        setState(() {
          _quote = ApiNinjasQuoteService().randomFallback;
          _quoteState = _QuoteState.error;
        });
        if (kDebugMode) debugPrint('[Splash] Quote error: $message');
    }
    _quoteCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.secondary,
                AppColors.accent
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(flex: 5, child: _buildHero()),
                Expanded(flex: 4, child: _buildQuoteArea()),
                _buildProgressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────

  Widget _buildHero() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Daily Mettle',
          style: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 700.ms).slideY(begin: -0.25, end: 0),
        const SizedBox(height: 4),
        Text(
          'HABIT & CHALLENGE',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 4,
          ),
        ).animate().fadeIn(delay: 250.ms, duration: 600.ms),
        const SizedBox(height: 28),
        ScaleTransition(
          scale: _logoScale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/logo.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Challenge Your Body,\nStrengthen Your Mind',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.88),
            height: 1.6,
            letterSpacing: 0.2,
          ),
        )
            .animate()
            .fadeIn(delay: 450.ms, duration: 700.ms)
            .slideY(begin: 0.15, end: 0),
      ],
    );
  }

  // ── Quote area ────────────────────────────────────────────────

  Widget _buildQuoteArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: FadeTransition(
        opacity: _quoteFade,
        child: SlideTransition(
          position: _quoteSlide,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: switch (_quoteState) {
              _QuoteState.loading => _buildLoader(),
              _QuoteState.loaded => _buildQuote(_quote!),
              _QuoteState.error =>
                _buildQuote(_quote ?? ApiNinjasQuoteService().randomFallback),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.9)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fetching your daily quote…',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildQuote(Quote quote) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decorative quote mark
        Text(
          '\u201C',
          style: GoogleFonts.playfairDisplay(
            fontSize: 52,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.35),
            height: 0.75,
          ),
        ),

        const SizedBox(height: 6),

        // Quote body
        Text(
          quote.quote,
          style: GoogleFonts.lora(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.65,
            fontStyle: FontStyle.italic,
          ),
        ),

        const SizedBox(height: 14),

        // Divider + author
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 1,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                quote.author,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Offline badge
        if (_quoteState == _QuoteState.error) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 11, color: Colors.white.withValues(alpha: 0.45)),
              const SizedBox(width: 4),
              Text(
                'Offline quote',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Progress bar ──────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _progressCtrl,
            builder: (_, __) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: _progressCtrl.value,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
