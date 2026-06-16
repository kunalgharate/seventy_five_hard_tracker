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
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/daily_task_card.dart';
import '../widgets/progress_stats.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/horizontal_date_picker.dart';
import '../widgets/journal_bottom_sheet.dart';
import '../widgets/photo_proof_sheet.dart';
import '../widgets/proof_review_dialog.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  Map<String, String> _assignedChallengeMap =
      {}; // challengeId → accountableUid
  Map<String, String> _assignedPartnerNames = {}; // challengeId → partnerName
  Map<String, ProofStatus> _proofStatuses = {}; // challengeId → proofStatus
  Map<String, AccountabilityTaskStatus> _accountabilityStatuses =
      {}; // challengeId → accountabilityStatus
  StreamSubscription<List<AccountabilityTask>>? _tasksAssignedByMeSub;
  List<AccountabilityTask>? _latestAssignedTasks;
  Timer? _assignedReloadDebounce;

  // Tracks previously known completed tasks to avoid re-triggering
  final Set<String> _previouslyCompletedTaskIds = {};

  @override
  void initState() {
    super.initState();
    context.read<ChallengeBloc>().add(LoadChallengeData());
    _loadAssignedChallenges();
    // One-time cleanups
    AccountabilityService()..cleanupSelfAssignedTasks()..migrateOrphanedAccountabilityTasks();
    // Subscribe to real-time streams
    _subscribeToStreams();
  }

  @override
  void dispose() {
    _assignedReloadDebounce?.cancel();
    _tasksAssignedByMeSub?.cancel();
    super.dispose();
  }

  void _scheduleAssignedReload() {
    _assignedReloadDebounce?.cancel();
    _assignedReloadDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_latestAssignedTasks != null) {
        _syncCompletedTasks(_latestAssignedTasks!);
      }
      _loadAssignedChallenges();
    });
  }

  void _subscribeToStreams() {
    final svc = AccountabilityService();

    // Listen for tasks assigned BY me (tasks I assigned to partners)
    // Used to auto-sync completion back to my 75 Hard progress
    _tasksAssignedByMeSub = svc.assignedByMeStream().listen((tasks) {
      if (!mounted) return;
      _latestAssignedTasks = tasks;
      _scheduleAssignedReload();
    });
  }

  /// When a partner completes an accountability task linked to one of my
  /// challenges, auto-update my local 75 Hard progress.
  void _syncCompletedTasks(List<AccountabilityTask> tasks) {
    for (final task in tasks) {
      if (task.challengeId == null) continue;
      if (!task.isCompleted) continue;
      if (_previouslyCompletedTaskIds.contains(task.id)) continue;

      _previouslyCompletedTaskIds.add(task.id);

      // Mark my local challenge task as completed
      context.read<ChallengeBloc>().add(UpdateDailyProgress(
            date: DateTime.now(),
            challengeId: task.challengeId!,
            isCompleted: true,
          ));
    }
  }

  Future<void> _loadAssignedChallenges() async {
    final svc = AccountabilityService();
    final results = await Future.wait([
      svc.fetchAssignedChallengeMap(), // challengeId → accountableUid (I assigned)
      svc.fetchMyPartnerships(),
      svc.fetchAccountableForMap(), // challengeId → assignerName (assigned to me)
      svc.fetchMyAccountabilityTaskStatuses(), // challengeId → my accountability status
    ]);
    final challengeMap = results[0] as Map<String, String>;
    final partnerships = results[1] as List<AccountabilityPartner>;
    final accountableForMap = results[2] as Map<String, String>;
    final accountabilityStatuses = results[3] as Map<String, AccountabilityTaskStatus>;

    // Build challengeId → partnerName for tasks I ASSIGNED
    final myUid = svc.currentUid;
    final uidToName = <String, String>{};
    for (final p in partnerships) {
      if (p.partnerUid != null) uidToName[p.partnerUid!] = p.partnerName;
      if (p.ownerUid != myUid) uidToName[p.ownerUid] = p.partnerName;
    }
    final partnerNames = <String, String>{};
    // From tasks I assigned — show the accountable person's name
    challengeMap.forEach((cid, uid) {
      final name = uidToName[uid];
      if (name != null) partnerNames[cid] = name;
    });
    // From tasks assigned TO me — show the assigner's name on my card
    accountableForMap.forEach((cid, assignerName) {
      partnerNames.putIfAbsent(cid, () => assignerName);
    });

    // Fetch proof statuses for all challenge IDs that have partners
    final allCids = <String>{
      ...challengeMap.keys,
      ...accountableForMap.keys,
    };
    Map<String, ProofStatus> proofStatuses = {};
    if (allCids.isNotEmpty) {
      // Firestore whereIn supports up to 30 values
      final batches = <List<String>>[];
      var batch = <String>[];
      for (final cid in allCids) {
        batch.add(cid);
        if (batch.length == 30) {
          batches.add(batch);
          batch = [];
        }
      }
      if (batch.isNotEmpty) batches.add(batch);
      for (final b in batches) {
        final result = await svc.fetchProofStatusesForChallengeIds(b);
        proofStatuses.addAll(result);
      }
    }

    // Populate set of already-completed accountability tasks I assigned
    // so the real-time stream listener doesn't re-trigger auto-completion.
    final snap = await svc.fetchAssignedTasksCompleted();
    _previouslyCompletedTaskIds.addAll(
      snap
          .where((t) => t.challengeId != null)
          .map((t) => t.id),
    );

    if (mounted) {
      setState(() {
        _assignedChallengeMap = challengeMap;
        _assignedPartnerNames = partnerNames;
        _proofStatuses = proofStatuses;
        _accountabilityStatuses = accountabilityStatuses;
      });
    }
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
    final isFutureDate = _normalizeDate(_selectedDay).isAfter(_normalizeDate(DateTime.now()));
    final isBeforeStart = _normalizeDate(_selectedDay).isBefore(_normalizeDate(session.startDate));

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
                    child: Icon(Icons.check_circle, color: Colors.green, size: 32),
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
                          child: DailyTaskCard(
                            challenge: challenge,
                            isCompleted: isCompleted,
                            isEditable: isToday,
                            accountablePartnerUid:
                                _assignedChallengeMap[challenge.id],
                            partnerName: _assignedPartnerNames[challenge.id],
                            proofStatus: _proofStatuses[challenge.id],
                            accountabilityStatus:
                                _accountabilityStatuses[challenge.id],
                            onSubmitProof: () => _submitProof(challenge),
                            onReviewProof: () => _reviewProof(challenge),
                            onViewProof: () => _viewProof(challenge),
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

// ── Discipline Score Card ────────────────────────────────────────────────────

class _DisciplineScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisciplineScoreBloc, DisciplineScoreState>(
      builder: (context, state) {
        if (state is! DisciplineScoreLoaded) {
          return const SizedBox.shrink();
        }
        final s = state;
        return Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFA726).withValues(alpha: 0.08),
                  const Color(0xFFFF7043).withValues(alpha: 0.05),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Color(0xFFFFA726), size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Discipline Score',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const Spacer(),
                    // Grade badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gradeColor(s.grade).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _gradeColor(s.grade), width: 1.2),
                      ),
                      child: Text(
                        s.grade,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _gradeColor(s.grade),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Score + tier
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      s.disciplineScore.toStringAsFixed(0),
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _gradeColor(s.grade),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('/100',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ),
                    const Spacer(),
                    Text(
                      s.tier,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _gradeColor(s.grade),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: s.disciplineScore / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_gradeColor(s.grade)),
                  ),
                ),

                const SizedBox(height: 14),

                // Warning banner — shown when consecutive misses exist
                if (s.hasActiveWarnings) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: s.onFinalWarning
                          ? Colors.red.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: s.onFinalWarning ? Colors.red : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s.onFinalWarning
                              ? Icons.dangerous_outlined
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: s.onFinalWarning ? Colors.red : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.onFinalWarning
                                ? '${s.warningLabel} — Next miss breaks your streak! (-15 pts)'
                                : '${s.warningLabel} — Complete today to avoid penalty',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: s.onFinalWarning
                                  ? Colors.red[700]
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Stats row
                Row(
                  children: [
                    _StatPill(
                      icon: Icons.local_fire_department,
                      label: 'Streak',
                      value: '${s.currentStreak}d',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _StatPill(
                      icon: Icons.emoji_events_outlined,
                      label: 'Best',
                      value: '${s.longestStreak}d',
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    _StatPill(
                      icon: Icons.calendar_today_outlined,
                      label: '7-day',
                      value: '${s.weeklyConsistency.toStringAsFixed(0)}%',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _StatPill(
                      icon: Icons.trending_up,
                      label: 'Breaks',
                      value: '${s.streakBreaks}',
                      color: s.streakBreaks > 0 ? Colors.red : Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S':
        return const Color(0xFF6C3FC5); // purple
      case 'A':
        return const Color(0xFF2E7D32); // dark green
      case 'B':
        return const Color(0xFF1565C0); // blue
      case 'C':
        return const Color(0xFFFFA726); // orange
      case 'D':
        return const Color(0xFFE65100); // deep orange
      default:
        return const Color(0xFFB71C1C); // red
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Partner-assigned task card removed — tasks now shown only in Partners tab ──
