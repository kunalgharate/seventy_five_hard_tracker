/// Property Test: Repository data isolation
///
/// For any sequence of RegularTaskRepository operations (save, delete,
/// archive, toggle completion), the contents of the `challenge_sessions`
/// and `daily_progress` Hive boxes SHALL remain unchanged.
///
/// **Validates: Requirements 2.5, 1.1, 1.2**
library repository_data_isolation_test;

import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:seventy_five_hard_tracker/models/challenge.dart';
import 'package:seventy_five_hard_tracker/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';

/// Snapshot of a Hive box's contents for comparison.
class BoxSnapshot<T> {
  final Map<dynamic, T> entries;
  BoxSnapshot(Box<T> box)
      : entries = {for (final key in box.keys) key: box.get(key) as T};

  @override
  bool operator ==(Object other) {
    if (other is! BoxSnapshot<T>) return false;
    if (entries.length != other.entries.length) return false;
    for (final key in entries.keys) {
      if (!other.entries.containsKey(key)) return false;
      if (entries[key] != other.entries[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => entries.length.hashCode;

  @override
  String toString() =>
      'BoxSnapshot(${entries.length} entries: ${entries.keys})';
}

/// Generates a random non-empty string.
String _randomString(Random rng, {int maxLength = 20}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final length = rng.nextInt(maxLength) + 1;
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random RegularTask.
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

/// Generates a random RegularTaskCompletion.
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
  late RegularTaskRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_isolation_test_');
    Hive.init(tempDir.path);

    // Register all adapters (with guards)
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

    // Open the challenge system boxes
    sessionBox = await Hive.openBox<ChallengeSession>('challenge_sessions');
    progressBox = await Hive.openBox<DailyProgress>('daily_progress');

    // Create the repository (it will open its own boxes on init)
    repo = RegularTaskRepository();
    await repo.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Property 5: Repository data isolation', () {
    test(
      'Validates: Requirements 2.5, 1.1, 1.2 — '
      'random sequence of RegularTaskRepository operations never modifies '
      'challenge_sessions or daily_progress boxes',
      () async {
        final rng = Random(42);

        // Seed challenge system boxes with realistic data
        final seedSession = ChallengeSession(
          id: 'session_1',
          challenges: [
            const Challenge(id: 'c1', title: 'Read 30 pages', taskType: 'hard'),
            const Challenge(id: 'c2', title: 'Workout', taskType: 'hard'),
            const Challenge(id: 'c3', title: 'Drink water', taskType: 'soft'),
          ],
          startDate: DateTime(2024, 1, 1),
          isActive: true,
          isCompleted: false,
          currentDay: 10,
        );
        await sessionBox.put(seedSession.id, seedSession);

        final seedProgress = DailyProgress(
          date: DateTime(2024, 1, 5),
          challengeCompletions: {'c1': true, 'c2': false, 'c3': true},
          isCompleted: false,
        );
        await progressBox.put('2024-01-05', seedProgress);

        // Snapshot the challenge system boxes BEFORE any repo operations
        final sessionSnapshotBefore = BoxSnapshot(sessionBox);
        final progressSnapshotBefore = BoxSnapshot(progressBox);

        // Perform a random sequence of RegularTaskRepository operations
        final createdTaskIds = <String>[];

        for (int i = 0; i < 100; i++) {
          final op = rng.nextInt(
              5); // 0=save, 1=delete, 2=archive, 3=saveCompletion, 4=getCompletion

          switch (op) {
            case 0: // saveTask
              final task = _randomRegularTask(rng);
              await repo.saveTask(task);
              createdTaskIds.add(task.id);
              break;

            case 1: // deleteTask (archive)
              if (createdTaskIds.isNotEmpty) {
                final id = createdTaskIds[rng.nextInt(createdTaskIds.length)];
                await repo.deleteTask(id);
              }
              break;

            case 2: // archiveTask
              if (createdTaskIds.isNotEmpty) {
                final id = createdTaskIds[rng.nextInt(createdTaskIds.length)];
                await repo.archiveTask(id);
              }
              break;

            case 3: // saveCompletion
              if (createdTaskIds.isNotEmpty) {
                final completion = _randomCompletion(rng, createdTaskIds);
                await repo.saveCompletion(completion);
              }
              break;

            case 4: // getCompletion (read operation)
              final date =
                  DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28));
              repo.getCompletion(date);
              break;
          }
        }

        // Snapshot the challenge system boxes AFTER all repo operations
        final sessionSnapshotAfter = BoxSnapshot(sessionBox);
        final progressSnapshotAfter = BoxSnapshot(progressBox);

        // Verify challenge_sessions box is unchanged
        expect(sessionSnapshotAfter.entries.length,
            equals(sessionSnapshotBefore.entries.length),
            reason: 'challenge_sessions box entry count changed after '
                'RegularTaskRepository operations');
        for (final key in sessionSnapshotBefore.entries.keys) {
          expect(sessionSnapshotAfter.entries.containsKey(key), isTrue,
              reason: 'challenge_sessions key "$key" disappeared');
          expect(sessionSnapshotAfter.entries[key],
              equals(sessionSnapshotBefore.entries[key]),
              reason: 'challenge_sessions entry "$key" was modified');
        }

        // Verify daily_progress box is unchanged
        expect(progressSnapshotAfter.entries.length,
            equals(progressSnapshotBefore.entries.length),
            reason: 'daily_progress box entry count changed after '
                'RegularTaskRepository operations');
        for (final key in progressSnapshotBefore.entries.keys) {
          expect(progressSnapshotAfter.entries.containsKey(key), isTrue,
              reason: 'daily_progress key "$key" disappeared');
          expect(progressSnapshotAfter.entries[key],
              equals(progressSnapshotBefore.entries[key]),
              reason: 'daily_progress entry "$key" was modified');
        }
      },
    );

    test(
      'Validates: Requirements 2.5, 1.1, 1.2 — '
      'challenge_sessions box stays empty when no seed data exists '
      'and RegularTaskRepository operations are performed',
      () async {
        final rng = Random(99);

        // No seed data — both challenge boxes start empty
        expect(sessionBox.isEmpty, isTrue);
        expect(progressBox.isEmpty, isTrue);

        // Perform various repo operations
        for (int i = 0; i < 50; i++) {
          final task = _randomRegularTask(rng);
          await repo.saveTask(task);
        }
        for (int i = 0; i < 20; i++) {
          final completion = _randomCompletion(rng, ['t1', 't2', 't3']);
          await repo.saveCompletion(completion);
        }

        // Challenge boxes must still be empty
        expect(sessionBox.isEmpty, isTrue,
            reason: 'challenge_sessions should remain empty');
        expect(progressBox.isEmpty, isTrue,
            reason: 'daily_progress should remain empty');
      },
    );

    test(
      'Validates: Requirements 2.5, 1.1, 1.2 — '
      'RegularTaskRepository uses separate Hive boxes from challenge system',
      () async {
        // Save a task and a completion
        final task = RegularTask(
          id: 'isolation_test_task',
          title: 'Test Task',
          category: 'general',
          reminderType: 'once',
          reminderStartHour: 8,
          reminderEndHour: 22,
          allowNightReminders: true,
          createdAt: DateTime(2024, 6, 1),
        );
        await repo.saveTask(task);

        final completion = RegularTaskCompletion(
          date: DateTime(2024, 6, 1),
          taskCompletions: {'isolation_test_task': true},
        );
        await repo.saveCompletion(completion);

        // Verify the data is NOT in challenge system boxes
        expect(sessionBox.get('isolation_test_task'), isNull,
            reason: 'Task ID should not appear in challenge_sessions');
        expect(progressBox.get('2024-06-01'), isNull,
            reason: 'Completion date key should not appear in daily_progress');

        // Verify the data IS accessible through the repository
        expect(repo.getTaskById('isolation_test_task'), isNotNull);
        expect(repo.getCompletion(DateTime(2024, 6, 1)), isNotNull);
      },
    );

    test(
      'Validates: Requirements 2.5, 1.1, 1.2 — '
      'heavy interleaved save/delete/archive operations preserve '
      'challenge system data integrity',
      () async {
        final rng = Random(77);

        // Seed multiple sessions and progress entries
        for (int s = 0; s < 3; s++) {
          final session = ChallengeSession(
            id: 'session_$s',
            challenges: [
              Challenge(id: 'ch_${s}_0', title: 'Task A $s', taskType: 'hard'),
              Challenge(id: 'ch_${s}_1', title: 'Task B $s', taskType: 'soft'),
            ],
            startDate: DateTime(2024, 1 + s, 1),
            isActive: s == 0,
            isCompleted: s > 0,
            currentDay: s == 0 ? 5 : 75,
          );
          await sessionBox.put(session.id, session);
        }

        for (int d = 0; d < 5; d++) {
          final progress = DailyProgress(
            date: DateTime(2024, 1, 1 + d),
            challengeCompletions: {'ch_0_0': d.isEven, 'ch_0_1': d.isOdd},
            isCompleted: false,
          );
          final key = '2024-01-${(1 + d).toString().padLeft(2, '0')}';
          await progressBox.put(key, progress);
        }

        final sessionSnapshotBefore = BoxSnapshot(sessionBox);
        final progressSnapshotBefore = BoxSnapshot(progressBox);

        // Heavy interleaved operations
        final taskIds = <String>[];
        for (int i = 0; i < 50; i++) {
          final task = _randomRegularTask(rng);
          await repo.saveTask(task);
          taskIds.add(task.id);
        }
        // Delete half
        for (int i = 0; i < 25; i++) {
          await repo.deleteTask(taskIds[i]);
        }
        // Archive some
        for (int i = 25; i < 35; i++) {
          await repo.archiveTask(taskIds[i]);
        }
        // Save completions
        for (int i = 0; i < 30; i++) {
          final completion = _randomCompletion(rng, taskIds);
          await repo.saveCompletion(completion);
        }
        // Read operations
        repo.getAllTasks();
        repo.getActiveTasks();
        repo.getCompletionsInRange(
            DateTime(2024, 1, 1), DateTime(2024, 12, 31));

        // Verify challenge system boxes are unchanged
        final sessionSnapshotAfter = BoxSnapshot(sessionBox);
        final progressSnapshotAfter = BoxSnapshot(progressBox);

        expect(sessionSnapshotAfter.entries.length,
            equals(sessionSnapshotBefore.entries.length),
            reason: 'challenge_sessions entry count changed');
        expect(progressSnapshotAfter.entries.length,
            equals(progressSnapshotBefore.entries.length),
            reason: 'daily_progress entry count changed');

        for (final key in sessionSnapshotBefore.entries.keys) {
          expect(sessionSnapshotAfter.entries[key],
              equals(sessionSnapshotBefore.entries[key]),
              reason: 'challenge_sessions entry "$key" was modified');
        }
        for (final key in progressSnapshotBefore.entries.keys) {
          expect(progressSnapshotAfter.entries[key],
              equals(progressSnapshotBefore.entries[key]),
              reason: 'daily_progress entry "$key" was modified');
        }
      },
    );
  });
}
