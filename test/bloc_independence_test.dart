/// Property Test: BLoC bidirectional independence
///
/// For any sequence of events dispatched to the RegularTaskBloc, the
/// ChallengeBloc state SHALL remain unchanged, and for any sequence of
/// events dispatched to the ChallengeBloc, the RegularTaskBloc state
/// SHALL remain unchanged. Toggling a regular task completion never
/// triggers ChallengeReset or modifies DailyProgress.
///
/// **Validates: Requirements 3.3, 3.4, 9.1**
library bloc_independence_test;

import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';

/// Snapshot of a Hive box's contents for comparison.
class BoxSnapshot<T> {
  final Map<dynamic, T> entries;
  BoxSnapshot(Box<T> box)
      : entries = {for (final key in box.keys) key: box.get(key) as T};

  bool isEqualTo(BoxSnapshot<T> other) {
    if (entries.length != other.entries.length) return false;
    for (final key in entries.keys) {
      if (!other.entries.containsKey(key)) return false;
      if (entries[key] != other.entries[key]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'BoxSnapshot(${entries.length} entries: ${entries.keys})';
}

String _randomString(Random rng, {int maxLength = 20}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final length = rng.nextInt(maxLength) + 1;
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

RegularTask _randomRegularTask(Random rng) {
  const categories = ['general', 'health', 'fitness', 'learning'];
  const reminderTypes = ['once', 'hourly', 'custom'];
  return RegularTask(
    id: _randomString(rng, maxLength: 15),
    title: _randomString(rng, maxLength: 50),
    reminderTime: rng.nextBool()
        ? '${rng.nextInt(24).toString().padLeft(2, '0')}:${rng.nextInt(60).toString().padLeft(2, '0')}'
        : null,
    isReminderEnabled: rng.nextBool(),
    category: categories[rng.nextInt(categories.length)],
    reminderType: reminderTypes[rng.nextInt(reminderTypes.length)],
    reminderStartHour: rng.nextInt(24),
    reminderEndHour: rng.nextInt(24),
    allowNightReminders: rng.nextBool(),
    createdAt: DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28)),
    isArchived: false,
  );
}

RegularTaskCompletion _randomCompletion(Random rng, List<String> taskIds) {
  final date = DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28));
  final completions = <String, bool>{};
  for (final id in taskIds) {
    completions[id] = rng.nextBool();
  }
  return RegularTaskCompletion(date: date, taskCompletions: completions);
}

