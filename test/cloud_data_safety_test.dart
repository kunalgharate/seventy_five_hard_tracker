import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';

void main() {
  group('cloud sign-out safety decisions', () {
    test('failed backup keeps local data and blocks sign-out', () {
      final decision = CloudSyncService.signOutStatusForBackup(false);

      expect(decision, SignOutPreparationStatus.backupFailed);
      expect(decision.maySignOut, isFalse);
      expect(decision.keepsLocalData, isTrue);
    });

    test('successful backup allows the caller to clear and sign out', () {
      final decision = CloudSyncService.signOutStatusForBackup(true);

      expect(decision, SignOutPreparationStatus.readyToSignOut);
      expect(decision.maySignOut, isTrue);
      expect(decision.keepsLocalData, isFalse);
    });
  });

  group('cloud restore payload detection', () {
    test('recognizes tasks-only, sessions-only, and empty backups', () {
      expect(
        CloudSyncService.hasRestorablePayload({'regularTasks': []}),
        isTrue,
      );
      expect(
        CloudSyncService.hasRestorablePayload({'sessions': []}),
        isTrue,
      );
      expect(
        CloudSyncService.hasRestorablePayload({
          'sessions': [],
          'regularTasks': [],
          'regularCompletions': [],
        }),
        isTrue,
      );
      expect(CloudSyncService.hasRestorablePayload({'syncedAt': 'today'}),
          isFalse);
    });
  });

  group('restore replacement semantics', () {
    late Directory tempDir;
    late RegularTaskRepository taskRepository;
    late DatabaseRepository databaseRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cloud_restore_test_');
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

      taskRepository = RegularTaskRepository();
      databaseRepository = DatabaseRepository();
      await taskRepository.init();
      await databaseRepository.init();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('tasks-only backup replaces tasks and preserves omitted completions',
        () async {
      final existingTask = _task('existing');
      final replacementTask = _task('replacement');
      await taskRepository.saveTask(existingTask);
      await taskRepository.saveCompletion(_completion('2026-01-01'));

      await taskRepository.restoreFromJson({
        'regularTasks': [replacementTask.toJson()],
      });

      expect(taskRepository.getAllTasks(), [replacementTask]);
      expect(taskRepository.getAllCompletions(), hasLength(1));
    });

    test('present empty arrays clear their collections', () async {
      await taskRepository.saveTask(_task('existing'));
      await taskRepository.saveCompletion(_completion('2026-01-01'));

      await taskRepository.restoreFromJson({
        'regularTasks': [],
        'regularCompletions': [],
      });

      expect(taskRepository.getAllTasks(), isEmpty);
      expect(taskRepository.getAllCompletions(), isEmpty);
    });

    test('sessions-only backup replaces sessions without touching tasks',
        () async {
      await taskRepository.saveTask(_task('keep-me'));
      await databaseRepository.saveSession(
        ChallengeSession(
          id: 'existing-session',
          challenges: const [],
          startDate: DateTime(2026, 1, 1),
          isActive: true,
          isCompleted: false,
          currentDay: 1,
        ),
      );
      final replacementSession = ChallengeSession(
        id: 'replacement-session',
        challenges: const [],
        startDate: DateTime(2026, 2, 1),
        isActive: false,
        isCompleted: true,
        currentDay: 75,
      );

      await databaseRepository.restoreFromJson({
        'sessions': [replacementSession.toJson()],
      });

      expect(taskRepository.getAllTasks(), hasLength(1));
      expect(databaseRepository.getAllSessions(), [replacementSession]);
    });
  });
}

RegularTask _task(String id) => RegularTask(
      id: id,
      title: id,
      createdAt: DateTime(2026, 1, 1),
    );

RegularTaskCompletion _completion(String date) => RegularTaskCompletion(
      date: DateTime.parse(date),
      taskCompletions: const {},
    );
