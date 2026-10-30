import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';

/// Shared storage keys. The Android widget code (widget/WidgetStore.kt) and
/// the iOS WidgetKit extension (DailyMettleWidget) read/write these exact keys
/// inside the shared home_widget store — `HomeWidgetPreferences` on Android,
/// the App Group UserDefaults on iOS. Keep all three sides in sync.
class WidgetKeys {
  /// JSON array shown by the widgets:
  /// [{id, title, completed, pending}]
  static const tasks = 'widget_tasks';

  /// Tasks created natively (Android quick-add dialog) that the app has not
  /// materialized into Hive yet:
  /// [{id, title, reminderTime ("once:HH:mm"|null), completed, createdAt}]
  static const pendingTasks = 'widget_pending_tasks';

  /// Completion toggles performed from a widget while the app was not
  /// running: [{taskId, completed, date ("YYYY-MM-DD")}]
  static const toggleEvents = 'widget_toggle_events';
}

/// Deep links emitted by the widgets. iOS URLs must carry a `homeWidget`
/// query item — the home_widget plugin uses it to recognize widget taps.
class WidgetLinks {
  static Uri get addTask => Uri.parse('dailymettle://add-task?homeWidget');
  static Uri get tasks => Uri.parse('dailymettle://tasks?homeWidget');
  static Uri toggle(String taskId) => Uri.parse('dailymettle://toggle/$taskId');
}

/// Bridge between the app and the home-screen widgets on iOS and Android.
///
/// The widgets never touch Hive directly. They render the `widget_tasks`
/// snapshot, queue native quick-adds into `widget_pending_tasks`, and journal
/// completion toggles into `widget_toggle_events`. This service owns all
/// reads/writes into Hive and keeps the widget snapshot in sync.
class WidgetBridgeService {
  WidgetBridgeService._();
  static final WidgetBridgeService instance = WidgetBridgeService._();

  /// App Group shared by the Runner target and the WidgetKit extension.
  static const String appGroupId = 'group.com.seventyfive.hard.challenge';
  static const String iOSWidgetName = 'DailyMettleWidget';

  /// Fully-qualified Kotlin class of the Android AppWidgetProvider. Passed via
  /// `qualifiedAndroidName` because the plugin resolves plain names against
  /// the applicationId (com.seventyfive.hard.challenge), not this namespace.
  static const String androidProviderClass =
      'com.example.seventy_five_hard_tracker.widget.DailyTasksWidgetProvider';

  /// Registered by MainNavigationScreen so widget deep links can switch tabs
  /// and open the add-task sheet without going through named routes.
  VoidCallback? onOpenTasksTab;
  VoidCallback? onOpenAddTask;

  /// Fired whenever [drainWidgetChanges] applied widget-originated changes,
  /// so the UI layer can trigger a bloc reload.
  final _changesController = StreamController<void>.broadcast();
  Stream<void> get changes => _changesController.stream;

  StreamSubscription<Uri?>? _clickSub;
  Uri? _pendingLink;
  bool _initialized = false;

