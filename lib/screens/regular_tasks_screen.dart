import 'dart:async';
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
import 'package:seventy_five_hard_tracker/core/utils/regular_task_stats.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/models/collaborator.dart';
import 'package:seventy_five_hard_tracker/widgets/collaborator_dialog.dart';
import 'package:seventy_five_hard_tracker/widgets/photo_proof_sheet.dart';
import 'package:seventy_five_hard_tracker/widgets/proof_review_dialog.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/widgets/regular_tasks/add_regular_task_sheet.dart';
import 'package:seventy_five_hard_tracker/widgets/regular_tasks/edit_regular_task_sheet.dart';

class RegularTasksScreen extends StatefulWidget {
  const RegularTasksScreen({super.key});

  @override
  State<RegularTasksScreen> createState() => _RegularTasksScreenState();
}

class _RegularTasksScreenState extends State<RegularTasksScreen> {
  final Map<String, String> _assignedPartnerNames = {};
  final Map<String, ProofStatus> _proofStatuses = {};
  final Map<String, AccountabilityTaskStatus> _accountabilityStatuses = {};
  final Set<String> _tasksIAssigned = {};
  final Map<String, List<Collaborator>> _taskCollaborators = {};

  @override
  void initState() {
    super.initState();
    context.read<RegularTaskBloc>().add(LoadRegularTasks());
    _loadAccountabilityData();
  }

