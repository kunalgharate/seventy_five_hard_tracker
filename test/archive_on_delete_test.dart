/// Property Test: Archive-on-delete preserves records
///
/// For any RegularTask that is deleted via the RegularTaskRepository,
/// the task record SHALL still exist in storage with isArchived set to true,
/// and the task's completion history SHALL remain accessible.
///
/// **Validates: Requirement 2.4**
library archive_on_delete_test;

import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:seventy_five_hard_tracker/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';

/// Generates a random non-empty string.
String _randomString(Random rng, {int maxLength = 20}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final length = rng.nextInt(maxLength) + 1;
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random RegularTask with isArchived = false.
RegularTask _randomRegularTask(Random rng, {String? id}) {
  const categories = ['general', 'health', 'fitness', 'learning'];
  const reminderTypes = ['once', 'hourly', 'custom'];
  return RegularTask(
    id: id ?? _randomString(rng, maxLength: 15),
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

void main() {
  late Directory tempDir;
  late RegularTaskRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_archive_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(RegularTaskAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(RegularTaskCompletionAdapter());
    }

    repo = RegularTaskRepository();
    await repo.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Property 4: Archive-on-delete preserves records', () {
    test(
      'Validates: Requirement 2.4 — '
      'deleting a random task sets isArchived=true and preserves the record in getAllTasks',
      () async {
        final rng = Random(42);

        for (int trial = 0; trial < 100; trial++) {
          final task = _randomRegularTask(rng, id: 'task_$trial');
          await repo.saveTask(task);

          // Verify task is active before delete
          expect(repo.getTaskById(task.id)!.isArchived, isFalse,
              reason: 'Task $trial should not be archived before delete');

          // Delete the task
          await repo.deleteTask(task.id);

          // 1. The task still exists in storage (getAllTasks includes it)
          final allTasks = repo.getAllTasks();
          final found = allTasks.where((t) => t.id == task.id);
          expect(found.isNotEmpty, isTrue,
              reason:
                  'Task $trial should still exist in getAllTasks after delete');

          // 2. The task has isArchived=true
          final archivedTask = repo.getTaskById(task.id);
          expect(archivedTask, isNotNull,
              reason: 'Task $trial should be retrievable by ID after delete');
          expect(archivedTask!.isArchived, isTrue,
              reason: 'Task $trial should have isArchived=true after delete');

          // 3. Original fields are preserved
          expect(archivedTask.title, equals(task.title));
          expect(archivedTask.category, equals(task.category));
          expect(archivedTask.createdAt, equals(task.createdAt));

          // 4. getActiveTasks does NOT include the archived task
          final activeTasks = repo.getActiveTasks();
          final activeFound = activeTasks.where((t) => t.id == task.id);
          expect(activeFound.isEmpty, isTrue,
              reason:
                  'Task $trial should NOT appear in getActiveTasks after delete');
        }
      },
    );

    test(
      'Validates: Requirement 2.4 — '
      'completion history remains accessible after task deletion',
      () async {
        final rng = Random(99);

        for (int trial = 0; trial < 50; trial++) {
          final task = _randomRegularTask(rng, id: 'comp_task_$trial');
          await repo.saveTask(task);

          // Save completions for several random dates
          final numCompletions = 1 + rng.nextInt(5);
          final savedDates = <DateTime>[];
          for (int c = 0; c < numCompletions; c++) {
            final date =
                DateTime(2024, 1 + rng.nextInt(12), 1 + rng.nextInt(28));
            savedDates.add(date);
            final completion = RegularTaskCompletion(
              date: date,
              taskCompletions: {task.id: true},
            );
            await repo.saveCompletion(completion);
          }

          // Delete the task
          await repo.deleteTask(task.id);

          // Verify completion history is still accessible
          for (final date in savedDates) {
            final completion = repo.getCompletion(date);
            expect(completion, isNotNull,
                reason:
                    'Completion for task $trial on $date should still exist');
            expect(completion!.taskCompletions[task.id], isTrue,
                reason:
                    'Completion entry for task $trial should still be true');
          }
        }
      },
    );

    test(
      'Validates: Requirement 2.4 — '
      'batch delete: multiple tasks deleted, all preserved as archived '
      'and excluded from getActiveTasks',
      () async {
        final rng = Random(123);
        final taskIds = <String>[];

        // Create a batch of tasks
        final batchSize = 20 + rng.nextInt(30);
        for (int i = 0; i < batchSize; i++) {
          final task = _randomRegularTask(rng, id: 'batch_$i');
          await repo.saveTask(task);
          taskIds.add(task.id);
        }

        // Pick a random subset to delete
        final toDelete = <String>{};
        final deleteCount = 1 + rng.nextInt(batchSize);
        for (int i = 0; i < deleteCount; i++) {
          toDelete.add(taskIds[rng.nextInt(taskIds.length)]);
        }

        for (final id in toDelete) {
          await repo.deleteTask(id);
        }

        // All tasks should still exist in getAllTasks
        final allTasks = repo.getAllTasks();
        for (final id in taskIds) {
          expect(allTasks.any((t) => t.id == id), isTrue,
              reason: 'Task $id should still exist in getAllTasks');
        }

        // Deleted tasks should be archived
        for (final id in toDelete) {
          final task = repo.getTaskById(id);
          expect(task!.isArchived, isTrue,
              reason: 'Deleted task $id should be archived');
        }

        // Active tasks should exclude all deleted ones
        final activeTasks = repo.getActiveTasks();
        for (final id in toDelete) {
          expect(activeTasks.any((t) => t.id == id), isFalse,
              reason: 'Deleted task $id should not be in getActiveTasks');
        }

        // Non-deleted tasks should still be active
        final notDeleted = taskIds.where((id) => !toDelete.contains(id));
        for (final id in notDeleted) {
          expect(activeTasks.any((t) => t.id == id), isTrue,
              reason: 'Non-deleted task $id should still be in getActiveTasks');
        }
      },
    );
  });
}
