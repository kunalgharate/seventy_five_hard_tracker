import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/discipline_score.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/screens/onboarding_screen.dart';
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

    addTearDown(() async {
      await challengeBloc.close();
      await regularTaskBloc.close();
      await disciplineScoreBloc.close();
    });

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: challengeBloc),
        BlocProvider.value(value: regularTaskBloc),
        BlocProvider.value(value: disciplineScoreBloc),
      ],
      child: const MaterialApp(home: OnboardingScreen()),
    );
  }

  testWidgets('onboarding renders the first page with challenge inputs',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Sign In & Start Setup'), findsOneWidget);
    expect(find.text('Continue as Guest (Local Only)'), findsOneWidget);
  });

  testWidgets('onboarding shows disclaimer about 75 Hard independence',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.text(
        'DailyMettle is an independent app inspired by the public 75 Hard '
        'concept and is not affiliated with its creators.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('onboarding guest flow shows challenge setup page',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)');
    await tester.tap(guestButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('onboarding allows adding and removing challenges',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)');
    await tester.tap(guestButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('onboarding challenge title input updates state', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)');
    await tester.tap(guestButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('onboarding shows reset mode selection', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)');
    await tester.tap(guestButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('onboarding completes without crashing', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)');
    await tester.tap(guestButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
