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
  setUp(() {
    // Use a taller screen to accommodate the onboarding UI
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(800, 1400);
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.clearPhysicalSizeTestValue();
  });

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
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Sign In & Start Setup'), findsOneWidget);
    expect(find.text('Continue as Guest (Local Only)'), findsOneWidget);
  });

  testWidgets('onboarding shows disclaimer about 75 Hard independence',
      (tester) async {
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
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)').first;
    await tester.scrollUntilVisible(guestButton, 100);
    await tester.tap(guestButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // The heading is "Create Your Challenges" not "Your Challenges"
    expect(find.text('Create Your Challenges'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('onboarding allows adding and removing challenges',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)').first;
    await tester.scrollUntilVisible(guestButton, 100);
    await tester.tap(guestButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // The add button is an OutlinedButton with "Add Challenge (X/10)" text
    final initialFieldCount = find.byType(TextField).evaluate().length;

    await tester.tap(find.text('Add Challenge').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TextField), findsNWidgets(initialFieldCount + 1));

    // Delete is via a popup menu (more_vert icon) with "Remove Challenge"
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Remove Challenge'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TextField), findsNWidgets(initialFieldCount));
  });

  testWidgets('onboarding challenge title input updates state', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)').first;
    await tester.scrollUntilVisible(guestButton, 100);
    await tester.tap(guestButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, 'Exercise');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Exercise'), findsOneWidget);
  });

  testWidgets('onboarding shows reset mode selection', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)').first;
    await tester.scrollUntilVisible(guestButton, 100);
    await tester.tap(guestButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // The next button text is "Review My Challenges →"
    await tester.tap(find.text('Review My Challenges →').first);
    await tester.pump(const Duration(milliseconds: 500));

    // Reset mode uses SegmentedButton with "Hard" and "Soft" labels
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Soft'), findsOneWidget);
  });

  testWidgets('onboarding completes without crashing', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump(const Duration(seconds: 3));

    final guestButton = find.text('Continue as Guest (Local Only)').first;
    await tester.scrollUntilVisible(guestButton, 100);
    await tester.tap(guestButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, 'Test Challenge');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Review My Challenges →').first);
    await tester.pump(const Duration(milliseconds: 500));

    // Select "Hard" reset mode
    await tester.tap(find.text('Hard'));
    await tester.pump(const Duration(milliseconds: 300));

    // The next button on the reset mode page
    await tester.tap(find.text('Review My Challenges →').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
