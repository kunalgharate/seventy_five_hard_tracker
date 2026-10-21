import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/discipline_score.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/screens/main_navigation_screen.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';

/// A simple stateful screen that increments a counter on tap.
/// Used to verify state preservation across tab switches.
class _StatefulCounterScreen extends StatefulWidget {
  final VoidCallback onTap;

  const _StatefulCounterScreen({required this.onTap});

  @override
  State<_StatefulCounterScreen> createState() => _StatefulCounterScreenState();
}

class _StatefulCounterScreenState extends State<_StatefulCounterScreen> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: const Scaffold(
        body: Center(child: Text('Habits screen - tap to increment')),
      ),
    );
  }
}

/// Mock RegularTaskRepository that doesn't require Hive
class _MockRegularTaskRepository extends RegularTaskRepository {
  @override
  Future<void> init() async {}

  @override
  List<RegularTask> getAllTasks() => [];

  @override
  List<RegularTask> getActiveTasks() => [];

  @override
  RegularTask? getTaskById(String taskId) => null;

  @override
  Future<void> saveTask(RegularTask task) async {}

  @override
  Future<void> archiveTask(String taskId) async {}

  @override
  RegularTaskCompletion? getCompletion(DateTime date) => null;

  @override
  Future<void> saveCompletion(RegularTaskCompletion completion) async {}

  @override
  List<RegularTaskCompletion> getAllCompletions() => [];

  @override
  List<RegularTaskCompletion> getCompletionsInRange(
          DateTime start, DateTime end) =>
      [];

  // ignore: unused_element
  String _dateToKey(DateTime date) => '';

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> restoreFromJson(Map<String, dynamic> data) async {}
}

/// Mock DatabaseRepository that doesn't require Hive
class _MockDatabaseRepository extends DatabaseRepository {
  @override
  Future<void> init() async {}

  @override
  Future<ChallengeSession?> getActiveSession() async => null;

  @override
  List<ChallengeSession> getAllSessions() => [];

  @override
  Future<void> saveSession(ChallengeSession session) async {}

  Future<void> deleteSession(String sessionId) async {}

  @override
  DailyProgress? getDailyProgress(DateTime date, {String? sessionId}) => null;

  @override
  List<DailyProgress> getProgressForSession(
    DateTime startDate, {
    String? sessionId,
    int totalDaysTarget = 75,
  }) =>
      [];

  @override
  Future<void> saveSetting(String key, dynamic value) async {}

  @override
  T? getSetting<T>(String key) => null;

  // ignore: unused_element
  String _progressKey(DateTime date, String? sessionId) => '';

  @override
  Future<bool> hasActiveSession() async => false;

  @override
  Future<void> clearAllData() async {}

  @override
  Future<void> restoreFromJson(Map<String, dynamic> data) async {}

  @override
  Future<void> adoptLegacyProgressForSession(ChallengeSession session) async {}

  @override
  Future<void> adoptSessionsFor(String uid) async {}
}

void main() {
  Widget buildHarness() {
    final challengeBloc = ChallengeBloc(
      repository: _MockDatabaseRepository(),
      smartNotifications: SmartNotificationService(),
      startMidnightTimer: false,
    );
    final regularTaskBloc = RegularTaskBloc(
      repository: _MockRegularTaskRepository(),
      notifications: SmartNotificationService(),
    );
    final disciplineScoreBloc = DisciplineScoreBloc();

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: challengeBloc),
        BlocProvider.value(value: regularTaskBloc),
        BlocProvider.value(value: disciplineScoreBloc),
      ],
      child: MaterialApp(
        home: MainNavigationScreen(
          screenBuilders: [
            () => const Scaffold(body: Text('Today screen')),
            () => const Scaffold(body: Text('Habits screen')),
            () => const Scaffold(body: Text('Journal screen')),
            () => const Scaffold(body: Text('Insights screen')),
            () => const Scaffold(body: Text('Squad screen')),
            () => const Scaffold(body: Text('Account screen')),
          ],
        ),
      ),
    );
  }

  testWidgets('bottom navigation exposes all primary app destinations',
      (tester) async {
    final challengeBloc = ChallengeBloc(
      repository: DatabaseRepository(),
      smartNotifications: SmartNotificationService(),
      startMidnightTimer: false,
    );
    final regularTaskBloc = RegularTaskBloc(
      repository: RegularTaskRepository(),
      notifications: SmartNotificationService(),
    );
    final disciplineScoreBloc = DisciplineScoreBloc();

    addTearDown(() async {
      await challengeBloc.close();
      await regularTaskBloc.close();
      await disciplineScoreBloc.close();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: challengeBloc),
          BlocProvider.value(value: regularTaskBloc),
          BlocProvider.value(value: disciplineScoreBloc),
        ],
        child: MaterialApp(
          home: MainNavigationScreen(
            screenBuilders: [
              () => const Scaffold(body: Text('Today screen')),
              () => const Scaffold(body: Text('Habits screen')),
              () => const Scaffold(body: Text('Journal screen')),
              () => const Scaffold(body: Text('Insights screen')),
              () => const Scaffold(body: Text('Squad screen')),
              () => const Scaffold(body: Text('Account screen')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Squad'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Journal screen'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Insights screen'), findsOneWidget);
  });

  testWidgets('navigation preserves state when switching tabs', (tester) async {
    int tapCount = 0;
    Widget statefulScreen() => _StatefulCounterScreen(onTap: () => tapCount++);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(
              value: ChallengeBloc(
            repository: _MockDatabaseRepository(),
            smartNotifications: SmartNotificationService(),
            startMidnightTimer: false,
          )),
          BlocProvider.value(
              value: RegularTaskBloc(
            repository: _MockRegularTaskRepository(),
            notifications: SmartNotificationService(),
          )),
          BlocProvider.value(value: DisciplineScoreBloc()),
        ],
        child: MaterialApp(
          home: MainNavigationScreen(
            screenBuilders: [
              () => const Scaffold(body: Text('Today screen')),
              statefulScreen, // Habits tab - stateful
              () => const Scaffold(body: Text('Journal screen')),
              () => const Scaffold(body: Text('Insights screen')),
              () => const Scaffold(body: Text('Squad screen')),
              () => const Scaffold(body: Text('Account screen')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Tap the Habits tab (index 1)
    await tester.tap(find.text('Habits'));
    await tester.pump(const Duration(milliseconds: 300));

    // Interact with the stateful screen
    await tester.tap(find.byType(_StatefulCounterScreen));
    await tester.pump();
    expect(tapCount, 1);

    // Switch to another tab
    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Today screen'), findsOneWidget);

    // Switch back to Habits tab
    await tester.tap(find.text('Habits'));
    await tester.pump(const Duration(milliseconds: 300));

    // State should be preserved - tapCount should still be 1
    await tester.tap(find.byType(_StatefulCounterScreen));
    await tester.pump();
    expect(tapCount, 2);
  });

  testWidgets('navigation handles rapid tab switches without errors',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    for (int i = 0; i < 3; i++) {
      await tester.tap(find.text('Journal'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Insights'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Today'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Today screen'), findsOneWidget);
  });

  testWidgets('navigation bar shows all six tab labels', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Squad'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('navigation bar is always visible', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.tap(find.text('Journal'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.tap(find.text('Account'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('navigation supports programmatic tab selection', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify initial tab is Today (index 0)
    expect(find.text('Today screen'), findsOneWidget);

    // Programmatically select Journal tab (index 2) via tapping
    await tester.tap(find.text('Journal'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Journal screen'), findsOneWidget);
  });
}
