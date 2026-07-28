import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/discipline_score.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import '../widgets/daily_task_card.dart';
import '../widgets/water_reminder_widget.dart';
import '../widgets/progress_stats.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/horizontal_date_picker.dart';
import '../widgets/journal_bottom_sheet.dart';
import '../widgets/photo_proof_sheet.dart';
import '../widgets/proof_review_dialog.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'package:seventy_five_hard_tracker/core/constants/app_constants.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  final Map<String, ProofStatus> _proofStatuses = {};
  final Map<String, AccountabilityTaskStatus> _accountabilityStatuses = {};

  /// Whether a challenge should render as a water tracker card.
  /// Only challenges explicitly categorized as 'water' use the tracker.
  bool _isWaterChallenge(Challenge challenge) => challenge.category == 'water';

  @override
  void initState() {
    super.initState();
    context.read<ChallengeBloc>().add(LoadChallengeData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Daily mettle',
        actions: [
          // Test notification button (only in debug mode)
          if (kDebugMode)
            IconButton(
              icon:
                  const Icon(Icons.notifications_active, color: Colors.orange),
              onPressed: () async {
                final notificationService = SmartNotificationService();
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Notifications'),
                    content: const Text('Choose a test type:'),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await notificationService.sendTestNotification();
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Immediate test notification sent')),
                            );
                          }
                        },
                        child: const Text('Immediate'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await notificationService.scheduleTestNotification();
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Test notification scheduled for 10 seconds')),
                            );
                          }
                        },
                        child: const Text('10 Seconds'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Test Notifications',
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ChallengeBloc, ChallengeState>(
        listener: (context, state) {
          // Use addPostFrameCallback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return; // Safety check

            if (state is ChallengeLoaded && state.hasActiveSession) {
              // Reset selected day to today when a new session becomes active
              // (e.g. after restarting from history)
              final today = DateTime.now();
              if (!_isSameDay(_selectedDay, today)) {
                setState(() {
                  _selectedDay = today;
                });
              }
            } else if (state is ChallengeError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is ChallengeReset) {
              _showResetDialog(state);
            } else if (state is ChallengeCompleted) {
              _showCompletionDialog(state.completedSession);
            }
          });
        },
        builder: (context, state) {
          if (state is ChallengeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChallengeLoaded) {
            if (!state.hasActiveSession) {
              return _buildNoActiveSession();
            }

            return _buildActiveSession(state);
          }

          return _buildNoActiveSession();
        },
      ),
      floatingActionButton: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          if (state is ChallengeLoaded) {
            if (!state.hasActiveSession) {
              return FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/onboarding');
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Start Challenge',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            } else {
              // Journal FAB for active session
              final selectedProgress = state.currentProgress
                  .where((p) => _isSameDay(p.date, _selectedDay))
                  .firstOrNull;
              final hasNote = selectedProgress?.journalNote != null &&
                  selectedProgress!.journalNote!.isNotEmpty;

              return FloatingActionButton.extended(
                heroTag: 'journal',
                onPressed: () => _showJournalBottomSheet(
                  context,
                  state,
                  selectedProgress,
                ),
                icon: Icon(
                  hasNote ? Icons.book : Icons.book_outlined,
                  size: 20,
                ),
                label: Text(
                  hasNote ? 'View Journal' : 'Add Journal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNoActiveSession() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Challenge',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your 75 Hard Challenge journey!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/onboarding'),
            icon: const Icon(Icons.add),
            label: const Text('Create 75 Hard Challenge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA726),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession(ChallengeLoaded state) {
    final session = state.activeSession!;
    final daysSinceStart =
        DateTime.now().difference(session.startDate).inDays + 1;
    final currentDay = daysSinceStart > 75 ? 75 : daysSinceStart;

    // Trigger discipline score calculation whenever session data changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DisciplineScoreBloc>().add(CalculateDisciplineScore(
              session: session,
              progress: state.currentProgress,
            ));
      }
    });

    return Column(
      children: [
        // Progress Stats
        ProgressStats(
          currentDay: currentDay,
          totalDays: 75,
          session: session,
          progress: state.currentProgress,
        ),

        // Calendar
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Date',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFA726),
                                  ),
                        ),
                        const SizedBox(height: 12),
                        HorizontalDatePicker(
                          selectedDate: _selectedDay,
                          startDate: session.startDate,
                          endDate:
                              session.startDate.add(const Duration(days: 74)),
                          onDateSelected: (selectedDate) {
                            setState(() {
                              _selectedDay = selectedDate;
                            });
                          },
                          completedDates: state.currentProgress
                              .where((p) => p.isCompleted)
                              .map((p) => p.date)
                              .toList(),
                          incompleteDates: state.currentProgress
                              .where((p) => !p.isCompleted)
                              .map((p) => p.date)
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        // Progress indicator for selected date
                        _buildDateProgressIndicator(state),
                      ],
                    ),
                  ),
                ),

                // Daily Tasks for Selected Day
                _buildDailyTasks(session, state.currentProgress),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTasks(
      ChallengeSession session, List<DailyProgress> allProgress) {
    // Clamp selected day to the session date range to avoid stale date state.
    if (_selectedDay.isBefore(session.startDate)) {
      _selectedDay = session.startDate;
    }
    final selectedProgress =
        allProgress.where((p) => _isSameDay(p.date, _selectedDay)).firstOrNull;

    final isToday = _isSameDay(_selectedDay, DateTime.now());
    final isFutureDate =
        _normalizeDate(_selectedDay).isAfter(_normalizeDate(DateTime.now()));
    final isBeforeStart = _normalizeDate(_selectedDay)
        .isBefore(_normalizeDate(session.startDate));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    DateFormat('EEEE, MMM d').format(_selectedDay),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedProgress?.isCompleted == true)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 32),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (isBeforeStart)
              const Text(
                'Challenge hasn\'t started yet',
                style: TextStyle(color: Colors.grey),
              ).animate().fadeIn(duration: 400.ms)
            else if (isFutureDate)
              const Text(
                'Future date - complete today\'s tasks first!',
                style: TextStyle(color: Colors.grey),
              ).animate().fadeIn(duration: 400.ms)
            else
              // Animated task cards with staggered entrance
              ...session.challenges
                  .where((c) => c.taskType != 'regular')
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final index = entry.key;
                final challenge = entry.value;
                final isCompleted =
                    selectedProgress?.challengeCompletions[challenge.id] ??
                        false;
                final totalNonRegular = session.challenges
                    .where((c) => c.taskType != 'regular')
                    .length;
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: index == totalNonRegular - 1 ? 0 : 8,
                        ),
                        child: RepaintBoundary(
                          child: _isWaterChallenge(challenge)
                              ? _buildWaterTracker(
                                  challenge, isToday, selectedProgress)
                              : DailyTaskCard(
                                  challenge: challenge,
                                  isCompleted: isCompleted,
                                  isEditable: isToday,
                                  onToggle: (completed) {
                                    context.read<ChallengeBloc>().add(
                                          UpdateDailyProgress(
                                            date: _selectedDay,
                                            challengeId: challenge.id,
                                            isCompleted: completed,
                                          ),
                                        );
                                  },
                                  onReminderUpdate: (updatedChallenge) {
                                    context.read<ChallengeBloc>().add(
                                          UpdateChallenge(updatedChallenge),
                                        );
                                  },
                                  onRemove: () {
                                    context.read<ChallengeBloc>().add(
                                          RemoveChallengeFromSession(
                                              challenge.id),
                                        );
                                  },
                                  proofStatus: _proofStatuses[challenge.id],
                                  onSubmitProof: () => _submitProof(challenge),
                                  onReviewProof: () => _reviewProof(challenge),
                                  onViewProof: () => _viewProof(challenge),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(
                height: 120), // Space for FAB to avoid covering content
          ],
        ),
      ),
    );
  }

  Widget _buildWaterTracker(
      Challenge challenge, bool isToday, DailyProgress? selectedProgress) {
    // Parse completed times from taskNotes — skip individual invalid tokens
    List<DateTime> completedTimes = [];
    final noteString = selectedProgress?.taskNotes?[challenge.id];
    if (noteString != null && noteString.isNotEmpty) {
      for (final token in noteString.split(',')) {
        final trimmed = token.trim();
        if (trimmed.isEmpty) continue;
        final parsed = DateTime.tryParse(trimmed);
        if (parsed != null) completedTimes.add(parsed);
      }
    }

    return WaterReminderWidget(
      selectedDate: _selectedDay,
      completedTimes: completedTimes,
      isEditable: isToday,
      onWaterLogged: (dt) {
        if (!isToday) return;
        completedTimes.add(dt);
        _updateWaterProgress(challenge, completedTimes);
      },
      onWaterRemoved: (dt) {
        if (!isToday) return;
        // Remove only the first entry matching this exact timestamp (minute-level identity)
        final idx = completedTimes.indexWhere((e) =>
            e.year == dt.year &&
            e.month == dt.month &&
            e.day == dt.day &&
            e.hour == dt.hour &&
            e.minute == dt.minute);
        if (idx != -1) completedTimes.removeAt(idx);
        _updateWaterProgress(challenge, completedTimes);
      },
    );
  }

  void _updateWaterProgress(Challenge challenge, List<DateTime> times) {
    final newString = times.map((e) => e.toIso8601String()).join(',');
    final isCompleted = times.length >= kWaterGoal;

    // 1. Save timestamps first so a stale rebuild doesn't overwrite them
    context.read<ChallengeBloc>().add(
          AddTaskNote(
            date: _selectedDay,
            challengeId: challenge.id,
            note: newString,
          ),
        );

    // 2. Update the overall completion boolean
    context.read<ChallengeBloc>().add(
          UpdateDailyProgress(
            date: _selectedDay,
            challengeId: challenge.id,
            isCompleted: isCompleted,
          ),
        );
  }

  Widget _buildDateProgressIndicator(ChallengeLoaded state) {
    final progress = state.currentProgress
        .where((p) => _isSameDay(p.date, _selectedDay))
        .firstOrNull;

    if (progress == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'No data for this date',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: progress.isCompleted ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: progress.isCompleted ? Colors.green[300]! : Colors.red[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            progress.isCompleted ? Icons.check_circle : Icons.cancel,
            color: progress.isCompleted ? Colors.green[600] : Colors.red[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            progress.isCompleted
                ? 'All tasks completed!'
                : 'Some tasks incomplete',
            style: TextStyle(
              color: progress.isCompleted ? Colors.green[700] : Colors.red[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitProof(Challenge challenge) async {
    final svc = AccountabilityService();
    final taskId = await svc.fetchTaskIdByChallengeId(challenge.id);
    if (taskId == null) return;

    if (!mounted) return;
    final result = await PhotoProofSheet.show(
      context: context,
      taskId: taskId,
      taskName: challenge.title,
      date: _selectedDay,
    );
    if (result == true && mounted) {
      setState(() {
        _proofStatuses[challenge.id] = ProofStatus.submitted;
      });
    }
  }

  Future<void> _reviewProof(Challenge challenge) async {
    final svc = AccountabilityService();
    final task = await svc.fetchTaskByChallengeId(challenge.id);
    if (task == null) return;

    if (!mounted) return;
    final result = await ProofReviewDialog.show(context, task);
    if (result == true && mounted) {
      final updated = await svc.fetchTaskByChallengeId(challenge.id);
      if (mounted && updated != null) {
        setState(() {
          _proofStatuses[challenge.id] = updated.proofStatus;
          _accountabilityStatuses[challenge.id] = updated.status;
        });
      }
    }
  }

  Future<void> _viewProof(Challenge challenge) async {
    final svc = AccountabilityService();
    final task = await svc.fetchTaskByChallengeId(challenge.id);
    if (task == null || task.proofUrl == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                task.proofUrl!,
                fit: BoxFit.contain,
                width: double.infinity,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Failed to load image',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _showResetDialog(ChallengeReset state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Challenge Reset!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your challenge has been reset to Day 1.'),
            const SizedBox(height: 8),
            Text('Reason: ${state.reason}'),
            if (state.failedChallenges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Failed tasks: ${state.failedChallenges.join(', ')}'),
            ],
            const SizedBox(height: 16),
            const Text('Don\'t give up! You can start again anytime.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(ChallengeSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Congratulations! 🎉'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'You completed the 75 Hard Challenge!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You are amazing! This is a huge accomplishment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Thank You!'),
          ),
        ],
      ),
    );
  }

  void _showJournalBottomSheet(
    BuildContext context,
    ChallengeLoaded state,
    DailyProgress? selectedProgress,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JournalBottomSheet(
        date: _selectedDay,
        existingNote: selectedProgress?.journalNote,
        onSave: (note) {
          context.read<ChallengeBloc>().add(
                AddJournalNote(date: _selectedDay, note: note),
              );
        },
        onDelete: selectedProgress?.journalNote != null
            ? () {
                context.read<ChallengeBloc>().add(
                      AddJournalNote(date: _selectedDay, note: ''),
                    );
              }
            : null,
      ),
    );
  }
}
