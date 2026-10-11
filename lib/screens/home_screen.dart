import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/widgets/greeting_header.dart';
import 'package:seventy_five_hard_tracker/widgets/challenge_hero_card.dart';
import 'package:seventy_five_hard_tracker/widgets/review_notification_card.dart';
import 'package:seventy_five_hard_tracker/widgets/motivation_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seventy_five_hard_tracker/services/quotes_service.dart';
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
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import '../widgets/daily_task_card.dart';
import '../widgets/challenge_task_sheet.dart';
import '../widgets/water_reminder_widget.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/photo_proof_sheet.dart';
import '../widgets/proof_review_dialog.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'package:seventy_five_hard_tracker/core/constants/app_constants.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onGoToSquad});

  final VoidCallback? onGoToSquad;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  final Map<String, ProofStatus> _proofStatuses = {};
  final Map<String, AccountabilityTaskStatus> _accountabilityStatuses = {};

  /// challengeId -> true when the current user is only the REVIEWER of the
  /// linked accountability task (a partner assigned it). Such cards must not
  /// offer completion — the owner completes and uploads proof.
  final Map<String, bool> _reviewOnlyChallenges = {};
  final ScrollController _scrollController = ScrollController();

  /// Live Firestore subscriptions so an approval on the reviewer's device
  /// reflects on the owner's Today screen (and vice versa) without a restart.
  StreamSubscription<List<AccountabilityTask>>? _assignedByMeSub;
  StreamSubscription<List<AccountabilityTask>>? _myTasksSub;

  /// Tracks the session for which accountability statuses were last loaded.
  /// Prevents re-fetching from Firestore on every task-toggle rebuild —
  /// we only reload on initial load or when the active session changes.
  String? _accountabilityLoadedSessionId;

  /// Last successfully loaded state, kept so a transient error emission
  /// (e.g. a denied task toggle) never blanks the Today screen.
  ChallengeLoaded? _lastLoadedState;

  /// Recent review notifications for inline display.
  List<Map<String, String>> _recentNotifications = [];

  /// Daily motivational quote.
  String _dailyQuote =
      'Discipline is choosing between what you want now and what you want most.';

  // ignore: prefer_final_fields is intentional — updated after init

  /// Whether a challenge should render as a water tracker card.
  /// Only challenges explicitly categorized as 'water' use the tracker.
  bool _isWaterChallenge(Challenge challenge) => challenge.category == 'water';

  @override
  void initState() {
    super.initState();
    context.read<ChallengeBloc>().add(LoadChallengeData());
    _loadRecentNotifications();
    _loadDailyQuote();
    _subscribeToAccountabilityStreams();
  }

  /// Listens to both directions of the review flow so approval reflects on
  /// BOTH sides in real time: owner sees the checkbox check itself when the
  /// reviewer approves, reviewer sees the updated proof status immediately.
  void _subscribeToAccountabilityStreams() {
    try {
      final svc = AccountabilityService();
      _assignedByMeSub?.cancel();
      _myTasksSub?.cancel();
      _assignedByMeSub = svc.assignedByMeStream().listen((tasks) {
        if (!mounted) return;
        _applyTaskStreamUpdate(tasks);
      }, onError: (_) {});
      _myTasksSub = svc.myTasksStream().listen((tasks) {
        if (!mounted) return;
        _applyTaskStreamUpdate(tasks);
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Merges a Firestore task update into the local status maps. When a task
  /// lands in approved/completed, the owner's local daily progress is marked
  /// complete too — so both sides show the same checked state.
  void _applyTaskStreamUpdate(List<AccountabilityTask> tasks) {
    if (!mounted) return;
    final state = context.read<ChallengeBloc>().state;
    if (state is! ChallengeLoaded || !state.hasActiveSession) return;
    final challengeIds =
        state.activeSession!.challenges.map((c) => c.id).toSet();
    var changed = false;
    for (final task in tasks) {
      final cid = task.challengeId;
      if (cid == null || !challengeIds.contains(cid)) continue;
      final myUid = AccountabilityService().currentUid;
      final reviewOnly = myUid != null &&
          task.accountableUid == myUid &&
          task.assignedByUid != myUid;
      if (_accountabilityStatuses[cid] != task.status ||
          _proofStatuses[cid] != task.proofStatus ||
          _reviewOnlyChallenges[cid] != reviewOnly) {
        _accountabilityStatuses[cid] = task.status;
        _proofStatuses[cid] = task.proofStatus;
        _reviewOnlyChallenges[cid] = reviewOnly;
        changed = true;
      }
      final approved = task.status == AccountabilityTaskStatus.approved ||
          task.status == AccountabilityTaskStatus.completed;
      if (approved && !reviewOnly) {
        context.read<ChallengeBloc>().add(
              UpdateDailyProgress(
                date: _selectedDay,
                challengeId: cid,
                isCompleted: true,
              ),
            );
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _loadRecentNotifications() async {
    try {
      final svc = AccountabilityService();
      final uid = svc.currentUid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('fcm_notifications')
          .where('recipientUid', isEqualTo: uid)
          .where('delivered', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      if (!mounted) return;
      setState(() {
        _recentNotifications = snap.docs.map((d) {
          final data = d.data();
          final type = data['type'] as String? ?? '';
          String action = 'feedback';
          if (type.contains('approved')) action = 'approved';
          if (type.contains('rejected')) action = 'rejected';
          return {
            'reviewer': (data['title'] as String? ?? '').split(' ').first,
            'task': data['body'] as String? ?? '',
            'action': action,
          };
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadDailyQuote() async {
    try {
      final quote = await QuotesService().getMotivationalQuote();
      if (mounted) setState(() => _dailyQuote = quote);
    } catch (_) {}
  }

  @override
  void dispose() {
    _assignedByMeSub?.cancel();
    _myTasksSub?.cancel();
    _scrollController.dispose();
    super.dispose();
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
              _lastLoadedState = state;
              // Reset selected day to today when a new session becomes active
              // (e.g. after restarting from history)
              final today = DateTime.now();
              if (!_isSameDay(_selectedDay, today)) {
                setState(() {
                  _selectedDay = today;
                });
              }
              // Load accountability statuses only once per session —
              // not on every ChallengeLoaded emission (e.g. task toggles),
              // which would cause repeated Firestore reads and rebuilds.
              // Mark as loaded only after success so failures can be retried.
              final sessionId = state.activeSession!.id;
              if (_accountabilityLoadedSessionId != sessionId) {
                _loadAccountabilityStatuses(
                  state.activeSession!.challenges,
                ).then((_) {
                  _accountabilityLoadedSessionId = sessionId;
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

          // Error / loading / initial — keep showing the last good screen so
          // a failed action never makes every task vanish.
          final cached = _lastLoadedState;
          if (cached != null && cached.hasActiveSession) {
            return _buildActiveSession(cached);
          }

          return _buildNoActiveSession();
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

    // --- Compute task data once ---
    if (_selectedDay.isBefore(session.startDate)) {
      _selectedDay = session.startDate;
    }
    final allProgress = state.currentProgress;
    final selectedProgress =
        allProgress.where((p) => _isSameDay(p.date, _selectedDay)).firstOrNull;
    final isToday = _isSameDay(_selectedDay, DateTime.now());
    final isFutureDate =
        _normalizeDate(_selectedDay).isAfter(_normalizeDate(DateTime.now()));
    final isBeforeStart = _normalizeDate(_selectedDay)
        .isBefore(_normalizeDate(session.startDate));
    final nonRegularChallenges =
        session.challenges.where((c) => c.taskType != 'regular').toList();

    // --- Build a flat list of widgets ---
    final List<Widget> items = [
      // 1. Greeting
      const GreetingHeader(),

      // 2. Hero card
      ChallengeHeroCard(
        currentDay: currentDay,
        totalDays: session.totalDaysTarget,
        currentStreak: _computeCurrentStreak(allProgress),
        bestStreak: _computeBestStreak(allProgress),
      ),
      const SizedBox(height: 8),

      // 3. Review notifications
      ..._recentNotifications.take(3).map((n) => ReviewNotificationCard(
            reviewerName: n['reviewer'] ?? '',
            taskName: n['task'] ?? '',
            action: n['action'] ?? 'approved',
            comment: n['comment'],
            onDismiss: () {
              setState(() => _recentNotifications.remove(n));
            },
          )),

      // 4. "Today's Tasks" section header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
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
                child: Icon(Icons.check_circle, color: Colors.green, size: 28),
              ),
          ],
        ),
      ),

      // 5. Task cards (or placeholder text)
      if (isBeforeStart)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Challenge hasn\'t started yet',
              style: TextStyle(color: Colors.grey)),
        )
      else if (isFutureDate)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Future date - complete today\'s tasks first!',
              style: TextStyle(color: Colors.grey)),
        )
      else
        ...nonRegularChallenges.map((challenge) {
          final isCompleted =
              selectedProgress?.challengeCompletions[challenge.id] ?? false;
          final child = _isWaterChallenge(challenge)
              ? _buildWaterTracker(challenge, isToday, selectedProgress)
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
                  onRemove: () => _handleRemoveTask(session, challenge),
                  onEdit: () => _showTaskSheet(context, challenge),
                  proofStatus: _proofStatuses[challenge.id],
                  accountabilityStatus: _accountabilityStatuses[challenge.id],
                  isReviewOnly: _reviewOnlyChallenges[challenge.id] ?? false,
                  onSubmitProof: () => _submitProof(challenge),
                  onReviewProof: () => _reviewProof(challenge),
                  onViewProof: () => _viewProof(challenge),
                  onProofRequired: () => _handleProofRequired(challenge),
                );
          return Padding(
            key: ValueKey(challenge.id),
            padding: const EdgeInsets.only(bottom: 4),
            child: child,
          );
        }),

      // 7. Motivation banner
      MotivationBanner(quote: _dailyQuote),

      // Bottom spacing for FAB
      const SizedBox(height: 120),
    ];

    return ListView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        try {
          return items[index];
        } catch (e) {
          debugPrint('HomeScreen item $index error: $e');
          return const SizedBox.shrink();
        }
      },
    );
  }

  void _showTaskSheet(
    BuildContext context,
    Challenge? challenge,
  ) {
    final bloc = context.read<ChallengeBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChallengeTaskSheet(bloc: bloc, challenge: challenge),
    );
  }

  void _handleRemoveTask(ChallengeSession session, Challenge challenge) {
    final remaining =
        session.challenges.where((c) => c.taskType != 'regular').length;
    if (remaining > 1) {
      context.read<ChallengeBloc>().add(
            RemoveChallengeFromSession(challenge.id),
          );
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Challenge?'),
        content: Text(
          '"${challenge.title}" is the only task in this challenge. '
          'Deleting it will end the challenge.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Challenge'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context.read<ChallengeBloc>().add(const EndActiveSession());
      }
    });
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

    // Save timestamps first so a stale rebuild doesn't overwrite them
    context.read<ChallengeBloc>().add(
          AddTaskNote(
            date: _selectedDay,
            challengeId: challenge.id,
            note: newString,
          ),
        );

    // Then update the overall completion boolean
    context.read<ChallengeBloc>().add(
          UpdateDailyProgress(
            date: _selectedDay,
            challengeId: challenge.id,
            isCompleted: isCompleted,
          ),
        );
  }

  /// Called on initial session load so DailyTaskCard shows correct review states.
  Future<void> _loadAccountabilityStatuses(List<Challenge> challenges) async {
    final svc = AccountabilityService();
    final myUid = svc.currentUid;

    for (final challenge in challenges) {
      try {
        // Single query returns the full task — avoids the extra
        // fetchTaskIdByChallengeId + fetchTaskById round-trip.
        final task = await svc.fetchTaskByChallengeId(challenge.id);
        if (task != null && mounted) {
          // A partner assigned this to me for review — I don't complete it.
          final reviewOnly = myUid != null &&
              task.accountableUid == myUid &&
              task.assignedByUid != myUid;

          // Partner approved my proof → the task is complete; mirror it onto
          // my local challenge so the Today card shows the checkmark.
          final partnerApproved =
              task.status == AccountabilityTaskStatus.completed ||
                  task.status == AccountabilityTaskStatus.approved;

          setState(() {
            _accountabilityStatuses[challenge.id] = task.status;
            _proofStatuses[challenge.id] = task.proofStatus;
            _reviewOnlyChallenges[challenge.id] = reviewOnly;
          });

          if (partnerApproved && !reviewOnly && mounted) {
            context.read<ChallengeBloc>().add(
                  UpdateDailyProgress(
                    date: _selectedDay,
                    challengeId: challenge.id,
                    isCompleted: true,
                  ),
                );
          }
        }
      } catch (_) {
        // Non-critical — card will just show default state
      }
    }
  }

  /// Called when user tries to toggle a task that has reviewers.
  /// Opens proof upload sheet instead of completing the task directly.
  /// On successful upload, submits for review via the AccountabilityBloc.
  /// OWNER-ONLY: reviewers get an explanatory message instead of the sheet.
  Future<void> _handleProofRequired(Challenge challenge) async {
    // Reviewer side: only the owner can add proof — never open the sheet.
    if (_reviewOnlyChallenges[challenge.id] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the task owner can add proof — you review it.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final svc = AccountabilityService();

    // Find or get the accountability task for this challenge
    final task = await svc.fetchTaskByChallengeId(challenge.id);
    final taskId = task?.id;
    if (taskId == null) {
      // No accountability task — fall back to normal proof submission
      _submitProof(challenge);
      return;
    }

    // Extra guard: only the owner (assigner) may submit proof.
    final myUid = svc.currentUid;
    if (task != null && myUid != null && task.assignedByUid != myUid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the task owner can add proof — you review it.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    final result = await PhotoProofSheet.show(
      context: context,
      taskId: taskId,
      taskName: challenge.title,
      date: _selectedDay,
    );

    if (result == true && mounted) {
      // Get the proof URL from the updated task
      final updated = await svc.fetchTaskById(taskId);
      if (updated?.proofUrl != null && mounted) {
        // Submit proof for review via BLoC — notifies all reviewers
        context.read<AccountabilityBloc>().add(
              SubmitProofForReview(
                taskId: taskId,
                challengeId: challenge.id,
                proofUrl: updated!.proofUrl!,
              ),
            );
        setState(() {
          _proofStatuses[challenge.id] = ProofStatus.submitted;
          _accountabilityStatuses[challenge.id] =
              AccountabilityTaskStatus.pendingReview;
        });
      }
    }
  }

  Future<void> _submitProof(Challenge challenge) async {
    // Owner-only: reviewers must not upload proof.
    if (_reviewOnlyChallenges[challenge.id] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the task owner can add proof — you review it.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final svc = AccountabilityService();
    final taskId = await svc.fetchTaskIdByChallengeId(challenge.id);
    if (taskId == null) {
      // Never fail silently — the camera button must always give feedback.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not find the linked review task. Pull to refresh and try again.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
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
    // Reviewer-only: the owner cannot approve their own proof.
    final myUid = svc.currentUid;
    final iAmReviewer = myUid != null &&
        task.assignedByUid != myUid &&
        (task.accountableUid == myUid ||
            task.accountableUserIds.contains(myUid) ||
            task.partnerUid == myUid);
    if (!iAmReviewer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the assigned reviewer can review this proof.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

  int _computeCurrentStreak(List<DailyProgress> progress) {
    int streak = 0;
    final sorted = [...progress]..sort((a, b) => b.date.compareTo(a.date));
    for (final p in sorted) {
      if (p.isCompleted) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeBestStreak(List<DailyProgress> progress) {
    int best = 0;
    int current = 0;
    final sorted = [...progress]..sort((a, b) => a.date.compareTo(b.date));
    for (final p in sorted) {
      if (p.isCompleted) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
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
}
