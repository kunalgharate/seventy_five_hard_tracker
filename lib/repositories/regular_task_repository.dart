import 'package:hive_flutter/hive_flutter.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';

class RegularTaskRepository {
  static const String _tasksBoxName = 'regular_tasks';
  static const String _completionsBoxName = 'regular_task_completions';

  Box<RegularTask>? _tasksBox;
  Box<RegularTaskCompletion>? _completionsBox;

  bool get _isInitialized => _tasksBox != null && _completionsBox != null;

  Future<void> init() async {
    if (_isInitialized) return;

    _tasksBox = await Hive.openBox<RegularTask>(_tasksBoxName);
    _completionsBox =
        await Hive.openBox<RegularTaskCompletion>(_completionsBoxName);
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // Task CRUD methods

  Future<void> saveTask(RegularTask task) async {
    await _ensureInitialized();
    await _tasksBox!.put(task.id, task);
  }

  /// Soft-deletes a task by setting isArchived to true.
  Future<void> deleteTask(String taskId) async {
    await _ensureInitialized();
    final task = _tasksBox!.get(taskId);
    if (task != null) {
      await _tasksBox!.put(taskId, task.copyWith(isArchived: true));
    }
  }

  Future<void> archiveTask(String taskId) async {
    await deleteTask(taskId);
  }

  List<RegularTask> getAllTasks() {
    return _tasksBox?.values.toList() ?? [];
  }

  List<RegularTask> getActiveTasks() {
    final tasks = _tasksBox?.values.where((t) => !t.isArchived).toList() ?? [];
    // Fix any tasks with empty IDs (legacy data bug)
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].id.isEmpty) {
        final newId =
            DateTime.now().millisecondsSinceEpoch.toString() + i.toString();
        final fixed = tasks[i].copyWith(id: newId);
        _tasksBox!.put(newId, fixed);
        _tasksBox!.delete('');
        tasks[i] = fixed;
      }
    }
    return tasks;
  }

  RegularTask? getTaskById(String taskId) {
    return _tasksBox?.get(taskId);
  }

  // Completion methods

  Future<void> saveCompletion(RegularTaskCompletion completion) async {
    await _ensureInitialized();
    final key = _dateToKey(completion.date);
    await _completionsBox!.put(key, completion);
  }

  RegularTaskCompletion? getCompletion(DateTime date) {
    final key = _dateToKey(date);
    return _completionsBox?.get(key);
  }

  /// Returns ALL stored completions — used by cloud backup to avoid
  /// the 365-day truncation bug that existed when iterating by date.
  List<RegularTaskCompletion> getAllCompletions() {
    return _completionsBox?.values.toList() ?? [];
  }

  List<RegularTaskCompletion> getCompletionsInRange(
      DateTime start, DateTime end) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final results = <RegularTaskCompletion>[];

    var current = normalizedStart;
    while (!current.isAfter(normalizedEnd)) {
      final completion = getCompletion(current);
      if (completion != null) {
        results.add(completion);
      }
      current = current.add(const Duration(days: 1));
    }

    return results;
  }

  // Utility methods

  String _dateToKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Restores regular tasks and completions from a cloud backup JSON payload.
  Future<void> restoreFromJson(Map<String, dynamic> data) async {
    await _ensureInitialized();

    // Restore tasks
    final tasks = (data['regularTasks'] as List?) ?? [];
    if (tasks.isNotEmpty) {
      await _tasksBox!.clear();
      for (final t in tasks) {
        final task = RegularTask.fromJson(t as Map<String, dynamic>);
        await _tasksBox!.put(task.id, task);
      }
    }

    // Restore completions
    final completions = (data['regularCompletions'] as List?) ?? [];
    if (completions.isNotEmpty) {
      await _completionsBox!.clear();
      for (final c in completions) {
        final completion =
            RegularTaskCompletion.fromJson(c as Map<String, dynamic>);
        await _completionsBox!.put(_dateToKey(completion.date), completion);
      }
    }
  }
}
