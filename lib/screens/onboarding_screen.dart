import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import '../widgets/icon_picker_widget.dart';
import '../widgets/challenge_icon_widget.dart';
import '../widgets/reminder_bottom_sheet.dart';
import 'package:seventy_five_hard_tracker/services/challenge_icon_service.dart';
import 'package:seventy_five_hard_tracker/core/services/dynamic_color_service.dart';
import 'package:seventy_five_hard_tracker/services/task_templates.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = [];
  final List<Challenge> _challenges = [];
  final Map<int, String?> _validationErrors = {};
  final PageController _pageController = PageController();
  // partnerUid selected per challenge index (null = no partner)
  final Map<int, AccountabilityPartner?> _selectedPartners = {};
  List<AccountabilityPartner> _availablePartners = [];
  final ScrollController _setupScrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};
  late AnimationController _headerAnimationController;
  late AnimationController _pulseController;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _headerAnimationController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Start with 2 empty challenges
    _addNewChallenge();
    _addNewChallenge();

    // Load accepted accountability partners
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    final partners = await AccountabilityService().fetchMyPartnerships();
    if (mounted) {
      setState(() {
        _availablePartners = partners
            .where((p) => p.status == PartnershipStatus.accepted)
            .toList();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _pageController.dispose();
    _setupScrollController.dispose();
    _headerAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _addNewChallenge() {
    if (_challenges.length < 10) {
      final index = _challenges.length;
      final controller = TextEditingController();
      _controllers.add(controller);
      _cardKeys[index] = GlobalKey();

      _challenges.add(Challenge(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            _challenges.length.toString(),
        title: '',
        category: 'general',
        taskType: 'hard', // Default to hard
        reminderType: 'once', // Default to once
        reminderStartHour: 8, // 8 AM
        reminderEndHour: 22, // 10 PM
        allowNightReminders: true,
        isReminderEnabled: true, // Enable by default
      ));
      setState(() {});
    }
  }

  void _removeChallenge(int index) {
    if (_challenges.length > 1) {
      _controllers[index].dispose();
      _controllers.removeAt(index);
      _challenges.removeAt(index);
      // Rebuild validation errors map with updated indices
      final newErrors = <int, String?>{};
      for (final entry in _validationErrors.entries) {
        if (entry.key < index) {
          newErrors[entry.key] = entry.value;
        } else if (entry.key > index) {
          newErrors[entry.key - 1] = entry.value;
        }
      }
      _validationErrors.clear();
      _validationErrors.addAll(newErrors);
      // Rebuild card keys with updated indices
      final newKeys = <int, GlobalKey>{};
      for (final entry in _cardKeys.entries) {
        if (entry.key < index) {
          newKeys[entry.key] = entry.value;
        } else if (entry.key > index) {
          newKeys[entry.key - 1] = entry.value;
        }
      }
      _cardKeys.clear();
      _cardKeys.addAll(newKeys);
      setState(() {});
    }
  }

  void _scrollToFirstError() {
    for (int i = 0; i < _challenges.length; i++) {
      if (_validationErrors[i] != null) {
        final key = _cardKeys[i];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
        break;
      }
    }
  }

  void _updateChallenge(
    int index, {
    String? title,
    String? iconName,
    String? imagePath,
    int? iconColor,
    String? category,
    String? taskType,
    String? reminderType,
    String? reminderTime,
    int? reminderStartHour,
    int? reminderEndHour,
    bool? allowNightReminders,
    bool? isReminderEnabled,
  }) {
    _challenges[index] = _challenges[index].copyWith(
      title: title,
      iconName: iconName,
      imagePath: imagePath,
      iconColor: iconColor,
      category: category,
      taskType: taskType,
      reminderType: reminderType,
      reminderTime: reminderTime,
      reminderStartHour: reminderStartHour,
      reminderEndHour: reminderEndHour,
      allowNightReminders: allowNightReminders,
      isReminderEnabled: isReminderEnabled,
    );
    setState(() {});
  }

  bool _hasCustomIcon(Challenge challenge) {
    return (challenge.imagePath != null && challenge.imagePath!.isNotEmpty) ||
        (challenge.iconName != null && challenge.iconName!.isNotEmpty);
  }

  Future<void> _startChallenge() async {
    final validChallenges = _challenges
        .where((challenge) => challenge.title.trim().isNotEmpty)
        .toList();

    if (validChallenges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one challenge'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate task names
    final invalidNames = <String>[];
    for (final challenge in validChallenges) {
      final error = validateTaskName(challenge.title);
      if (error != null) {
        invalidNames.add('${challenge.title}: $error');
      }
    }

    if (invalidNames.isNotEmpty) {
      // Mark validation errors on the cards so they highlight red
      for (int i = 0; i < _challenges.length; i++) {
        if (_challenges[i].title.trim().isNotEmpty) {
          _validationErrors[i] = validateTaskName(_challenges[i].title);
        }
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fix task names:\n${invalidNames.join('\n')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      _pageController.animateToPage(1,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      Future.delayed(const Duration(milliseconds: 400), _scrollToFirstError);
      return;
    }

    // Sanitize task names
    final sanitizedChallenges = validChallenges
        .map((c) => c.copyWith(title: sanitizeTaskName(c.title)))
        .toList();

    // Validate that hard tasks have a reminder time set
    final hardTasksWithoutReminder = validChallenges
        .where((c) =>
            c.taskType == 'hard' &&
            c.isReminderEnabled &&
            c.reminderTime == null)
        .toList();

    if (hardTasksWithoutReminder.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please set reminder time for: ${hardTasksWithoutReminder.map((c) => c.title).join(', ')}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      // Go back to setup page
      _pageController.animateToPage(1,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      Future.delayed(const Duration(milliseconds: 400), _scrollToFirstError);
      return;
    }

    context.read<ChallengeBloc>().add(StartNewSession(sanitizedChallenges));

    // Create accountability task requests for challenges with assigned partners
    final svc = AccountabilityService();
    final myUid = svc.currentUid;
    for (int i = 0; i < _challenges.length; i++) {
      final challenge = _challenges[i];
      if (challenge.title.trim().isEmpty) continue;
      final partner = _selectedPartners[i];
      if (partner == null || partner.id == '__ai__') continue;
      // Always assign to the OTHER person
      final otherUid =
          partner.ownerUid == myUid ? partner.partnerUid : partner.ownerUid;
      if (otherUid == null) continue;

      // Fire-and-forget — don't block navigation
      svc.createAccountabilityTask(
        accountableUid: otherUid,
        accountableName: partner.partnerName,
        partnershipId: partner.id,
        title: challenge.title.trim(),
        description: 'Daily challenge task from 75 Hard',
        challengeId: challenge.id,
      );
    }

    await context.read<ChallengeBloc>().stream.firstWhere(
          (state) => state is ChallengeLoaded && state.hasActiveSession,
        );

    // Sync to cloud immediately if user is signed in
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        final syncSvc = CloudSyncService();
        final db = context.read<ChallengeBloc>().repository;
        final taskRepo = context.read<RegularTaskBloc>().repository;
        await syncSvc.syncToCloud(db, taskRepo);
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  /// Handles Google Sign-In inline within onboarding.
  /// Shows consent dialog, signs in via CloudSyncService (derives AES key,
  /// writes users/{uid}), records consent, triggers initial sync to
  /// create user_data/{uid}, then advances to challenge setup.
  Future<void> handleInitialLogin() async {
    setState(() => _isLoggingIn = true);
    try {
      final syncSvc = CloudSyncService();

      // 1. Show consent dialog if not yet given
      if (!await syncSvc.hasConsentBeenGiven()) {
        if (!mounted) return;
        final accepted = await _showConsentDialog();
        if (!accepted) {
          setState(() => _isLoggingIn = false);
          return;
        }
      }

      // 2. Sign in via CloudSyncService (derives AES key, writes users/{uid})
      final user = await syncSvc.signInWithGoogle();
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoggingIn = false);
        return;
      }

      // 3. Record consent
      await syncSvc.recordConsent();

      // 4. Check if cloud backup exists (reinstall scenario)
      //    Restore if found, then always go to /home.
      if (mounted) {
        try {
          final db = context.read<ChallengeBloc>().repository;
          final taskRepo = context.read<RegularTaskBloc>().repository;
          await db.init();
          await taskRepo.init();

          final cloudData = await syncSvc.syncFromCloud();
          if (cloudData != null &&
              (cloudData['sessions'] as List?)?.isNotEmpty == true) {
            await db.restoreFromJson(cloudData);
            await taskRepo.restoreFromJson(cloudData);
            if (mounted) {
              context.read<ChallengeBloc>().add(LoadChallengeData());
              context.read<RegularTaskBloc>().add(LoadRegularTasks());
            }
          } else {
            // No cloud data yet — sync current (empty) local state
            await syncSvc.syncToCloud(db, taskRepo);
          }
        } catch (_) {}
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome, ${user.displayName ?? 'there'}! Cloud backup is enabled.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Always go to /home after sign-in.
      // Home shows "Start 75 Hard Challenge" if no active session.
      Navigator.pushReplacementNamed(context, '/home');
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code != GoogleSignInExceptionCode.canceled &&
          e.code != GoogleSignInExceptionCode.interrupted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.description ?? e.code.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  /// Shows the cloud backup consent dialog.
  Future<bool> _showConsentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Color(0xFFFFA726), size: 22),
            SizedBox(width: 8),
            Text('Cloud Backup'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before enabling backup, here\'s what you need to know:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            _ConsentPoint(
              icon: Icons.lock_outline,
              text:
                  'Task names, journal notes, and all your progress data are encrypted with AES-256 before leaving your device.',
            ),
            SizedBox(height: 8),
            _ConsentPoint(
              icon: Icons.key,
              text:
                  'Your encryption key is derived from your account ID. Only you can decrypt your data.',
            ),
            SizedBox(height: 8),
            _ConsentPoint(
              icon: Icons.visibility_off,
              text:
                  'We cannot read your data. The server stores only ciphertext.',
            ),
            SizedBox(height: 8),
            _ConsentPoint(
              icon: Icons.sync,
              text:
                  'Backup happens automatically in the background whenever you\'re online.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA726),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable Backup'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.purple[50]!,
              Colors.pink[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() {}),
            children: [
              _buildWelcomePage(),
              _buildChallengeSetupPage(),
              _buildReviewPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Animated Header with Pulse
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.red],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(
                            alpha: 0.3 + (_pulseController.value * 0.3)),
                        blurRadius: 20 + (_pulseController.value * 20),
                        spreadRadius: _pulseController.value * 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '75',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          )
              .animate()
              .scale(delay: 200.ms, duration: 800.ms, curve: Curves.elasticOut),

          const SizedBox(height: 40),

          // Animated Title with Shimmer Effect
          AnimatedTextKit(
            animatedTexts: [
              TypewriterAnimatedText(
                '75 Hard Challenge',
                textStyle: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                speed: const Duration(milliseconds: 100),
              ),
            ],
            isRepeatingAnimation: false,
          ).animate().shimmer(delay: 1200.ms, duration: 1500.ms),

          const SizedBox(height: 20),

          // Description with Fade and Slide
          Text(
            'Transform your life in 75 days with daily challenges that build mental toughness and discipline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          )
              .animate()
              .fadeIn(delay: 1000.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 40),

          // Rules with Staggered Animation
          _buildRulesList(),

          const SizedBox(height: 40),

          // Continue Button with Scale and Glow
          _isLoggingIn
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange))
              : Column(
                  children: [
                    // Show different button based on auth state
                    if (FirebaseAuth.instance.currentUser == null) ...[
                      // Not signed in — offer sign-in
                      _buildAnimatedButton(
                        text: 'Sign In & Start Setup',
                        onPressed: handleInitialLogin,
                        gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.red]),
                      ),
                      const SizedBox(height: 12),
                      // Guest/Local option
                      TextButton(
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: Text(
                          'Continue as Guest (Local Only)',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Already signed in — just advance to setup
                      _buildAnimatedButton(
                        text: 'Start Challenge Setup →',
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.red]),
                      ),
                    ],
                  ],
                )
                  .animate()
                  .fadeIn(delay: 1500.ms, duration: 400.ms)
                  .scale(
                      delay: 1500.ms,
                      duration: 400.ms,
                      begin: const Offset(0.8, 0.8))
                  .then()
                  .shimmer(delay: 500.ms, duration: 1500.ms),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    final rules = [
      '📋 Create 1-10 daily challenges',
      '✅ Complete ALL tasks every day',
      '🔄 Miss ANY task = Start over from Day 1',
      '🎯 No modifications once started',
      '🏆 75 days of consistency',
    ];

    return AnimationLimiter(
      child: Column(
        children: List.generate(
          rules.length,
          (index) => AnimationConfiguration.staggeredList(
            position: index,
            delay: const Duration(milliseconds: 1200),
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          rules[index],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeSetupPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with slide animation
          Row(
            children: [
              GestureDetector(
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Your Challenges',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.2, end: 0),
                    Text(
                      '${_challenges.where((c) => c.title.trim().isNotEmpty).length} of ${_challenges.length} challenges ready',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Description with tips - animated
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.indigo[50]!],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.blue[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap the icon area to customize each challenge with photos or choose from 50+ icons!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: -0.2, end: 0)
              .then()
              .shimmer(delay: 1000.ms, duration: 1500.ms),

          const SizedBox(height: 24),

          // Challenges List with staggered animation
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                controller: _setupScrollController,
                itemCount: _challenges.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    delay: const Duration(milliseconds: 400),
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: ScaleAnimation(
                          scale: 0.9,
                          child: KeyedSubtree(
                            key: _cardKeys[index],
                            child: _buildChallengeCard(index),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Add Challenge & Templates row
          if (_challenges.length < 10)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // + Add challenge button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addNewChallenge,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add Challenge (${_challenges.length}/10)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        side: BorderSide(color: Colors.green[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Templates icon button
                  OutlinedButton(
                    onPressed: _showTemplatePicker,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[300]!),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 18),
                        SizedBox(width: 4),
                        Text('Templates'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Continue Button with enhanced animation
          _buildAnimatedButton(
            text: 'Review My Challenges →',
            onPressed: () {
              final validChallenges = _challenges
                  .where((challenge) => challenge.title.trim().isNotEmpty)
                  .toList();

              if (validChallenges.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Please add at least one challenge before continuing'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
                return;
              }

              // Check for validation errors before proceeding
              bool hasErrors = false;
              for (int i = 0; i < _challenges.length; i++) {
                if (_challenges[i].title.trim().isNotEmpty) {
                  final error = validateTaskName(_challenges[i].title);
                  _validationErrors[i] = error;
                  if (error != null) hasErrors = true;
                }
              }
              if (hasErrors) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Please fix the highlighted challenge names before continuing'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
                _scrollToFirstError();
                return;
              }

              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            gradient: const LinearGradient(colors: [Colors.orange, Colors.red]),
          )
              .animate()
              .fadeIn(delay: 700.ms, duration: 400.ms)
              .slideY(begin: 0.3, end: 0)
              .then()
              .shimmer(delay: 500.ms, duration: 1500.ms),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(int index) {
    final challenge = _challenges[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          // Main card with hover effect
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with number and remove button
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Challenge ${index + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    if (_challenges.length > 1)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: Colors.grey[600], size: 22),
                        onSelected: (v) {
                          if (v == 'remove') _removeChallenge(index);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Remove Challenge',
                                  style: TextStyle(color: Colors.red)),
                            ]),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Icon and input section
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Center align both elements
                  children: [
                    // Challenge Icon
                    GestureDetector(
                      onTap: () => _showIconPicker(index),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: _hasCustomIcon(challenge)
                              ? null
                              : LinearGradient(
                                  colors: [
                                    Colors.grey[100]!,
                                    Colors.grey[200]!
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasCustomIcon(challenge)
                                ? Colors.blue[300]!
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _hasCustomIcon(challenge)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ChallengeIconWidget(
                                  challenge: challenge,
                                  size: 60,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.grey[500],
                                    size: 20,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Icon',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Challenge Input - Expanded to fill remaining space
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height:
                                60, // Match icon height for perfect alignment
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _validationErrors[index] != null
                                    ? Colors.red
                                    : Colors.grey[300]!,
                                width:
                                    _validationErrors[index] != null ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _controllers[index],
                              decoration: InputDecoration(
                                hintText: 'e.g., "Drink 3L water daily"',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18, // Center the text vertically
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1, // Single line for better alignment
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (value) {
                                _updateChallenge(index, title: value);

                                // Real-time inline validation
                                final error = value.trim().isEmpty
                                    ? null
                                    : validateTaskName(value);
                                setState(() {
                                  _validationErrors[index] = error;
                                });

                                // Auto-detect category and icon only if no custom icon is set
                                if (value.isNotEmpty &&
                                    !_hasCustomIcon(challenge)) {
                                  final iconData =
                                      ChallengeIconService.findBestIcon(value);
                                  if (iconData != null) {
                                    // Use dynamic color instead of fixed color
                                    final dynamicColor =
                                        DynamicColorService.getColorForText(
                                            value);
                                    _updateChallenge(
                                      index,
                                      iconName: iconData.name,
                                      iconColor: dynamicColor.toARGB32(),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          if (_validationErrors[index] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _validationErrors[index]!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Progress indicator
                if (challenge.title.isNotEmpty &&
                    _validationErrors[index] == null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ready for 75 days!',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Task configuration
                if (challenge.title.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // Reminder Button - full width
                  _buildReminderButton(index, challenge),
                  if (challenge.isReminderEnabled &&
                      challenge.reminderTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '⏰ ${_getReminderDescription(challenge)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  // Partner selector
                  const SizedBox(height: 8),
                  _buildPartnerSelector(index),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    final validChallenges = _challenges
        .where((challenge) => challenge.title.trim().isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Text(
                  'Review Your Challenges',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'You will need to complete ALL of these challenges EVERY DAY for 75 days.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 24),

          // Challenges Preview
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                itemCount: validChallenges.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ChallengeIconWidget(
                                challenge: validChallenges[index],
                                size: 48,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  validChallenges[index].title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Missing ANY challenge on ANY day will reset your progress to Day 1!',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Start Button
          _buildAnimatedButton(
            text: 'Start 75 Hard Challenge!',
            onPressed: _startChallenge,
            gradient: const LinearGradient(colors: [Colors.orange, Colors.red]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({
    required String text,
    required VoidCallback onPressed,
    required LinearGradient gradient,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showIconPicker(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IconPickerWidget(
        selectedIconName: _challenges[index].iconName,
        selectedImagePath: _challenges[index].imagePath,
        onSelectionChanged: (iconName, imagePath) {
          // Explicitly set fields — use empty string to clear, since copyWith
          // treats null as "keep old value"
          _challenges[index] = Challenge(
            id: _challenges[index].id,
            title: _challenges[index].title,
            reminderTime: _challenges[index].reminderTime,
            isReminderEnabled: _challenges[index].isReminderEnabled,
            imagePath: imagePath,
            iconName: iconName,
            iconColor: _challenges[index].iconColor,
            category: _challenges[index].category,
            taskType: _challenges[index].taskType,
            reminderType: _challenges[index].reminderType,
            reminderStartHour: _challenges[index].reminderStartHour,
            reminderEndHour: _challenges[index].reminderEndHour,
            allowNightReminders: _challenges[index].allowNightReminders,
            reminderIntervalMinutes: _challenges[index].reminderIntervalMinutes,
            photoRequired: _challenges[index].photoRequired,
            showInRegularTab: _challenges[index].showInRegularTab,
          );
          setState(() {});
        },
      ),
    );
  }

  Widget _buildPartnerSelector(int index) {
    final selected = _selectedPartners[index];
    final hasPartners = _availablePartners.isNotEmpty;

    return GestureDetector(
      onTap: !hasPartners ? null : () => _showPartnerPicker(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected != null
              ? Colors.blue.withValues(alpha: 0.08)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected != null
                ? Colors.blue.withValues(alpha: 0.4)
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 16,
              color: selected != null ? Colors.blue[700] : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected != null
                    ? '👤 ${selected.partnerName} (${selected.role.label})'
                    : hasPartners
                        ? 'Assign accountability partner (optional)'
                        : 'No partners yet — invite one first',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected != null ? Colors.blue[700] : Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () => setState(() => _selectedPartners[index] = null),
                child: Icon(Icons.close, size: 14, color: Colors.blue[400]),
              )
            else if (hasPartners)
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPartnerPicker(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assign Accountability Partner',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'This partner will be responsible for verifying this task.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // No partner
            ListTile(
              leading:
                  const Icon(Icons.person_off_outlined, color: Colors.grey),
              title: const Text('No partner (self-tracked)'),
              onTap: () {
                setState(() => _selectedPartners[index] = null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            // AI option
            ListTile(
              leading: const Text('🤖', style: TextStyle(fontSize: 22)),
              title: const Text('AI Accountability',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('AI will track and motivate you'),
              trailing: _selectedPartners[index]?.id == '__ai__'
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() => _selectedPartners[index] = AccountabilityPartner(
                      id: '__ai__',
                      ownerUid: '',
                      partnerName: 'AI',
                      role: PartnerRole.mentorCoach,
                      status: PartnershipStatus.accepted,
                      inviteCode: '',
                      createdAt: DateTime.now(),
                    ));
                Navigator.pop(context);
              },
            ),
            if (_availablePartners.isNotEmpty) ...[
              const Divider(height: 1),
              ..._availablePartners.map((p) => ListTile(
                    leading: Text(p.role.emoji,
                        style: const TextStyle(fontSize: 22)),
                    title: Text(p.partnerName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.role.label),
                    trailing: _selectedPartners[index]?.id == p.id
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _selectedPartners[index] = p);
                      Navigator.pop(context);
                    },
                  )),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderButton(int index, Challenge challenge) {
    final hasReminder =
        challenge.isReminderEnabled && challenge.reminderTime != null;
    return GestureDetector(
      onTap: () => _showReminderSetup(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasReminder ? Colors.orange[50] : Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasReminder ? Colors.orange[300]! : Colors.red[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasReminder ? Icons.alarm_on : Icons.alarm_add,
              size: 18,
              color: hasReminder ? Colors.orange[600] : Colors.red[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasReminder ? 'Reminder Set ✓' : '⚠ Set Reminder (Required)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasReminder ? Colors.orange[700] : Colors.red[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18,
                color: hasReminder ? Colors.orange[400] : Colors.red[400]),
          ],
        ),
      ),
    );
  }

  String _getReminderDescription(Challenge challenge) {
    final data = challenge.reminderTime ?? '';
    if (data.startsWith('once:')) {
      return 'Once at ${_formatTimeStr(data.substring(5))}';
    }
    if (data.startsWith('multiple:')) {
      final count = data.substring(9).split(',').length;
      return '$count times daily';
    }
    if (data.startsWith('hourly:')) {
      return 'Every hour from ${_formatTimeStr(data.substring(7))}';
    }
    if (data.startsWith('interval:')) {
      final parts = data.substring(9).split(':');
      final mins = int.tryParse(parts[0]) ?? 0;
      return mins < 60 ? 'Every $mins min' : 'Every ${(mins / 60).round()}h';
    }
    if (data.startsWith('custom:')) {
      final count = data.substring(7).split(',').length;
      return '$count custom times';
    }
    if (data.isNotEmpty) return 'At ${_formatTimeStr(data)}';
    return 'Enabled';
  }

  String _formatTimeStr(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  void _showReminderSetup(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderBottomSheet(
        challenge: _challenges[index],
        onSave: (updatedChallenge) {
          _challenges[index] = updatedChallenge;
          setState(() {});
        },
      ),
    );
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Quick Add from Templates',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: TaskTemplates.grouped.entries.map((entry) {
                        final category = entry.key;
                        final templates = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                category[0].toUpperCase() +
                                    category.substring(1),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            ...templates.map((t) => ListTile(
                                  leading: Icon(_getTemplateIcon(t.iconName),
                                      color: DynamicColorService
                                          .getColorForCategory(t.category)),
                                  title: Text(t.title),
                                  trailing: const Icon(Icons.add_circle_outline,
                                      color: Colors.green),
                                  onTap: () {
                                    // Remove blank (empty-title) challenges first
                                    // so the template item appears at the top
                                    final blankIndices = <int>[];
                                    for (int i = _challenges.length - 1;
                                        i >= 0;
                                        i--) {
                                      if (_challenges[i].title.trim().isEmpty) {
                                        blankIndices.add(i);
                                      }
                                    }
                                    for (final i in blankIndices) {
                                      _controllers[i].dispose();
                                      _controllers.removeAt(i);
                                      _challenges.removeAt(i);
                                    }

                                    if (_challenges.length >= 10) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Maximum 10 challenges')),
                                      );
                                      return;
                                    }
                                    final challenge =
                                        TaskTemplates.toChallenge(t);
                                    final controller =
                                        TextEditingController(text: t.title);
                                    _controllers.add(controller);
                                    _challenges.add(challenge);
                                    Navigator.pop(context);
                                    setState(() {});
                                  },
                                )),
                            const Divider(),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }

  IconData _getTemplateIcon(String name) {
    const map = {
      'fitness_center': Icons.fitness_center,
      'directions_run': Icons.directions_run,
      'self_improvement': Icons.self_improvement,
      'directions_walk': Icons.directions_walk,
      'air': Icons.air,
      'edit_note': Icons.edit_note,
      'water_drop': Icons.water_drop,
      'no_food': Icons.no_food,
      'restaurant': Icons.restaurant,
      'no_drinks': Icons.no_drinks,
      'menu_book': Icons.menu_book,
      'school': Icons.school,
      'headphones': Icons.headphones,
      'alarm': Icons.alarm,
      'phone_disabled': Icons.phone_disabled,
      'shower': Icons.shower,
      'camera_alt': Icons.camera_alt,
      'bedtime': Icons.bedtime,
    };
    return map[name] ?? Icons.check_circle;
  }
}

// ── Helper widget for consent dialog points ──────────────────────────────────

class _ConsentPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConsentPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.green[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}
