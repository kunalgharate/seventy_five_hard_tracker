import '../models/regular_task.dart';
import '../models/regular_task_completion.dart';
import '../repositories/database_repository.dart';
import '../repositories/regular_task_repository.dart';

/// One-time migration service to move existing regular tasks from ChallengeSession
/// into the new independent RegularTask storage.
///
/// The migration is idempotent — safe to run multiple times. A `hasMigrated` flag
/// in the Hive settings box prevents re-running on subsequent launches.
class RegularTaskMigrationService {
  static const String _hasMigratedKey = 'regular_tasks_migrated';

  /// Returns true if migration has already been completed.
  static bool hasMigrated(DatabaseRepository challengeRepo) {
    return challengeRepo.getSetting<bool>(_hasMigratedKey) ?? false;
  }

  /// Runs the one-time migration of regular tasks from the Challenge system
  /// to the independent Regular Task system.
  ///
  /// Steps:
  /// 1. Find all sessions containing regular tasks
  /// 2. Check if already migrated (idempotent — skip if task ID exists)
  /// 3. Create RegularTask from each Challenge with taskType 'regular'
  /// 4. Copy completion data from DailyProgress to RegularTaskCompletion
  /// 5. Remove regular tasks from active ChallengeSession challenges list
  static Future<void> migrateRegularTasks(
    DatabaseRepository challengeRepo,
    RegularTaskRepository regularRepo,
  ) async {
    // Step 1: Find all sessions that contain regular tasks
    final allSessions = challengeRepo.getAllSessions();

    for (final session in allSessions) {
      final regularChallenges =
          session.challenges.where((c) => c.taskType == 'regular').toList();

      for (final challenge in regularChallenges) {
        // Step 2: Check if already migrated (idempotent)
        final existing = regularRepo.getTaskById(challenge.id);
        if (existing != null) continue;

        // Step 3: Create RegularTask from Challenge
        final regularTask = RegularTask(
          id: challenge.id,
          title: challenge.title,
          reminderTime: challenge.reminderTime,
          isReminderEnabled: challenge.isReminderEnabled,
          imagePath: challenge.imagePath,
          iconName: challenge.iconName,
          iconColor: challenge.iconColor,
          category: challenge.category,
          reminderType: challenge.reminderType,
          reminderStartHour: challenge.reminderStartHour,
          reminderEndHour: challenge.reminderEndHour,
          allowNightReminders: challenge.allowNightReminders,
          reminderIntervalMinutes: challenge.reminderIntervalMinutes,
          createdAt: session.startDate,
          isArchived: !session.isActive,
        );

        await regularRepo.saveTask(regularTask);
      }

      // Step 4: Migrate completion data from DailyProgress
      if (session.isActive) {
        final progressList =
            challengeRepo.getProgressForSession(session.startDate);
        for (final progress in progressList) {
          var completion = regularRepo.getCompletion(progress.date);
          final taskCompletions = <String, bool>{};

          for (final challenge in regularChallenges) {
            final wasCompleted =
                progress.challengeCompletions[challenge.id] ?? false;
            taskCompletions[challenge.id] = wasCompleted;
          }

          if (taskCompletions.isNotEmpty) {
            completion = RegularTaskCompletion(
              date: progress.date,
              taskCompletions: {
                ...?completion?.taskCompletions,
                ...taskCompletions,
              },
            );
            await regularRepo.saveCompletion(completion);
          }
        }
      }
    }

    // Step 5: Remove regular tasks from active session's challenge list
    final activeSession = await challengeRepo.getActiveSession();
    if (activeSession != null) {
      final nonRegularChallenges = activeSession.challenges
          .where((c) => c.taskType != 'regular')
          .toList();
      if (nonRegularChallenges.length != activeSession.challenges.length) {
        final cleaned =
            activeSession.copyWith(challenges: nonRegularChallenges);
        await challengeRepo.updateSession(cleaned);
      }
    }

    // Set the hasMigrated flag so we skip on subsequent launches
    await challengeRepo.saveSetting(_hasMigratedKey, true);
  }
}