  Future<void> _loadAccountabilityData() async {
    final svc = AccountabilityService();
    final partners = await svc.fetchMyPartnerships();
    for (final p in partners) {
      if (p.status == PartnershipStatus.accepted) {
        // Load tasks assigned through this partnership
        // This populates _assignedPartnerNames, _proofStatuses, etc.
      }
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
              return _buildTaskItem(context, task, isCompleted, stats);
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
    RegularTaskStats stats,
  ) {
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
                              Flexible(
                                child: Text(
                                  '🔥 ${stats.currentStreak}d streak',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: stats.currentStreak > 0
                                        ? Colors.orange[600]
                                        : Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '🏆 ${stats.bestStreak}d best',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if ((_taskCollaborators[task.id]?.isNotEmpty ??
                              false)) ...[
                            const SizedBox(height: 4),
                            _buildCollaboratorAvatars(
                                _taskCollaborators[task.id]!),
                          ],
                        ],
                      ),
                    ),
                    // Collaborator icon (Google Keep style)
                    IconButton(
                      onPressed: () => _showCollaboratorDialog(context, task),
                      icon: Icon(
                        (_taskCollaborators[task.id]?.isNotEmpty ?? false)
                            ? Icons.person_add_alt_1
                            : Icons.person_add_alt_1_outlined,
                        color:
                            (_taskCollaborators[task.id]?.isNotEmpty ?? false)
                                ? const Color(0xFFFFA726)
                                : Colors.grey[500],
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      tooltip: 'Manage Collaborators',
                    ),

                    // Three-dot menu
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'remove') {
                          _showDeleteConfirmation(context, task);
                        }
                      },
                      icon: Icon(Icons.more_vert,
                          color: Colors.grey[500], size: 16),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Remove Task',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Photo proof button (only for tasks with a partner)
                    if (_assignedPartnerNames.containsKey(task.id))
                      _buildProofButton(context, task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofButton(BuildContext context, RegularTask task) {
    final proofStatus = _proofStatuses[task.id] ?? ProofStatus.not_required;
    final accStatus = _accountabilityStatuses[task.id];
    final iAmAssigner = _tasksIAssigned.contains(task.id);

    // If the accountability task hasn't been accepted yet, show pending
    if (accStatus == AccountabilityTaskStatus.requested) {
      return Icon(Icons.hourglass_empty, color: Colors.orange[400], size: 20);
    }

    const btnSize = 22.0;
    const iconS = 16.0;

    Widget iconBtn(
        IconData icon, Color color, VoidCallback? onPressed, String tooltip) {
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: iconS),
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: btnSize, minHeight: btnSize),
        tooltip: tooltip,
      );
    }

    // ── CREATOR (assigned this task) — camera is here ──
    if (iAmAssigner) {
      if (proofStatus == ProofStatus.not_required) {
        return iconBtn(Icons.camera_alt_outlined, Colors.grey[500]!,
            () => _submitProof(task), 'Upload Photo Proof');
      }
      switch (proofStatus) {
        case ProofStatus.submitted:
          return iconBtn(Icons.hourglass_bottom, Colors.orange[600]!, null,
              'Awaiting Review');
        case ProofStatus.approved:
          return iconBtn(Icons.check_circle, Colors.green[600]!, null,
              'View Approved Proof');
        case ProofStatus.rejected:
          return iconBtn(Icons.camera_alt, Colors.red[400]!,
              () => _submitProof(task), 'Resubmit Photo Proof');
        default:
          return const SizedBox.shrink();
      }
    }

    // ── COLLABORATOR (task was assigned to them) — status only ──
    if (proofStatus == ProofStatus.not_required) {
      return const SizedBox.shrink();
    }
    switch (proofStatus) {
      case ProofStatus.submitted:
        return iconBtn(Icons.rate_review_outlined, Colors.orange[600]!,
            () => _reviewProof(task), 'Review Photo Proof');
      case ProofStatus.approved:
        return iconBtn(Icons.check_circle, Colors.green[600]!, null,
            'View Approved Proof');
      case ProofStatus.rejected:
        return iconBtn(Icons.cancel, Colors.red[400]!, null, 'Proof Rejected');
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitProof(RegularTask task) async {
    final svc = AccountabilityService();
    final taskId = await svc.fetchTaskIdByChallengeId(task.id);
    if (taskId == null || !mounted) return;

    final result = await PhotoProofSheet.show(
      context: context,
      taskId: taskId,
      taskName: task.title,
      date: DateTime.now(),
    );
    if (result == true && mounted) {
      setState(() {
        _proofStatuses[task.id] = ProofStatus.submitted;
      });
      context.read<AccountabilityBloc>().add(LoadAccountabilityData());
    }
  }

  Future<void> _reviewProof(RegularTask task) async {
    final svc = AccountabilityService();
    final accountabilityTask = await svc.fetchTaskByChallengeId(task.id);
    if (accountabilityTask == null || !mounted) return;

    final result = await ProofReviewDialog.show(context, accountabilityTask);
    if (result == true && mounted) {
      final updated = await svc.fetchTaskByChallengeId(task.id);
      if (mounted && updated != null) {
        setState(() {
          _proofStatuses[task.id] = updated.proofStatus;
          _accountabilityStatuses[task.id] = updated.status;
        });
      }
      if (mounted) {
        context.read<AccountabilityBloc>().add(LoadAccountabilityData());
      }
    }
  }

  Widget _buildCollaboratorAvatars(List<Collaborator> collaborators) {
    const avatarSize = 20.0;
    const overlap = 7.0;
    final displayList = collaborators.take(5).toList();
    final extraCount = collaborators.length - displayList.length;

    return SizedBox(
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (int i = 0; i < displayList.length; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: CollaboratorDialog.buildAvatar(displayList[i],
                  size: avatarSize),
            ),
          if (extraCount > 0)
            Positioned(
              left: displayList.length * (avatarSize - overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          AddRegularTaskSheet(bloc: context.read<RegularTaskBloc>()),
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
              leading: const Icon(Icons.people_outline),
              title: const Text('Assign to Partner'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showHumanPartnerPicker(context, task);
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
      builder: (sheetContext) => EditRegularTaskSheet(
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

  void _showCollaboratorDialog(BuildContext context, RegularTask task) {
    showDialog(
      context: context,
      builder: (context) => CollaboratorDialog(
        taskId: task.id,
        taskName: task.title,
      ),
    ).then((_) => _refreshCollaborators(task.id));
  }

  Future<void> _refreshCollaborators(String taskId) async {
    final result = await AccountabilityService().getTaskCollaborators(taskId);
    if (!mounted) return;
    setState(() {
      _taskCollaborators[taskId] = result?.collaborators ?? [];
    });
  }

  Future<void> _showHumanPartnerPicker(BuildContext _, RegularTask task) async {
    final svc = AccountabilityService();
    final partners = await svc.fetchMyPartnerships();
    final acceptedPartners =
        partners.where((p) => p.status == PartnershipStatus.accepted).toList();

    if (!mounted) return;

    if (acceptedPartners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No accepted partners yet. Add a partner first.'),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

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
              'Assign to Partner',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a partner to hold accountable for "${task.title}"',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...acceptedPartners.map((p) => ListTile(
                  leading:
                      Text(p.role.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.partnerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.role.label),
                  onTap: () async {
                    Navigator.pop(context);
                    final createdTask = await svc.createAccountabilityTask(
                      partnershipId: p.id,
                      title: task.title,
                      challengeId: task.id,
                      accountableUid: p.partnerUid ?? '',
                      accountableName: p.partnerName,
                    );
                    if (createdTask != null && mounted) {
                      setState(() {
                        _assignedPartnerNames[task.id] = p.partnerName;
                        _accountabilityStatuses[task.id] = createdTask.status;
                        _tasksIAssigned.add(task.id);
                      });
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
