import 'screens/login_screen.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/challenges/data/models/challenge.dart';
import 'features/challenges/data/models/daily_progress.dart';
import 'features/challenges/data/models/challenge_session.dart';
import 'features/regular_tasks/data/models/regular_task.dart';
import 'features/regular_tasks/data/models/regular_task_completion.dart';
import 'models/quote.dart';
import 'repositories/database_repository.dart';
import 'repositories/regular_task_repository.dart';
import 'features/challenges/presentation/bloc/challenge_bloc.dart';
import 'features/challenges/presentation/bloc/challenge_event.dart';
import 'features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'services/smart_notification_service.dart';
import 'services/simple_background_check_service.dart';
import 'services/analytics_service.dart';
import 'services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// App-wide theme colors — single source of truth.
class AppColors {
  static const primary = Color(0xFFFFA726);
  static const secondary = Color(0xFFFF7043);
  static const accent = Color(0xFFEC407A);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── OFFLINE-FIRST: Core local services init first ──
  await Hive.initFlutter();
  // ... (Keep all your existing Hive adapter registrations here)

  final smartNotifications = SmartNotificationService();
  try {
    await smartNotifications.initialize();
  } catch (e) {
    if (kDebugMode) print('Notification init failed: $e');
  }

  // ── Internet-aware Firebase & Google Sign-In init ──
  final connectivity = ConnectivityService();

  unawaited(() async {
    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. NEW: Initialize Google Sign-In (ONLY ONCE HERE)
      // Replace YOUR_WEB_CLIENT_ID with the ID from your Firebase Console
      await GoogleSignIn.instance.initialize(
        serverClientId: '496007025535-vcfvp99s1kva06b042i74rnb8cg6fhrc.apps.googleusercontent.com',
      );
    } catch (e) {
      if (kDebugMode) print('Initialization failed: $e');
    }
    await connectivity.initFirebase();
  }());

  connectivity.startListening();

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
          create: (context) => AccountabilityBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Daily mettle',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const InitialScreen(),
        navigatorObservers: connectivity.isFirebaseReady
            ? [AnalyticsService().getObserver()]
            : [],
        routes: {
          '/login': (context) => const LoginScreen(), // Add this line
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const MainNavigationScreen(),
          '/history': (context) => const HistoryScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5),
        displayMedium: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.25),
        displaySmall: GoogleFonts.poppins(
            fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87),
        headlineLarge: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
        headlineMedium: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
        headlineSmall: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        titleLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: 0.15),
        titleMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            letterSpacing: 0.1),
        titleSmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            letterSpacing: 0.1),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
            letterSpacing: 0.5),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
            letterSpacing: 0.25),
        bodySmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: Colors.black54,
            letterSpacing: 0.4),
        labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            letterSpacing: 0.1),
        labelMedium: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            letterSpacing: 0.5),
        labelSmall: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
            letterSpacing: 0.5),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
        systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark),
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
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
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
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme:
          DividerThemeData(color: Colors.grey[200], thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100]!,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ── Daily Quote Splash Screen ────────────────────────────────────────────────

enum _QuoteState { loading, loaded, error }

/// Total time the splash is visible before navigating to /home.
const Duration _kSplashDuration = Duration(seconds: 2);

/// Progress bar fills over the same duration.
const Duration _kProgressDuration = Duration(seconds: 2);

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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
    WidgetsBinding.instance.addObserver(this);

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logoCtrl.dispose();
    _quoteCtrl.dispose();
    _progressCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SimpleBackgroundCheckService().checkOnAppOpen();
    }
  }

  void _checkInitialRoute() async {
    final navigator = Navigator.of(context);

    // 1. Give the splash screen 3 seconds to show off the logo
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Fade out before navigating
    await _exitCtrl.forward();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
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

  Future<void> _prepareApp() async {
    try {
      // 2. Initialize your local database & permissions
      await SmartNotificationService().requestPermissions();
      final bloc = context.read<ChallengeBloc>();
      await bloc.repository.init();
    } catch (_) {}

    // 3. THE DECISION POINT: Check Firebase session
    final currentUser = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (currentUser != null) {
        // User is already logged in, go to Dashboard
        navigator.pushReplacementNamed('/home');
      } else {
        // User is new or logged out, go to Welcome gate
        navigator.pushReplacementNamed('/onboarding');
      }
    }
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
          style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
