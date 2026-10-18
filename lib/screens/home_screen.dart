import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_notification_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/core/utils/notification_badge.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/widgets/reviews_tab.dart';
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

class _DisciplineScoreInputSignature extends Equatable {
  _DisciplineScoreInputSignature({
    required this.sessionId,
    required this.startDate,
    required this.totalDaysTarget,
    required this.today,
    required List<String> nonRegularChallengeIds,
    required List<_DisciplineProgressSignature> progress,
  })  : nonRegularChallengeIds = List.unmodifiable(nonRegularChallengeIds),
        progress = List.unmodifiable(progress);

  final String sessionId;
  final DateTime startDate;
  final int totalDaysTarget;
  final DateTime today;
  final List<String> nonRegularChallengeIds;
  final List<_DisciplineProgressSignature> progress;

  @override
  List<Object?> get props => [
        sessionId,
        startDate,
        totalDaysTarget,
        today,
        nonRegularChallengeIds,
        progress,
      ];
}

class _DisciplineProgressSignature extends Equatable {
  _DisciplineProgressSignature({
    required this.date,
    required this.isCompleted,
    required List<String> completedChallengeIds,
  }) : completedChallengeIds = List.unmodifiable(completedChallengeIds);

  final DateTime date;
  final bool isCompleted;
  final List<String> completedChallengeIds;

