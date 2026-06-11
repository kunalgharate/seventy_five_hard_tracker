import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_state.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import '../widgets/challenge_icon_widget.dart';
import '../widgets/icon_picker_widget.dart';
import '../widgets/reminder_bottom_sheet.dart';
import 'package:seventy_five_hard_tracker/services/challenge_icon_service.dart';
import 'package:seventy_five_hard_tracker/core/services/dynamic_color_service.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/core/utils/regular_task_stats.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';

class RegularTasksScreen extends StatefulWidget {
  const RegularTasksScreen({super.key});

  @override
  State<RegularTasksScreen> createState() => _RegularTasksScreenState();
}

class _RegularTasksScreenState extends State<RegularTasksScreen> {
  Map<String, String> _assignedPartnerNames = {}; // challengeId → partnerName

  @override
  void initState() {
    super.initState();
    context.read<RegularTaskBloc>().add(LoadRegularTasks());
    _loadAssignedPartners();
  }

  Future<void> _loadAssignedPartners() async {
    final svc = AccountabilityService();
    final myUid = svc.currentUid;

    final results = await Future.wait([
      svc.fetchAssignedChallengeMap(), // challengeId → accountableUid (I assigned)
      svc.fetchAccountableForMap(), // challengeId → assignerName (assigned to me, accepted)
      svc.fetchMyPartnerships(),
    ]);

    final challengeMap = results[0] as Map<String, String>;
    final accountableForMap = results[1] as Map<String, String>;
    final partnerships = results[2] as List<AccountabilityPartner>;

    // Build uid → name covering BOTH sides of every partnership
    final uidToName = <String, String>{};
    for (final p in partnerships) {
      if (p.partnerUid != null) uidToName[p.partnerUid!] = p.partnerName;
      if (p.ownerUid != myUid) uidToName[p.ownerUid] = p.partnerName;
    }

    final partnerNames = <String, String>{};
    // Tasks I assigned → show the accountable person's name
    challengeMap.forEach((cid, uid) {
      final name = uidToName[uid];
      if (name != null) partnerNames[cid] = name;
    });
    // Tasks assigned TO me (accepted) → show the assigner's name
    accountableForMap.forEach((cid, assignerName) {
      partnerNames.putIfAbsent(cid, () => assignerName);
    });

    if (mounted) {
      setState(() => _assignedPartnerNames = partnerNames);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegularTaskBloc, RegularTaskState>(
      builder: (context, state) {
        final List<RegularTask> tasks;
        final Map<String, bool> todayCompletions;
        final List<RegularTaskCompletion> recentCompletions;

        if (state is RegularTaskLoaded) {
          tasks = state.tasks;
          todayCompletions = state.todayCompletions;
          recentCompletions = state.recentCompletions;
        } else {
          tasks = [];
          todayCompletions = {};
          recentCompletions = [];
        }

        return Scaffold(
          appBar: const CustomAppBar(title: 'Regular Tasks'),
          body: state is RegularTaskLoading
              ? const Center(child: CircularProgressIndicator())
              : tasks.isNotEmpty
                  ? _buildTaskList(
                      context, tasks, todayCompletions, recentCompletions)
                  : _buildEmptyState(context),
          floatingActionButton: FloatingActionButton(
            heroTag: 'addRegularTask',
            onPressed: () => _showAddTaskSheet(context),
            backgroundColor: Colors.orange[600],
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    List<RegularTask> tasks,
    Map<String, bool> todayCompletions,
    List<RegularTaskCompletion> recentCompletions,
  ) {
    final completedCount =
        todayCompletions.values.where((v) => v).length.clamp(0, tasks.length);
    final totalCount = tasks.length;

    return Column(
      children: [
        // Summary header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: completedCount == totalCount
                  ? [Colors.green[50]!, Colors.green[100]!]
                  : [Colors.orange[50]!, Colors.orange[100]!],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: completedCount == totalCount
                  ? Colors.green[200]!
                  : Colors.orange[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                completedCount == totalCount
                    ? Icons.check_circle
                    : Icons.pending_actions,
                color: completedCount == totalCount
                    ? Colors.green[600]
                    : Colors.orange[600],
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  completedCount == totalCount
                      ? 'All $totalCount tasks done today!'
                      : '$completedCount of $totalCount completed today',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: completedCount == totalCount
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Task list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isCompleted = todayCompletions[task.id] ?? false;
              final stats =
                  calculateRegularTaskStats(task.id, recentCompletions);
              return _buildTaskItem(context, task, isCompleted, stats,
                  partnerName: _assignedPartnerNames[task.id]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    RegularTask task,
    bool isCompleted,
    RegularTaskStats stats, {
    String? partnerName,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: () => _showTaskOptions(context, task),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted ? Colors.green[200]! : Colors.grey[200]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Main task row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Checkbox
                    _buildCheckbox(context, task, isCompleted),
                    const SizedBox(width: 10),
                    // Task icon
                    ChallengeIconWidget(
                      challenge: task.toChallenge(),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    // Title + streak
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? Colors.green[700]
                                  : Colors.grey[800],
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: Colors.green,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '🔥 ${stats.currentStreak}d streak',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: stats.currentStreak > 0
                                      ? Colors.orange[600]
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '🏆 ${stats.bestStreak}d best',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (partnerName != null &&
                              partnerName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 11, color: Colors.blue[400]),
                                const SizedBox(width: 3),
                                Text(
                                  partnerName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: Colors.grey[400]),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      position: PopupMenuPosition.under,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditTaskSheet(context, task);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, task);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Task'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Task',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(
      BuildContext context, RegularTask task, bool isCompleted) {
    return GestureDetector(
      onTap: () {
        context.read<RegularTaskBloc>().add(
              ToggleRegularTaskCompletion(
                taskId: task.id,
                date: DateTime.now(),
                isCompleted: !isCompleted,
              ),
            );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted ? Colors.green : Colors.grey[350]!,
            width: 2,
          ),
        ),
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No Regular Tasks',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            Text(
              'Regular tasks are optional habits you can track without the pressure of resetting.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddTaskSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Regular Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _AddRegularTaskSheet(bloc: context.read<RegularTaskBloc>()),
    );
  }

  void _showTaskOptions(BuildContext context, RegularTask task) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditTaskSheet(context, task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Task',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(context, task);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskSheet(BuildContext context, RegularTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditRegularTaskSheet(
        bloc: context.read<RegularTaskBloc>(),
        task: task,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, RegularTask task) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text(
          'Are you sure you want to delete "${task.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<RegularTaskBloc>().add(DeleteRegularTask(task.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddRegularTaskSheet extends StatefulWidget {
  final RegularTaskBloc bloc;
  const _AddRegularTaskSheet({required this.bloc});

  @override
  State<_AddRegularTaskSheet> createState() => _AddRegularTaskSheetState();
}

class _AddRegularTaskSheetState extends State<_AddRegularTaskSheet> {
  final _controller = TextEditingController();
  late Challenge _challenge;
  String? _taskNameError;
  AccountabilityPartner? _selectedPartner;
  List<AccountabilityPartner> _availablePartners = [];

  @override
  void initState() {
    super.initState();
    _challenge = Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      taskType: 'regular',
      category: 'general',
      reminderType: 'once',
      isReminderEnabled: false,
      showInRegularTab: true,
    );
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    final partners = await AccountabilityService().fetchMyPartnerships();
    if (mounted) {
      setState(() {
        _availablePartners = partners
            .where((p) => p.status == PartnershipStatus.accepted)
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCustomIcon =>
      (_challenge.imagePath != null && _challenge.imagePath!.isNotEmpty) ||
      (_challenge.iconName != null && _challenge.iconName!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.add_task, color: Colors.orange[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'New Regular Task',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + Name row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon picker
                          GestureDetector(
                            onTap: _showIconPicker,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: _hasCustomIcon
                                    ? null
                                    : LinearGradient(colors: [
                                        Colors.grey[100]!,
                                        Colors.grey[200]!
                                      ]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasCustomIcon
                                      ? Colors.blue[300]!
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: _hasCustomIcon
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ChallengeIconWidget(
                                          challenge: _challenge, size: 60),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            color: Colors.grey[500], size: 20),
                                        const SizedBox(height: 2),
                                        Text('Icon',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 9,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Task name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _taskNameError != null
                                          ? Colors.red
                                          : Colors.grey[300]!,
                                      width: _taskNameError != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'e.g., "Drink 3L water daily"',
                                      hintStyle: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 18),
                                    ),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: (value) {
                                      setState(() {
                                        _challenge =
                                            _challenge.copyWith(title: value);
                                        _taskNameError = value.trim().isEmpty
                                            ? null
                                            : validateTaskName(value);
                                      });
                                      // Auto-detect icon
                                      if (value.isNotEmpty && !_hasCustomIcon) {
                                        final iconData =
                                            ChallengeIconService.findBestIcon(
                                                value);
                                        if (iconData != null) {
                                          final dynamicColor =
                                              DynamicColorService
                                                  .getColorForText(value);
                                          setState(() {
                                            _challenge = _challenge.copyWith(
                                              iconName: iconData.name,
                                              iconColor:
                                                  dynamicColor.toARGB32(),
                                            );
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                if (_taskNameError != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4, left: 4),
                                    child: Text(
                                      _taskNameError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_challenge.title.isNotEmpty &&
                          _taskNameError == null) ...[
                        const SizedBox(height: 16),
                        // Ready badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[600], size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Regular task — no reset on miss',
                                style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Reminder button
                        GestureDetector(
                          onTap: _showReminderSetup,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: (_challenge.isReminderEnabled &&
                                      _challenge.reminderTime != null)
                                  ? Colors.orange[50]
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_challenge.isReminderEnabled &&
                                        _challenge.reminderTime != null)
                                    ? Colors.orange[300]!
                                    : Colors.red[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (_challenge.isReminderEnabled &&
                                          _challenge.reminderTime != null)
                                      ? Icons.alarm_on
                                      : Icons.alarm_add,
                                  size: 18,
                                  color: (_challenge.isReminderEnabled &&
                                          _challenge.reminderTime != null)
                                      ? Colors.orange[600]
                                      : Colors.red[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (_challenge.isReminderEnabled &&
                                            _challenge.reminderTime != null)
                                        ? 'Reminder Set ✓'
                                        : '⚠ Set Reminder (Required)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: (_challenge.isReminderEnabled &&
                                              _challenge.reminderTime != null)
                                          ? Colors.orange[700]
                                          : Colors.red[700],
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18,
                                    color: (_challenge.isReminderEnabled &&
                                            _challenge.reminderTime != null)
                                        ? Colors.orange[400]
                                        : Colors.red[400]),
                              ],
                            ),
                          ),
                        ),
                        // ── Accountability Partner picker ──────
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _availablePartners.isEmpty
                              ? null
                              : _showPartnerPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedPartner != null
                                  ? Colors.blue[50]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedPartner != null
                                    ? Colors.blue[300]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 18,
                                  color: _selectedPartner != null
                                      ? Colors.blue[600]
                                      : Colors.grey[500],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedPartner != null
                                        ? '👥 ${_selectedPartner!.partnerName}'
                                        : _availablePartners.isEmpty
                                            ? 'No partners yet'
                                            : 'Assign accountability partner (optional)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedPartner != null
                                          ? Colors.blue[700]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                if (_selectedPartner != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedPartner = null),
                                    child: Icon(Icons.close,
                                        size: 16, color: Colors.grey[400]),
                                  )
                                else
                                  Icon(Icons.chevron_right,
                                      size: 18, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Create button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _challenge.title.trim().isEmpty ||
                            _taskNameError != null
                        ? null
                        : (!_challenge.isReminderEnabled ||
                                _challenge.reminderTime == null)
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Please set a reminder before creating the task'),
                                    backgroundColor: Colors.red[600],
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            : _createTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_challenge.title.trim().isNotEmpty &&
                              _taskNameError == null &&
                              _challenge.isReminderEnabled &&
                              _challenge.reminderTime != null)
                          ? Colors.orange[600]
                          : Colors.grey[400],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Create Task',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (_challenge.title.trim().isNotEmpty &&
                                  _taskNameError == null &&
                                  _challenge.isReminderEnabled &&
                                  _challenge.reminderTime != null)
                              ? Colors.white
                              : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IconPickerWidget(
        selectedIconName: _challenge.iconName,
        selectedImagePath: _challenge.imagePath,
        onSelectionChanged: (iconName, imagePath) {
          setState(() {
            _challenge = Challenge(
              id: _challenge.id,
              title: _challenge.title,
              reminderTime: _challenge.reminderTime,
              isReminderEnabled: _challenge.isReminderEnabled,
              imagePath: imagePath,
              iconName: iconName,
              iconColor: _challenge.iconColor,
              category: _challenge.category,
              taskType: _challenge.taskType,
              reminderType: _challenge.reminderType,
              reminderStartHour: _challenge.reminderStartHour,
              reminderEndHour: _challenge.reminderEndHour,
              allowNightReminders: _challenge.allowNightReminders,
              reminderIntervalMinutes: _challenge.reminderIntervalMinutes,
              photoRequired: _challenge.photoRequired,
              showInRegularTab: _challenge.showInRegularTab,
            );
          });
        },
      ),
    );
  }

  void _showPartnerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Assign Accountability Partner',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'They will be held accountable for this task',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ..._availablePartners.map((p) => ListTile(
                  leading:
                      Text(p.role.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.partnerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.role.label),
                  trailing: _selectedPartner?.id == p.id
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() => _selectedPartner = p);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReminderSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(
        challenge: _challenge,
        onSave: (updated) {
          setState(() => _challenge = updated);
        },
      ),
    );
  }

  void _createTask() {
    // Validate task name
    final validationError = validateTaskName(_challenge.title);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Sanitize the title
    final sanitizedTitle = sanitizeTaskName(_challenge.title);

    // Convert the Challenge form data to a RegularTask
    final regularTask = RegularTask(
      id: _challenge.id,
      title: sanitizedTitle,
      reminderTime: _challenge.reminderTime,
      isReminderEnabled: _challenge.isReminderEnabled,
      imagePath: _challenge.imagePath,
      iconName: _challenge.iconName,
      iconColor: _challenge.iconColor,
      category: _challenge.category,
      reminderType: _challenge.reminderType,
      reminderStartHour: _challenge.reminderStartHour,
      reminderEndHour: _challenge.reminderEndHour,
      allowNightReminders: _challenge.allowNightReminders,
      reminderIntervalMinutes: _challenge.reminderIntervalMinutes,
      createdAt: DateTime.now(),
    );
    widget.bloc.add(AddRegularTask(regularTask));

    // If a partner was selected, create an accountability task request
    if (_selectedPartner != null) {
      final svc = AccountabilityService();
      final myUid = svc.currentUid;
      final p = _selectedPartner!;
      // Always assign to the OTHER person, not ourselves
      final otherUid = p.ownerUid == myUid ? p.partnerUid : p.ownerUid;
      if (otherUid != null) {
        svc.createAccountabilityTask(
          accountableUid: otherUid,
          accountableName: p.partnerName,
          partnershipId: p.id,
          title: sanitizedTitle,
          description: 'Regular task from Daily Mettle',
          challengeId: _challenge.id,
        );
      }
    }

    Navigator.pop(context);
  }
}

class _EditRegularTaskSheet extends StatefulWidget {
  final RegularTaskBloc bloc;
  final RegularTask task;
  const _EditRegularTaskSheet({required this.bloc, required this.task});

  @override
  State<_EditRegularTaskSheet> createState() => _EditRegularTaskSheetState();
}

class _EditRegularTaskSheetState extends State<_EditRegularTaskSheet> {
  late TextEditingController _controller;
  late Challenge _challenge;
  String? _taskNameError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.title);
    _challenge = widget.task.toChallenge();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCustomIcon =>
      (_challenge.imagePath != null && _challenge.imagePath!.isNotEmpty) ||
      (_challenge.iconName != null && _challenge.iconName!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit Task',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _showIconPicker,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: _hasCustomIcon
                                    ? null
                                    : LinearGradient(colors: [
                                        Colors.grey[100]!,
                                        Colors.grey[200]!
                                      ]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasCustomIcon
                                      ? Colors.blue[300]!
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: _hasCustomIcon
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ChallengeIconWidget(
                                          challenge: _challenge, size: 60),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            color: Colors.grey[500], size: 20),
                                        const SizedBox(height: 2),
                                        Text('Icon',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 9,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _taskNameError != null
                                          ? Colors.red
                                          : Colors.grey[300]!,
                                      width: _taskNameError != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    decoration: InputDecoration(
                                      hintText: 'Task name',
                                      hintStyle: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 18),
                                    ),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: (value) {
                                      setState(() {
                                        _challenge =
                                            _challenge.copyWith(title: value);
                                        _taskNameError = value.trim().isEmpty
                                            ? null
                                            : validateTaskName(value);
                                      });
                                    },
                                  ),
                                ),
                                if (_taskNameError != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4, left: 4),
                                    child: Text(
                                      _taskNameError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showReminderSetup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: (_challenge.isReminderEnabled &&
                                    _challenge.reminderTime != null)
                                ? Colors.orange[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_challenge.isReminderEnabled &&
                                      _challenge.reminderTime != null)
                                  ? Colors.orange[300]!
                                  : Colors.red[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (_challenge.isReminderEnabled &&
                                        _challenge.reminderTime != null)
                                    ? Icons.alarm_on
                                    : Icons.alarm_add,
                                size: 18,
                                color: (_challenge.isReminderEnabled &&
                                        _challenge.reminderTime != null)
                                    ? Colors.orange[600]
                                    : Colors.red[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (_challenge.isReminderEnabled &&
                                          _challenge.reminderTime != null)
                                      ? 'Reminder Set ✓'
                                      : '⚠ Set Reminder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: (_challenge.isReminderEnabled &&
                                            _challenge.reminderTime != null)
                                        ? Colors.orange[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 18,
                                  color: (_challenge.isReminderEnabled &&
                                          _challenge.reminderTime != null)
                                      ? Colors.orange[400]
                                      : Colors.red[400]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _challenge.title.trim().isEmpty ||
                            _taskNameError != null
                        ? null
                        : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _challenge.title.trim().isNotEmpty &&
                              _taskNameError == null
                          ? Colors.orange[600]
                          : Colors.grey[400],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _challenge.title.trim().isNotEmpty &&
                                  _taskNameError == null
                              ? Colors.white
                              : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IconPickerWidget(
        selectedIconName: _challenge.iconName,
        selectedImagePath: _challenge.imagePath,
        onSelectionChanged: (iconName, imagePath) {
          setState(() {
            _challenge = Challenge(
              id: _challenge.id,
              title: _challenge.title,
              reminderTime: _challenge.reminderTime,
              isReminderEnabled: _challenge.isReminderEnabled,
              imagePath: imagePath,
              iconName: iconName,
              iconColor: _challenge.iconColor,
              category: _challenge.category,
              taskType: _challenge.taskType,
              reminderType: _challenge.reminderType,
              reminderStartHour: _challenge.reminderStartHour,
              reminderEndHour: _challenge.reminderEndHour,
              allowNightReminders: _challenge.allowNightReminders,
              reminderIntervalMinutes: _challenge.reminderIntervalMinutes,
              photoRequired: _challenge.photoRequired,
              showInRegularTab: _challenge.showInRegularTab,
            );
          });
        },
      ),
    );
  }

  void _showReminderSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(
        challenge: _challenge,
        onSave: (updated) {
          setState(() => _challenge = updated);
        },
      ),
    );
  }

  void _saveChanges() {
    // Validate task name
    final validationError = validateTaskName(_challenge.title);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Sanitize the title
    final sanitizedTitle = sanitizeTaskName(_challenge.title);

    final updatedTask = RegularTask(
      id: widget.task.id,
      title: sanitizedTitle,
      reminderTime: _challenge.reminderTime,
      isReminderEnabled: _challenge.isReminderEnabled,
      imagePath: _challenge.imagePath,
      iconName: _challenge.iconName,
      iconColor: _challenge.iconColor,
      category: _challenge.category,
      reminderType: _challenge.reminderType,
      reminderStartHour: _challenge.reminderStartHour,
      reminderEndHour: _challenge.reminderEndHour,
      allowNightReminders: _challenge.allowNightReminders,
      reminderIntervalMinutes: _challenge.reminderIntervalMinutes,
      createdAt: widget.task.createdAt,
    );
    widget.bloc.add(UpdateRegularTask(updatedTask));
    Navigator.pop(context);
  }
}