void main() {
  late Directory tempDir;
  late Box<ChallengeSession> sessionBox;
  late Box<DailyProgress> progressBox;
  late RegularTaskRepository regularRepo;
  late DatabaseRepository challengeRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_bloc_independence_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChallengeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DailyProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ChallengeSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(RegularTaskAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(RegularTaskCompletionAdapter());
    }

    // Open challenge system boxes directly for snapshot comparison
    sessionBox = await Hive.openBox<ChallengeSession>('challenge_sessions');
    progressBox = await Hive.openBox<DailyProgress>('daily_progress');

    // Initialize both repositories
    regularRepo = RegularTaskRepository();
    await regularRepo.init();

    challengeRepo = DatabaseRepository();
    await challengeRepo.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Property 3: BLoC bidirectional independence', () {
    // ── Direction 1: RegularTask ops → Challenge system unchanged ──

    test(
      'Validates: Requirements 3.3, 3.4, 9.1 — '
      'random RegularTaskRepository operations never modify '
      'challenge_sessions or daily_progress',
      () async {
        final rng = Random(42);

        // Seed challenge system with realistic data
        final seedSession = ChallengeSession(
          id: 'session_1',
          challenges: const [
            Challenge(id: 'c1', title: 'Read 30 pages', taskType: 'hard'),
            Challenge(id: 'c2', title: 'Workout', taskType: 'hard'),
            Challenge(id: 'c3', title: 'Drink water', taskType: 'soft'),
          ],
          startDate: DateTime(2024, 1, 1),
          isActive: true,
          isCompleted: false,
          currentDay: 10,
        );
        await challengeRepo.saveSession(seedSession);

        final seedProgress = DailyProgress(
          date: DateTime(2024, 1, 5),
          challengeCompletions: const {'c1': true, 'c2': false, 'c3': true},
          isCompleted: false,
        );
        await challengeRepo.saveDailyProgress(seedProgress);

        // Snapshot challenge boxes BEFORE
        final sessionBefore = BoxSnapshot(sessionBox);
        final progressBefore = BoxSnapshot(progressBox);

        // Perform random RegularTaskRepository operations
        final taskIds = <String>[];
        for (int i = 0; i < 100; i++) {
          final op = rng.nextInt(5);
          switch (op) {
            case 0:
              final task = _randomRegularTask(rng);
              await regularRepo.saveTask(task);
              taskIds.add(task.id);
              break;
            case 1:
              if (taskIds.isNotEmpty) {
                await regularRepo
                    .deleteTask(taskIds[rng.nextInt(taskIds.length)]);
              }
              break;
            case 2:
              if (taskIds.isNotEmpty) {
                await regularRepo
                    .archiveTask(taskIds[rng.nextInt(taskIds.length)]);
              }
              break;
            case 3:
              if (taskIds.isNotEmpty) {
                final completion = _randomCompletion(rng, taskIds);
                await regularRepo.saveCompletion(completion);
              }
              break;
            case 4:
              final date =
                  DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28));
              regularRepo.getCompletion(date);
              break;
          }
        }

        // Snapshot challenge boxes AFTER
        final sessionAfter = BoxSnapshot(sessionBox);
        final progressAfter = BoxSnapshot(progressBox);

        expect(sessionAfter.isEqualTo(sessionBefore), isTrue,
            reason: 'challenge_sessions changed after RegularTask operations');
        expect(progressAfter.isEqualTo(progressBefore), isTrue,
            reason: 'daily_progress changed after RegularTask operations');
      },
    );

    // ── Direction 2: Challenge system ops → RegularTask system unchanged ──

    test(
      'Validates: Requirements 3.3, 3.4, 9.1 — '
      'random DatabaseRepository operations never modify '
      'regular_tasks or regular_task_completions',
      () async {
        final rng = Random(99);

        // Seed regular task system with data
        final seedTasks = <String>[];
        for (int i = 0; i < 10; i++) {
          final task = _randomRegularTask(rng);
          await regularRepo.saveTask(task);
          seedTasks.add(task.id);
        }
        for (int i = 0; i < 5; i++) {
          final completion = _randomCompletion(rng, seedTasks);
          await regularRepo.saveCompletion(completion);
        }

        // Snapshot regular task boxes BEFORE
        final regularTasksBox = Hive.box<RegularTask>('regular_tasks');
        final regularCompletionsBox =
            Hive.box<RegularTaskCompletion>('regular_task_completions');
        final tasksBefore = BoxSnapshot(regularTasksBox);
        final completionsBefore = BoxSnapshot(regularCompletionsBox);

        // Perform random DatabaseRepository operations
        for (int i = 0; i < 100; i++) {
          final op = rng.nextInt(5);
          switch (op) {
            case 0: // saveSession
              final session = ChallengeSession(
                id: 'rand_session_$i',
                challenges: [
                  Challenge(
                    id: 'ch_$i',
                    title: _randomString(rng),
                    taskType: rng.nextBool() ? 'hard' : 'soft',
                  ),
                ],
                startDate:
                    DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28)),
                isActive: false,
                isCompleted: rng.nextBool(),
                currentDay: rng.nextInt(75) + 1,
              );
              await challengeRepo.saveSession(session);
              break;
            case 1: // saveDailyProgress
              final progress = DailyProgress(
                date: DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28)),
                challengeCompletions: {'ch_0': rng.nextBool()},
                isCompleted: rng.nextBool(),
              );
              await challengeRepo.saveDailyProgress(progress);
              break;
            case 2: // updateSession
              final session = ChallengeSession(
                id: 'rand_session_${rng.nextInt(i + 1)}',
                challenges: const [
                  Challenge(id: 'ch_upd', title: 'Updated', taskType: 'hard'),
                ],
                startDate: DateTime(2024, 3, 1),
                isActive: false,
                isCompleted: true,
                currentDay: 75,
              );
              await challengeRepo.updateSession(session);
              break;
            case 3: // getDailyProgress (read)
              challengeRepo.getDailyProgress(
                  DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28)));
              break;
            case 4: // getAllSessions (read)
              challengeRepo.getAllSessions();
              break;
          }
        }

        // Snapshot regular task boxes AFTER
        final tasksAfter = BoxSnapshot(regularTasksBox);
        final completionsAfter = BoxSnapshot(regularCompletionsBox);

        expect(tasksAfter.isEqualTo(tasksBefore), isTrue,
            reason:
                'regular_tasks changed after DatabaseRepository operations');
        expect(completionsAfter.isEqualTo(completionsBefore), isTrue,
            reason:
                'regular_task_completions changed after DatabaseRepository operations');
      },
    );

    // ── Specific: toggling regular task completion never modifies DailyProgress ──

    test(
      'Validates: Requirements 3.3, 3.4, 9.1 — '
      'toggling regular task completions never modifies DailyProgress',
      () async {
        final rng = Random(123);

        // Set up an active challenge session with daily progress
        final session = ChallengeSession(
          id: 'active_session',
          challenges: const [
            Challenge(id: 'hard_1', title: 'Workout', taskType: 'hard'),
            Challenge(id: 'hard_2', title: 'Read', taskType: 'hard'),
          ],
          startDate: DateTime(2024, 6, 1),
          isActive: true,
          isCompleted: false,
          currentDay: 5,
        );
        await challengeRepo.saveSession(session);

        // Create daily progress for several days
        for (int d = 0; d < 5; d++) {
          final date = DateTime(2024, 6, 1 + d);
          final progress = DailyProgress(
            date: date,
            challengeCompletions: {
              'hard_1': d.isEven,
              'hard_2': d.isOdd,
            },
            isCompleted: false,
          );
          await challengeRepo.saveDailyProgress(progress);
        }

        // Snapshot challenge boxes BEFORE toggling regular tasks
        final sessionBefore = BoxSnapshot(sessionBox);
        final progressBefore = BoxSnapshot(progressBox);

        // Create regular tasks and toggle their completions many times
        final regularTaskIds = <String>[];
        for (int i = 0; i < 10; i++) {
          final task = _randomRegularTask(rng);
          await regularRepo.saveTask(task);
          regularTaskIds.add(task.id);
        }

        // Simulate toggling regular task completions (what the BLoC does)
        for (int i = 0; i < 50; i++) {
          final taskId = regularTaskIds[rng.nextInt(regularTaskIds.length)];
          final date = DateTime(2024, 6, 1 + rng.nextInt(5));
          final normalizedDate = DateTime(date.year, date.month, date.day);

          var completion = regularRepo.getCompletion(normalizedDate);
          final updatedCompletions =
              Map<String, bool>.from(completion?.taskCompletions ?? {});
          updatedCompletions[taskId] = rng.nextBool();

          completion = RegularTaskCompletion(
            date: normalizedDate,
            taskCompletions: updatedCompletions,
          );
          await regularRepo.saveCompletion(completion);
        }

        // Snapshot challenge boxes AFTER
        final sessionAfter = BoxSnapshot(sessionBox);
        final progressAfter = BoxSnapshot(progressBox);

        // Challenge system must be completely unchanged
        expect(sessionAfter.isEqualTo(sessionBefore), isTrue,
            reason:
                'challenge_sessions changed after toggling regular task completions');
        expect(progressAfter.isEqualTo(progressBefore), isTrue,
            reason:
                'daily_progress changed after toggling regular task completions');

        // Also verify that regular task completions are stored in the right box
        for (int d = 0; d < 5; d++) {
          final date = DateTime(2024, 6, 1 + d);
          final regularCompletion = regularRepo.getCompletion(date);
          final challengeProgress = challengeRepo.getDailyProgress(date);

          // If regular completions exist for this date, they should only
          // contain regular task IDs, not challenge IDs
          if (regularCompletion != null) {
            for (final key in regularCompletion.taskCompletions.keys) {
              expect(regularTaskIds.contains(key), isTrue,
                  reason:
                      'Regular completion contains non-regular task ID: $key');
            }
          }

          // Challenge progress should only contain challenge IDs
          if (challengeProgress != null) {
            for (final key in challengeProgress.challengeCompletions.keys) {
              expect(['hard_1', 'hard_2'].contains(key), isTrue,
                  reason: 'Challenge progress contains non-challenge ID: $key');
            }
          }
        }
      },
    );

    // ── Interleaved: simultaneous operations on both systems ──

    test(
      'Validates: Requirements 3.3, 3.4, 9.1 — '
      'interleaved operations on both systems preserve mutual independence',
      () async {
        final rng = Random(777);

        // Seed both systems
        final seedSession = ChallengeSession(
          id: 'interleave_session',
          challenges: const [
            Challenge(id: 'h1', title: 'Hard Task', taskType: 'hard'),
          ],
          startDate: DateTime(2024, 3, 1),
          isActive: true,
          isCompleted: false,
          currentDay: 1,
        );
        await challengeRepo.saveSession(seedSession);

        final seedRegularTask = RegularTask(
          id: 'rt_seed',
          title: 'Seed Regular Task',
          category: 'general',
          reminderType: 'once',
          reminderStartHour: 8,
          reminderEndHour: 22,
          allowNightReminders: true,
          createdAt: DateTime(2024, 3, 1),
        );
        await regularRepo.saveTask(seedRegularTask);

        // Snapshot both systems BEFORE interleaved operations
        final sessionBefore = BoxSnapshot(sessionBox);
        //final progressBefore = BoxSnapshot(progressBox);
        final regularTasksBox = Hive.box<RegularTask>('regular_tasks');
        final regularCompletionsBox =
            Hive.box<RegularTaskCompletion>('regular_task_completions');
        final rtBefore = BoxSnapshot(regularTasksBox);
        //final rcBefore = BoxSnapshot(regularCompletionsBox);

        // Interleave: challenge op, then regular op, alternating
        final regularTaskIds = <String>['rt_seed'];
        for (int i = 0; i < 50; i++) {
          // Challenge system operation
          if (i.isEven) {
            final progress = DailyProgress(
              date: DateTime(2024, 3, 1 + (i ~/ 2)),
              challengeCompletions: {'h1': rng.nextBool()},
              isCompleted: rng.nextBool(),
            );
            await challengeRepo.saveDailyProgress(progress);
          } else {
            // Regular task system operation
            final task = _randomRegularTask(rng);
            await regularRepo.saveTask(task);
            regularTaskIds.add(task.id);

            final completion = _randomCompletion(rng, regularTaskIds);
            await regularRepo.saveCompletion(completion);
          }
        }

        // Snapshot both systems AFTER
        final sessionAfter = BoxSnapshot(sessionBox);
        final rtAfter = BoxSnapshot(regularTasksBox);

        // Challenge sessions should be unchanged (we only added progress, not sessions)
        expect(sessionAfter.isEqualTo(sessionBefore), isTrue,
            reason: 'challenge_sessions changed during interleaved operations');

        // Regular tasks should have grown (we added tasks)
        // But the ORIGINAL seed task should still be there unchanged
        expect(rtAfter.entries.containsKey('rt_seed'), isTrue,
            reason: 'Seed regular task disappeared during interleaved ops');
        expect(rtAfter.entries['rt_seed'], equals(rtBefore.entries['rt_seed']),
            reason: 'Seed regular task was modified during interleaved ops');

        // Verify no cross-contamination: regular task IDs should not appear
        // in daily_progress, and challenge IDs should not appear in
        // regular_task_completions
        final allProgressKeys = progressBox.keys.toList();
        final allRegCompKeys = regularCompletionsBox.keys.toList();

        for (final key in allProgressKeys) {
          final progress = progressBox.get(key);
          if (progress != null) {
            for (final cId in progress.challengeCompletions.keys) {
              expect(regularTaskIds.contains(cId), isFalse,
                  reason: 'Regular task ID "$cId" found in daily_progress');
            }
          }
        }

        for (final key in allRegCompKeys) {
          final comp = regularCompletionsBox.get(key);
          if (comp != null) {
            for (final tId in comp.taskCompletions.keys) {
              expect(tId == 'h1', isFalse,
                  reason:
                      'Challenge ID "h1" found in regular_task_completions');
            }
          }
        }
      },
    );
  });
}
