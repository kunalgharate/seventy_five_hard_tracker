import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../models/challenge.dart';
import '../bloc/challenge_bloc.dart';
import '../bloc/challenge_event.dart';
import '../widgets/icon_picker_widget.dart';
import '../widgets/challenge_icon_widget.dart';
import '../widgets/reminder_bottom_sheet.dart';
import '../services/challenge_icon_service.dart';
import '../services/dynamic_color_service.dart';
import '../services/task_templates.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = [];
  final List<Challenge> _challenges = [];
  final PageController _pageController = PageController();
  late AnimationController _headerAnimationController;
  late AnimationController _pulseController;

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
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _pageController.dispose();
    _headerAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _addNewChallenge() {
    if (_challenges.length < 10) {
      final controller = TextEditingController();
      _controllers.add(controller);

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
      setState(() {});
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
      return;
    }

    context.read<ChallengeBloc>().add(StartNewSession(validChallenges));

    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

          const SizedBox(height: 60),

          // Rules with Staggered Animation
          _buildRulesList(),

          const Spacer(),

          // Continue Button with Scale and Glow
          _buildAnimatedButton(
            text: 'Start Setup',
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            gradient:
                const LinearGradient(colors: [Colors.blue, Colors.purple]),
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
      padding: const EdgeInsets.all(24),
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
                          child: _buildChallengeCard(index),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Add Challenge Button with pulse animation
          if (_challenges.length < 10)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _addNewChallenge,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.teal[500]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Add (${_challenges.length}/10)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showTemplatePicker,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.indigo[500]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome,
                                color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Templates',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),

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
                      GestureDetector(
                        onTap: () => _removeChallenge(index),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.red[600],
                            size: 20,
                          ),
                        ),
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
                      child: Container(
                        height: 60, // Match icon height for perfect alignment
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
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

                            // Auto-detect category and icon only if no custom icon is set
                            if (value.isNotEmpty &&
                                !_hasCustomIcon(challenge)) {
                              final iconData =
                                  ChallengeIconService.findBestIcon(value);
                              if (iconData != null) {
                                // Use dynamic color instead of fixed color
                                final dynamicColor =
                                    DynamicColorService.getColorForText(value);
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
                    ),
                  ],
                ),

                // Progress indicator
                if (challenge.title.isNotEmpty)
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
      padding: const EdgeInsets.all(24),
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
        selectedColor: _challenges[index].iconColor,
        onSelectionChanged: (iconName, imagePath, color) {
          _updateChallenge(
            index,
            iconName: iconName,
            imagePath: imagePath,
            iconColor: color,
          );
        },
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
        builder: (context, scrollController) => Container(
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                            category[0].toUpperCase() + category.substring(1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        ...templates.map((t) => ListTile(
                              leading: Icon(_getTemplateIcon(t.iconName),
                                  color:
                                      DynamicColorService.getColorForCategory(
                                          t.category)),
                              title: Text(t.title),
                              trailing: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onTap: () {
                                if (_challenges.length >= 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Maximum 10 challenges')),
                                  );
                                  return;
                                }
                                final challenge = TaskTemplates.toChallenge(t);
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
        ),
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
