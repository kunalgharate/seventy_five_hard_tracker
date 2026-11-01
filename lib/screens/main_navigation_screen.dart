import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/core/services/connectivity_service.dart';
import 'package:seventy_five_hard_tracker/core/services/offline_task_outbox.dart';
import 'package:seventy_five_hard_tracker/core/services/widget_bridge_service.dart';
import 'package:seventy_five_hard_tracker/widgets/regular_tasks/add_regular_task_sheet.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'home_screen.dart';
import 'regular_tasks_screen.dart';
import 'journal_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/pages/accountability_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.screenBuilders});

  @visibleForTesting
  final List<Widget Function()>? screenBuilders;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Future<void>? _resumeSyncInFlight;
  final Set<int> _visitedTabs = {0};
  final Map<int, Widget> _builtScreens = {};
  StreamSubscription<void>? _widgetChangesSub;

  late final List<Widget Function()> _screenBuilders = widget.screenBuilders ??
      [
        () => HomeScreen(
              onGoToSquad: () => _selectTab(4),
            ),
        () => const RegularTasksScreen(),
        () => const JournalScreen(),
        () => const InsightsScreen(),
        () => AccountabilityScreen(
              onGoToProfile: () => _selectTab(5),
            ),
        () => const ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Widget deep links (dailymettle://add-task, dailymettle://tasks) land
    // here — the widget can't reach into the tab navigator by itself.
    WidgetBridgeService.instance.registerNavigationHandlers(
      openTasksTab: () => _selectTab(1),
      openAddTask: _openWidgetAddTask,
    );
    _widgetChangesSub = WidgetBridgeService.instance.changes.listen((_) {
      if (mounted) {
        context.read<RegularTaskBloc>().add(LoadRegularTasks());
      }
    });
    unawaited(_drainWidgetChanges().catchError((Object e) {
      if (kDebugMode) {
        debugPrint('[MainNav] widget drain failed: $e');
      }
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetBridgeService.instance.unregisterNavigationHandlers();
    _widgetChangesSub?.cancel();
    super.dispose();
  }

  /// Applies quick-adds and toggles the widgets queued while the app was
  /// closed, then refreshes the widget snapshot. Uses the bloc's repository
  /// and notification service so test doubles are honored. The repository is
  /// deliberately not opened eagerly — the drain only touches Hive when the
  /// widget actually queued work, so this is a no-op in test environments.
  Future<void> _drainWidgetChanges() async {
    try {
      final bloc = context.read<RegularTaskBloc>();
      final repo = bloc.repository;
      await WidgetBridgeService.instance.drainWidgetChanges(
        repository: repo,
        notifications: bloc.notifications,
      );
      await WidgetBridgeService.instance.syncWidgetDataFromRepository(repo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MainNav] widget drain failed: $e');
      }
    }
  }

  void _openWidgetAddTask() {
    _selectTab(1);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          AddRegularTaskSheet(bloc: context.read<RegularTaskBloc>()),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (FirebaseAuth.instance.currentUser != null) {
      context.read<AccountabilityBloc>().add(CheckExpiredTasks());
    }
    // Pick up anything the widget queued while the app was away.
    unawaited(_drainWidgetChanges().catchError((Object e) {
      if (kDebugMode) {
        debugPrint('[MainNav] widget drain failed: $e');
      }
    }));
    unawaited(_syncLocalChanges());
  }

  Future<void> _syncLocalChanges() {
    final activeSync = _resumeSyncInFlight;
    if (activeSync != null) return activeSync;

    late final Future<void> sync;
    sync = _performLocalSync().whenComplete(() {
      if (identical(_resumeSyncInFlight, sync)) {
        _resumeSyncInFlight = null;
      }
    });
    _resumeSyncInFlight = sync;
    return sync;
  }

  Future<void> _performLocalSync() async {
    try {
      if (!await ConnectivityService().hasInternet()) return;
      final db = DatabaseRepository();
      final taskRepo = RegularTaskRepository();
      await db.init();
      await taskRepo.init();
      final syncSucceeded =
          await CloudSyncService().autoSyncWithResult(db, taskRepo);
      final outboxResult = await OfflineTaskOutbox.instance.flushWithResult();
      if (!syncSucceeded || !outboxResult.succeeded) {
        ConnectivityService().requestReconnectRetry();
        if (kDebugMode) {
          debugPrint(
            'Resume sync incomplete; pending work will retry on the next '
            'resume or reconnect.',
          );
        }
      }
    } catch (e) {
      ConnectivityService().requestReconnectRetry();
      if (kDebugMode) debugPrint('Resume sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(_screenBuilders.length, (index) {
          return _visitedTabs.contains(index)
              ? _builtScreens.putIfAbsent(index, _screenBuilders[index])
              : const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            context.read<RegularTaskBloc>().add(LoadRegularTasks());
          }
          if (index == 4) {
            // Squad tab: refresh so a just-signed-in user (e.g. an invited
            // partner) sees fresh data instead of the last cached payload.
            context.read<AccountabilityBloc>().add(LoadAccountabilityData());
          }
          _selectTab(index);
        },
        selectedItemColor: const Color(0xFFFF5449),
        unselectedItemColor:
            isDark ? Colors.grey[500] : const Color(0xFFA59DA2),
        backgroundColor: isDark ? const Color(0xFF1A1618) : Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            activeIcon: Icon(Icons.checklist),
            label: 'Habits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Squad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