  /// Registers the interactivity callback, subscribes to widget taps and
  /// performs the initial drain. Safe to call once from main().
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      await HomeWidget.registerInteractivityCallback(_widgetToggleCallback);
      _clickSub = HomeWidget.widgetClicked.listen(_handleLink);
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchUri != null) _handleLink(launchUri);
    } catch (e) {
      debugPrint('[WidgetBridge] init failed: $e');
    }
  }

  /// Called by MainNavigationScreen once it can react to widget links.
  void registerNavigationHandlers({
    required VoidCallback openTasksTab,
    required VoidCallback openAddTask,
  }) {
    onOpenTasksTab = openTasksTab;
    onOpenAddTask = openAddTask;
    _flushPendingLink();
  }

  void unregisterNavigationHandlers() {
    onOpenTasksTab = null;
    onOpenAddTask = null;
  }

  void _handleLink(Uri? uri) {
    if (uri == null) return;
    switch (uri.host) {
      case 'add-task':
        if (onOpenAddTask != null) {
          onOpenAddTask!();
        } else {
          _pendingLink = uri;
        }
        break;
      case 'tasks':
        if (onOpenTasksTab != null) {
          onOpenTasksTab!();
        } else {
          _pendingLink = uri;
        }
        break;
    }
  }

  void _flushPendingLink() {
    final pending = _pendingLink;
    _pendingLink = null;
    if (pending != null) _handleLink(pending);
  }

  // ── Widget → App: drain native quick-adds and toggle journals ──────

  /// Applies changes the widgets made while the app was not running:
  /// materializes pending quick-added tasks into Hive and replays completion
  /// toggles. Returns true when anything changed.
  Future<bool> drainWidgetChanges({
    required RegularTaskRepository repository,
    required SmartNotificationService notifications,
  }) async {
    var changed = false;

    try {
      changed = await _drainPendingTasks(repository, notifications) || changed;
      changed = await _drainToggleEvents(repository, notifications) || changed;
    } catch (e) {
      debugPrint('[WidgetBridge] drain failed: $e');
    }

    if (changed) _changesController.add(null);
    return changed;
  }

  Future<bool> _drainPendingTasks(
    RegularTaskRepository repository,
    SmartNotificationService notifications,
  ) async {
    final raw = await HomeWidget.getWidgetData<String>(WidgetKeys.pendingTasks);
    if (raw == null || raw.isEmpty) return false;

    final List<dynamic> pending;
    try {
      pending = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return false;
    }
    if (pending.isEmpty) return false;

    // The drain can run before the bloc finishes loading — make sure the
    // boxes are open so saves/lookups below don't silently no-op.
    await repository.init();

    final remaining = <dynamic>[];
    var any = false;
    for (final item in pending) {
      if (item is! Map) {
        remaining.add(item);
        continue;
      }
      final id = item['id'] as String?;
      final title = (item['title'] as String?)?.trim();
      if (id == null || title == null || title.isEmpty) {
        // Keep malformed entries out of the journal forever — nothing can
        // ever consume them.
        continue;
      }

      final reminderTime = item['reminderTime'] as String?;
      final createdAt = DateTime.tryParse(item['createdAt'] as String? ?? '') ??
          DateTime.now();
      final task = RegularTask(
        id: id,
        title: title,
        reminderTime: reminderTime,
        isReminderEnabled: reminderTime != null,
        createdAt: createdAt,
      );
      try {
        await repository.saveTask(task);
      } catch (_) {
        remaining.add(item);
        continue;
      }

      if (reminderTime != null) {
        try {
          await notifications.scheduleSmartReminders(
            DateTime.now(),
            [task.toChallenge()],
            null,
          );
        } catch (_) {}
      }

      if (item['completed'] == true) {
        await _recordCompletion(repository, id, DateTime.now(), true);
      }
      any = true;
    }

    await HomeWidget.saveWidgetData(
        WidgetKeys.pendingTasks, jsonEncode(remaining));
    // Removing a pending entry also self-disables the native Android alarm
    // for it — TaskReminderReceiver no-ops when the item is gone.
    return any;
  }

  Future<bool> _drainToggleEvents(
    RegularTaskRepository repository,
    SmartNotificationService notifications,
  ) async {
    final raw = await HomeWidget.getWidgetData<String>(WidgetKeys.toggleEvents);
    if (raw == null || raw.isEmpty) return false;

    final List<dynamic> events;
    try {
      events = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return false;
    }
    if (events.isEmpty) return false;

    // The drain can run before the bloc finishes loading — open the boxes
    // so getTaskById actually finds the toggled tasks.
    await repository.init();

    final remaining = <dynamic>[];
    var any = false;
    for (final event in events) {
      if (event is! Map) {
        remaining.add(event);
        continue;
      }
      final taskId = event['taskId'] as String?;
      final completed = event['completed'] as bool?;
      final date =
          DateTime.tryParse(event['date'] as String? ?? '') ?? DateTime.now();
      if (taskId == null || completed == null) continue;
      if (repository.getTaskById(taskId) == null) {
        // Task unknown (e.g. deleted, or a pending add that didn't drain).
        // Keep the event — a later drain may succeed.
        remaining.add(event);
        continue;
      }

      try {
        await _recordCompletion(repository, taskId, date, completed);
      } catch (_) {
        remaining.add(event);
        continue;
      }
      if (completed) {
        try {
          await notifications.cancelCompletedTaskReminders(taskId);
        } catch (_) {}
      }
      any = true;
    }

    await HomeWidget.saveWidgetData(
        WidgetKeys.toggleEvents, jsonEncode(remaining));
    return any;
  }

  Future<void> _recordCompletion(
    RegularTaskRepository repository,
    String taskId,
    DateTime date,
    bool completed,
  ) async {
    final day = DateTime(date.year, date.month, date.day);
    final existing = repository.getCompletion(day);
    final completions = Map<String, bool>.from(existing?.taskCompletions ?? {});
    completions[taskId] = completed;
    await repository.saveCompletion(
      RegularTaskCompletion(date: day, taskCompletions: completions),
    );
  }

  // ── App → Widget: publish today's task snapshot ────────────────────

  /// Writes the task list the widgets display and asks the OS to redraw.
  /// Pending (widget-created, not yet drained) tasks are appended so they
  /// stay visible until the drain replaces them with real tasks.
  Future<void> syncWidgetData({
    required List<RegularTask> tasks,
    required Map<String, bool> todayCompletions,
  }) async {
    try {
      final items = <Map<String, dynamic>>[
        for (final task in tasks)
          {
            'id': task.id,
            'title': task.title,
            'completed': todayCompletions[task.id] ?? false,
            'pending': false,
          },
      ];

      final rawPending =
          await HomeWidget.getWidgetData<String>(WidgetKeys.pendingTasks);
      if (rawPending != null && rawPending.isNotEmpty) {
        try {
          for (final item in jsonDecode(rawPending) as List<dynamic>) {
            if (item is! Map) continue;
            final id = item['id'] as String?;
            final title = item['title'] as String?;
            if (id == null || title == null) continue;
            if (tasks.any((t) => t.id == id)) continue;
            items.add({
              'id': id,
              'title': title,
              'completed': item['completed'] == true,
              'pending': true,
            });
          }
        } catch (_) {}
      }

      await HomeWidget.saveWidgetData(WidgetKeys.tasks, jsonEncode(items));
      await _updateWidgets();
    } catch (e) {
      debugPrint('[WidgetBridge] sync failed: $e');
    }
  }

  /// Rebuilds the widget snapshot straight from the repository — used when no
  /// bloc state is handy (e.g. right after a drain). Skipped while the boxes
  /// are still closed so an unopened repo can't blank out the widget.
  Future<void> syncWidgetDataFromRepository(
    RegularTaskRepository repository,
  ) async {
    if (!repository.isInitialized) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completions =
        repository.getCompletion(today)?.taskCompletions ?? const {};
    await syncWidgetData(
      tasks: repository.getActiveTasks(),
      todayCompletions: completions,
    );
  }

  Future<void> _updateWidgets() async {
    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
      qualifiedAndroidName: androidProviderClass,
    );
  }

  void dispose() {
    _clickSub?.cancel();
    _changesController.close();
  }
}

