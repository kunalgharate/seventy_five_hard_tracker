import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/challenge.dart';
import 'models/daily_progress.dart';
import 'models/challenge_session.dart';
import 'models/regular_task.dart';
import 'models/regular_task_completion.dart';
import 'models/quote.dart';
import 'repositories/database_repository.dart';
import 'repositories/regular_task_repository.dart';
import 'bloc/challenge_bloc.dart';
import 'bloc/challenge_event.dart';
import 'bloc/regular_task_bloc.dart';
import 'bloc/regular_task_event.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'services/smart_notification_service.dart';
import 'services/simple_background_check_service.dart';
import 'services/analytics_service.dart';
import 'services/connectivity_service.dart';
import 'services/api_quote_service.dart';
import 'bloc/accountability_bloc.dart';

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
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ChallengeAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyProgressAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(ChallengeSessionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(RegularTaskAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(RegularTaskCompletionAdapter());
  }

  final smartNotifications = SmartNotificationService();
  try {
    await smartNotifications.initialize();
  } catch (e) {
    if (kDebugMode) print('Notification init failed: $e');
  }

  // ── Internet-aware Firebase init (non-blocking) ──
  final connectivity = ConnectivityService();
  // Don't await — let Firebase init in the background so the app starts instantly
  unawaited(connectivity.initFirebase());
  connectivity.startListening(); // retries when internet comes back

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
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

/// State for the quote fetch lifecycle.
enum _QuoteState { loading, loaded, error }

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────
  _QuoteState _quoteState = _QuoteState.loading;
  Quote? _quote;

  // ── Animation controllers ──────────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _quoteController;
  late final Animation<double> _logoScale;
  late final Animation<double> _quoteFade;
  late final Animation<Offset> _quoteSlide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Logo entrance: scale from 0.6 → 1.0
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    // Quote card: fade + slide up
    _quoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _quoteFade = CurvedAnimation(
      parent: _quoteController,
      curve: Curves.easeIn,
    );
    _quoteSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _quoteController,
      curve: Curves.easeOutCubic,
    ));

    _logoController.forward();
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logoController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SimpleBackgroundCheckService().checkOnAppOpen();
    }
  }

  // ── Initialisation ─────────────────────────────────────────────

  Future<void> _initApp() async {
    // Kick off quote fetch and app init in parallel.
    await Future.wait([
      _fetchQuote(),
      _prepareApp(),
    ]);

    // Show the quote for at least 2 seconds so the user can read it.
    await Future.delayed(const Duration(seconds: 2));

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
        // Use a fallback so the screen never looks broken.
        setState(() {
          _quote = ApiNinjasQuoteService().randomFallback;
          _quoteState = _QuoteState.error;
        });
        if (kDebugMode) debugPrint('[InitialScreen] Quote error: $message');
    }

    // Animate the quote card in after state is set.
    _quoteController.forward();
  }

  Future<void> _prepareApp() async {
    try {
      await SmartNotificationService().requestPermissions();
    } catch (_) {}
    try {
      if (mounted) {
        final bloc = context.read<ChallengeBloc>();
        await bloc.repository.init();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InitialScreen] App init error: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.secondary,
              AppColors.accent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top section: app name + tagline + logo ──────────
              Expanded(
                flex: 5,
                child: _buildHeroSection(),
              ),

              // ── Bottom section: quote card ──────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _buildQuoteSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero (logo + title + tagline) ──────────────────────────────

  Widget _buildHeroSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App name
        Text(
          'Daily Mettle',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, end: 0),

        const SizedBox(height: 4),

        // Tagline
        Text(
          'Habit & Challenge',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 2.5,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

        const SizedBox(height: 28),

        // Logo
        ScaleTransition(
          scale: _logoScale,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/logo.jpg',
                width: 130,
                height: 130,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Punch line
        Text(
          'Challenge Your Body,\nStrengthen Your Mind',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.5,
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 700.ms)
            .slideY(begin: 0.2, end: 0),
      ],
    );
  }

  // ── Quote card ─────────────────────────────────────────────────

  Widget _buildQuoteSection() {
    return FadeTransition(
      opacity: _quoteFade,
      child: SlideTransition(
        position: _quoteSlide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: switch (_quoteState) {
            _QuoteState.loading => _buildLoadingIndicator(),
            _QuoteState.loaded => _buildQuoteContent(_quote!),
            _QuoteState.error => _buildQuoteContent(
                _quote ?? ApiNinjasQuoteService().randomFallback,
              ),
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading today\'s quote…',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteContent(Quote quote) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decorative open-quote mark
        Text(
          '\u201C',
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.5),
            height: 0.8,
          ),
        ),

        const SizedBox(height: 4),

        // Quote text
        Text(
          quote.quote,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.55,
          ),
        ),

        const SizedBox(height: 12),

        // Author
        Row(
          children: [
            Container(
              width: 28,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                quote.author,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Subtle offline indicator — only shown when API failed
        if (_quoteState == _QuoteState.error) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Offline quote',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
