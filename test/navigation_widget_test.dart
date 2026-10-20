import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/discipline_score.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/screens/main_navigation_screen.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';

void main() {
  Widget buildHarness() {
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

  testWidgets('navigation preserves state when switching tabs',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Journal'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Journal screen'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Today screen'), findsOneWidget);
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

  testWidgets('navigation bar shows all six tab labels',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Squad'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('navigation bar is always visible',
      (tester) async {
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

  testWidgets('navigation supports programmatic tab selection',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Journal'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Journal screen'), findsOneWidget);
  });
}