/// Runs in a background isolate when the user taps a task row in the
/// Android widget (and is also the callback registered for iOS). It only
/// touches the shared widget store — never Hive — so it can never collide
/// with the app's Hive boxes.
@pragma('vm:entry-point')
Future<void> _widgetToggleCallback(Uri? uri) async {
  try {
    if (uri == null || uri.host != 'toggle') return;
    final taskId = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    if (taskId.isEmpty) return;

    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(WidgetBridgeService.appGroupId);
    }

    // 1. Flip the completed flag in the display snapshot.
    final rawTasks =
        await HomeWidget.getWidgetData<String>(WidgetKeys.tasks) ?? '[]';
    var completedNow = true;
    try {
      final items = (jsonDecode(rawTasks) as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final item in items) {
        if (item['id'] == taskId) {
          item['completed'] = !(item['completed'] == true);
          completedNow = item['completed'] as bool;
        }
      }
      await HomeWidget.saveWidgetData(WidgetKeys.tasks, jsonEncode(items));
    } catch (_) {}

    // 2. Journal the toggle so the app replays it into Hive on next drain.
    final rawEvents =
        await HomeWidget.getWidgetData<String>(WidgetKeys.toggleEvents) ?? '[]';
    try {
      final events = (jsonDecode(rawEvents) as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      events.removeWhere((e) => e['taskId'] == taskId);
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      events
          .add({'taskId': taskId, 'completed': completedNow, 'date': dateKey});
      await HomeWidget.saveWidgetData(
          WidgetKeys.toggleEvents, jsonEncode(events));
    } catch (_) {}

    // 3. If it is a pending quick-added task, mirror the flag there so the
    //    drain records the completion when it materializes the task.
    final rawPending =
        await HomeWidget.getWidgetData<String>(WidgetKeys.pendingTasks) ?? '[]';
    try {
      final pending = (jsonDecode(rawPending) as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      var touched = false;
      for (final item in pending) {
        if (item['id'] == taskId) {
          item['completed'] = completedNow;
          touched = true;
        }
      }
      if (touched) {
        await HomeWidget.saveWidgetData(
            WidgetKeys.pendingTasks, jsonEncode(pending));
      }
    } catch (_) {}

    await HomeWidget.updateWidget(
      iOSName: WidgetBridgeService.iOSWidgetName,
      qualifiedAndroidName: WidgetBridgeService.androidProviderClass,
    );
  } catch (_) {}
}