  @override
  List<Object?> get props => [date, isCompleted, completedChallengeIds];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onGoToSquad});

  final VoidCallback? onGoToSquad;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _selectedDay = DateTime.now();
  final Map<String, ProofStatus> _proofStatuses = {};
  final Map<String, AccountabilityTaskStatus> _accountabilityStatuses = {};

  /// challengeId -> latest linked accountability task. Kept so the card can
  /// date-scope the done-state (yesterday's approval is not today's).
  /// Same lifecycle as the status maps above (rebuilt from the streams).
  final Map<String, AccountabilityTask> _accountabilityTasks = {};

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

  _DisciplineScoreInputSignature? _lastDisciplineScoreInputSignature;

  /// Recent review notifications for inline display.
  List<Map<String, String>> _recentNotifications = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;

  /// Daily motivational quote.
  String _dailyQuote =
      'Discipline is choosing between what you want now and what you want most.';

  /// Set when the completion-toggle path shows its own error SnackBar so the
  /// BlocConsumer listener below doesn't surface the same failure twice.
  bool _errorSnackClaimed = false;

  // ignore: prefer_final_fields is intentional — updated after init

  /// Whether a challenge should render as a water tracker card.
  /// Only challenges explicitly categorized as 'water' use the tracker.
  bool _isWaterChallenge(Challenge challenge) => challenge.category == 'water';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ChallengeBloc>().add(LoadChallengeData());
    _subscribeToNotifications();
    _loadDailyQuote();
    _subscribeToAccountabilityStreams();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    _notificationsSub?.cancel();
    final uid = AccountabilityService().currentUid;
    if (uid == null) return;
    _notificationsSub = FirebaseFirestore.instance
        .collection('fcm_notifications')
        .where('recipientUid', isEqualTo: uid)
        .where('delivered', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) => _applyNotificationSnapshot(snap),
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('[HomeScreen] notification stream failed: $e');
        }
      },
    );
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
    final myUid = AccountabilityService().currentUid;
    final challengeBloc = context.read<ChallengeBloc>();
    for (final task in tasks) {
      final outcome = reviewOutcomeForOwnerTask(task, currentUid: myUid);
      if (outcome != null) challengeBloc.add(outcome);
    }

    final state = context.read<ChallengeBloc>().state;
    if (state is! ChallengeLoaded || !state.hasActiveSession) return;
    final challengeIds =
        state.activeSession!.challenges.map((c) => c.id).toSet();
    var changed = false;
    for (final task in tasks) {
      final cid = task.challengeId;
      if (cid == null || !challengeIds.contains(cid)) continue;
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
      _accountabilityTasks[cid] = task;
      // Only TODAY's approval completes local progress — yesterday's must
      // not check off the new day.
      final approved = task.isDoneToday;
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
      // Unread-only feed: docs the recipient has already seen (surfaced or
      // dismissed) fall out, so the bell badge reaches zero (BUG-01).
      // Counted over a wider window than the 3 inline cards.
      final snap = await FirebaseFirestore.instance
          .collection('fcm_notifications')
          .where('recipientUid', isEqualTo: uid)
          .where('delivered', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      _applyNotificationSnapshot(snap);
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeScreen] notification load failed: $e');
    }
  }

  void _applyNotificationSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      // Docs the user muted via notification prefs stay out of the cards.
      _recentNotifications = unreadDeliveredNotifications(
        snap.docs.map((doc) => {'id': doc.id, ...doc.data()}),
      ).map((data) {
        final notifData =
            (data['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        final type = AccountabilityNotificationService.canonicalTypeFromName(
            (notifData['type'] ?? data['type'] ?? '').toString());
        String action = 'feedback';
        if (type == 'review_approved') action = 'approved';
        if (type == 'review_rejected') action = 'rejected';
        return {
          'id': data['id'] as String? ?? '',
          'reviewer': (data['title'] as String? ?? '').split(' ').first,
          'task': data['body'] as String? ?? '',
          'action': action,
        };
      }).toList();
    });
  }

  /// Marks only the notifications shown in the inline cards as read.
  Future<void> _markNotificationsRead(
    List<Map<String, String>> surfacedNotifications,
  ) async {
    if (surfacedNotifications.isEmpty) return;
    final surfacedIds = surfacedNotifications
        .map((notification) => notification['id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (surfacedIds.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final notification in surfacedNotifications) {
      final id = notification['id'];
      if (id == null || id.isEmpty) continue;
      batch.update(
        FirebaseFirestore.instance.collection('fcm_notifications').doc(id),
        {'isRead': true, 'readAt': Timestamp.now()},
      );
    }
    if (mounted) {
      setState(() => _recentNotifications.removeWhere(
          (notification) => surfacedIds.contains(notification['id'])));
    }
    try {
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark notifications as read: $e')),
        );
      }
    }
  }

  Future<void> _dismissNotification(Map<String, String> notification) async {
    final id = notification['id'];
    if (id == null || id.isEmpty) return;
    final index = _recentNotifications.indexOf(notification);
    if (mounted) {
      setState(() => _recentNotifications.remove(notification));
    }
    try {
      await FirebaseFirestore.instance
          .collection('fcm_notifications')
          .doc(id)
          .update({'isRead': true, 'readAt': Timestamp.now()});
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!_recentNotifications.any((item) => item['id'] == id)) {
            _recentNotifications.insert(
              index.clamp(0, _recentNotifications.length),
              notification,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update notification: $e')),
        );
      }
    }
  }

  Future<void> _loadDailyQuote() async {
    try {
      final quote = await QuotesService().getMotivationalQuote();
      if (mounted) setState(() => _dailyQuote = quote);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsSub?.cancel();
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
                                      'Test notification scheduled for 5 seconds')),
                            );
                          }
                        },
                        child: const Text('5 Seconds'),
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
      floatingActionButton: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          final hasSession = (state is ChallengeLoaded &&
                  state.hasActiveSession) ||
              (_lastLoadedState != null && _lastLoadedState!.hasActiveSession);
          if (!hasSession) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'addChallengeTask',
            onPressed: () => _showTaskSheet(context, null),
            backgroundColor: Colors.orange[600],
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Task',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            tooltip: 'Add Task',
          );
        },
      ),
      body: BlocListener<DisciplineScoreBloc, DisciplineScoreState>(
        listenWhen: (previous, current) =>
            previous is! DisciplineScoreInitial &&
            current is DisciplineScoreInitial,
        listener: (context, state) {
          _lastDisciplineScoreInputSignature = null;
        },
        child: BlocConsumer<ChallengeBloc, ChallengeState>(
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
              } else if (state is ChallengeLoaded) {
                // No active session (sign-out / account switch cleared local
                // data) — drop the cached snapshot so stale data can never
                // reappear behind a later error/loading emission.
                _lastLoadedState = null;
              } else if (state is ChallengeError) {
                if (_errorSnackClaimed) {
                  // Already surfaced by the toggle path — just reset the flag.
                  _errorSnackClaimed = false;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
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
    final nonRegularChallengeIds = session.challenges
        .where((challenge) => challenge.taskType != 'regular')
        .map((challenge) => challenge.id)
        .toList();
    final nonRegularChallengeIdSet = nonRegularChallengeIds.toSet();
    final scoreInputs = _DisciplineScoreInputSignature(
      sessionId: session.id,
      startDate: _normalizeDate(session.startDate),
      totalDaysTarget: session.totalDaysTarget,
      today: _normalizeDate(DateTime.now()),
      nonRegularChallengeIds: nonRegularChallengeIds,
      progress: state.currentProgress.map((dayProgress) {
        final completedChallengeIds = dayProgress.challengeCompletions.entries
            .where((entry) =>
                entry.value && nonRegularChallengeIdSet.contains(entry.key))
            .map((entry) => entry.key)
            .toList()
          ..sort();
        return _DisciplineProgressSignature(
          date: _normalizeDate(dayProgress.date),
          isCompleted: dayProgress.isCompleted,
          completedChallengeIds: completedChallengeIds,
        );
      }).toList(),
    );
    final daysSinceStart =
        DateTime.now().difference(session.startDate).inDays + 1;
    final currentDay = daysSinceStart > 75 ? 75 : daysSinceStart;

    // Score inputs are stable across unrelated widget rebuilds. Dispatch only
    // when the session, score-relevant progress, or current day changes.
    if (scoreInputs != _lastDisciplineScoreInputSignature) {
      _lastDisciplineScoreInputSignature = scoreInputs;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scoreInputs == _lastDisciplineScoreInputSignature) {
          context.read<DisciplineScoreBloc>().add(CalculateDisciplineScore(
                session: session,
                progress: state.currentProgress,
              ));
        }
      });
    }

    // --- Compute task data once ---
    if (_selectedDay.isBefore(session.startDate)) {
      _selectedDay = session.startDate;
    }
    final allProgress = state.currentProgress;
    final selectedProgress =
        allProgress.where((p) => _isSameDay(p.date, _selectedDay)).firstOrNull;
    final streaks = _computeStreaks(allProgress);
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
      GreetingHeader(
        notificationCount: _recentNotifications.length,
        onNotificationTap: _openNotifications,
      ),

      // 2. Hero card
      ChallengeHeroCard(
        currentDay: currentDay,
        totalDays: session.totalDaysTarget,
        currentStreak: streaks.current,
        bestStreak: streaks.best,
      ),
      const SizedBox(height: 8),

      // 3. Review notifications
      ..._recentNotifications.take(3).map((n) => ReviewNotificationCard(
            reviewerName: n['reviewer'] ?? '',
            taskName: n['task'] ?? '',
            action: n['action'] ?? 'approved',
            comment: n['comment'],
            onDismiss: () => _dismissNotification(n),
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
                  onToggle: (completed) =>
                      _toggleCompletion(challenge, completed),
                  onReminderUpdate: (updatedChallenge) {
                    context.read<ChallengeBloc>().add(
                          UpdateChallenge(updatedChallenge),
                        );
                  },
                  onRemove: () => _handleRemoveTask(session, challenge),
                  onEdit: () => _showTaskSheet(context, challenge),
                  proofStatus: _proofStatuses[challenge.id],
                  accountabilityStatus: _accountabilityStatuses[challenge.id],
                  accountabilityDoneToday:
                      _accountabilityTasks[challenge.id]?.isDoneToday ?? true,
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

  /// Opens the app's notification surface — the Reviews screen, the same
  /// destination the Squad top-right button and notification taps use.
  /// Returning from it marks the surfaced notifications as read so the
  /// bell badge goes to zero (BUG-01: badge must reflect unread state).
  Future<void> _openNotifications() async {
    final bloc = context.read<AccountabilityBloc>();
    final surfacedNotifications = _recentNotifications.take(3).toList();
    final route = Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const Scaffold(
            appBar: CustomAppBar(title: 'Reviews'),
            body: ReviewsTabV2(),
          ),
        ),
      ),
    );
    await route;
    if (!mounted) return;
    unawaited(_markNotificationsRead(surfacedNotifications));
    unawaited(_loadRecentNotifications());
  }

  /// Saves a task toggle end-to-end. Shows a blocking progress dialog while
  /// the bloc runs its chain (Hive save → Firestore publish → notification
  /// reschedule), closes it as soon as the saved value is confirmed, and on
  /// failure closes it and surfaces a SnackBar — the checkbox only follows
  /// persisted state, so it never flips optimistically.
  Future<void> _toggleCompletion(Challenge challenge, bool completed) async {
    final bloc = context.read<ChallengeBloc>();
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        dialogContext = dialogCtx;
        return const _SavingProgressDialog();
      },
    );

    try {
      // `bloc.add` is fire-and-forget: subscribe to the state stream first so
      // the completion signal can't be missed, then dispatch the event.
      final confirmed = bloc.stream.firstWhere(
        (state) =>
            state is ChallengeError || _isSaved(state, challenge.id, completed),
      );
      bloc.add(
        UpdateDailyProgress(
          date: _selectedDay,
          challengeId: challenge.id,
          isCompleted: completed,
        ),
      );
      final state = await confirmed.timeout(const Duration(seconds: 10));
      if (state is ChallengeError) {
        _showToggleError(state.message);
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Still saving your progress — it has not been confirmed yet.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      _showToggleError('$error');
    } finally {
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      } else if (ctx == null && rootNavigator.canPop()) {
        // The save beat the dialog's first frame — pop through the navigator
        // we pushed on, otherwise a non-dismissible dialog would be stranded.
        rootNavigator.pop();
      }
    }
  }

  /// True when [state] already stores [value] for [challengeId] on the
  /// selected day — i.e. the persistence actually landed.
  bool _isSaved(ChallengeState state, String challengeId, bool value) {
    if (state is! ChallengeLoaded || !state.hasActiveSession) return false;
    for (final progress in state.currentProgress) {
      if (_isSameDay(progress.date, _selectedDay)) {
        return progress.challengeCompletions[challengeId] == value;
      }
    }
    return false;
  }

  /// Surfaces the toggle failure once — the BlocConsumer listener skips its
  /// own SnackBar when this path has already claimed the error.
  void _showToggleError(String message) {
    if (_errorSnackClaimed) {
      _errorSnackClaimed = false;
      return;
    }
    _errorSnackClaimed = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not save your progress — $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleRemoveTask(ChallengeSession session, Challenge challenge) {
    final remaining =
        session.challenges.where((c) => c.taskType != 'regular').length;
    if (remaining > 1) {
      context.read<ChallengeBloc>().add(
            RemoveChallengeFromSession(challenge.id),
          );
      // Immediate local feedback: the bloc persists the delete to Hive and
      // reloads, but that round-trip is silent — confirm now so offline
      // deletes feel applied. Failures still surface via the ChallengeError
      // listener below. No hardcoded color so the SnackBar follows the theme.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${challenge.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
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
          // Date-scoped: only today's approval completes today's progress.
          final partnerApproved = task.isDoneToday;

          setState(() {
            _accountabilityStatuses[challenge.id] = task.status;
            _proofStatuses[challenge.id] = task.proofStatus;
            _reviewOnlyChallenges[challenge.id] = reviewOnly;
            _accountabilityTasks[challenge.id] = task;
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
          _accountabilityTasks[challenge.id] = updated;
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
              'Could not find the linked review task. Please try again later.'),
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

  ({int current, int best}) _computeStreaks(List<DailyProgress> progress) {
    final sorted = [...progress]..sort((a, b) => b.date.compareTo(a.date));
    var current = 0;
    int best = 0;
    var sequence = 0;
    var scanningCurrent = true;

    for (final p in sorted) {
      if (p.isCompleted) {
        sequence++;
        if (sequence > best) best = sequence;
        if (scanningCurrent) current++;
      } else {
        sequence = 0;
        scanningCurrent = false;
      }
    }
    return (current: current, best: best);
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

/// Modal progress dialog shown while a completion toggle is being persisted.
/// Barrier taps and the system back button are blocked so the save chain can
/// finish; the caller pops it as soon as the bloc confirms the new value (or
/// the attempt fails).
class _SavingProgressDialog extends StatelessWidget {
  const _SavingProgressDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Saving your progress…',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'This keeps your daily streak accurate.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
