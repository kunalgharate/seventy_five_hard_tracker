import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/services/regular_task_migration_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseRepository database;
  late RegularTaskRepository regularTasks;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('challenge_data_test_');
    Hive.init(tempDir.path);
    _registerAdapters();
    database = DatabaseRepository();
    regularTasks = RegularTaskRepository();
    await database.init();
    await regularTasks.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('daily progress is isolated between sessions on the same date',
      () async {
    final date = DateTime(2026, 10, 19);
    final first = _session('first', DateTime(2026, 10, 19));
    final second = _session('second', DateTime(2026, 10, 19));

    await database.saveSession(first);
    await database.saveSession(second);
    await database.saveDailyProgress(
      DailyProgress(
        date: date,
        sessionId: first.id,
        challengeCompletions: const {'task': true},
        isCompleted: true,
      ),
    );
    await database.saveDailyProgress(
      DailyProgress(
        date: date,
        sessionId: second.id,
        challengeCompletions: const {'task': false},
        isCompleted: false,
      ),
    );

    expect(
      database.getDailyProgress(date, sessionId: first.id)?.isCompleted,
      isTrue,
    );
    expect(
      database.getDailyProgress(date, sessionId: second.id)?.isCompleted,
      isFalse,
    );
    expect(
      database.getProgressForSession(
        first.startDate,
        sessionId: first.id,
      ),
      hasLength(1),
    );
  });

  test('progress lookup supports configurable challenge durations', () async {
    final session = _session('long', DateTime(2026, 1, 1), targetDays: 100);
    await database.saveSession(session);
    await database.saveDailyProgress(
      DailyProgress(
        date: DateTime(2026, 3, 21),
        sessionId: session.id,
        challengeCompletions: const {},
        isCompleted: true,
      ),
    );

    expect(
      database.getProgressForSession(
        session.startDate,
        sessionId: session.id,
        totalDaysTarget: session.totalDaysTarget,
      ),
      hasLength(1),
    );
  });

  test('legacy regular challenges migrate into independent habit storage',
      () async {
    const regular = Challenge(
      id: 'regular-1',
      title: 'Drink water',
      taskType: 'regular',
    );
    const hard = Challenge(
      id: 'hard-1',
      title: 'Workout',
      taskType: 'hard',
    );
    final session = ChallengeSession(
      id: 'legacy-session',
      challenges: const [regular, hard],
      startDate: DateTime(2026, 10, 19),
      isActive: true,
      isCompleted: false,
      currentDay: 1,
    );
    await database.saveSession(session);
    await database.saveDailyProgress(
      DailyProgress(
        date: session.startDate,
        sessionId: session.id,
        challengeCompletions: const {'regular-1': true, 'hard-1': true},
        isCompleted: true,
      ),
    );

    await RegularTaskMigrationService.migrateRegularTasks(
      database,
      regularTasks,
    );

    expect(regularTasks.getTaskById('regular-1'), isNotNull);
    expect(
      regularTasks
          .getCompletion(session.startDate)
          ?.taskCompletions['regular-1'],
      isTrue,
    );
    expect(
      (await database.getActiveSession())!.challenges,
      isNot(contains(regular)),
    );
  });
}

ChallengeSession _session(String id, DateTime startDate,
    {int targetDays = 75}) {
  return ChallengeSession(
    id: id,
    challenges: const [Challenge(id: 'task', title: 'Task')],
    startDate: startDate,
    isActive: true,
    isCompleted: false,
    currentDay: 1,
    totalDaysTarget: targetDays,
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ChallengeAdapter());
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyProgressAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(ChallengeSessionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(RegularTaskAdapter());
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(RegularTaskCompletionAdapter());
  }
}
