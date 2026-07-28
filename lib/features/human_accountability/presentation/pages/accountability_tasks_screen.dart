import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';

class AccountabilityTasksScreen extends StatefulWidget {
  final AccountabilityPartner partner;
  const AccountabilityTasksScreen({super.key, required this.partner});

  @override
  State<AccountabilityTasksScreen> createState() =>
      _AccountabilityTasksScreenState();
}

class _AccountabilityTasksScreenState extends State<AccountabilityTasksScreen> {
  final _svc = AccountabilityService();
  String _filter = 'All';

  String get _myUid => _svc.currentUid ?? '';
  bool get _iAmOwner => widget.partner.ownerUid == _myUid;
  String get _accountableUid =>
      _iAmOwner ? (widget.partner.partnerUid ?? '') : widget.partner.ownerUid;
  String get _accountableName =>
      _iAmOwner ? widget.partner.partnerName : _svc.currentUserDisplayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Accountability Tasks'),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, challengeState) {
          // 75 Hard challenges from local BLoC
          final challenges = (challengeState is ChallengeLoaded &&
                  challengeState.hasActiveSession)
              ? challengeState.activeSession!.challenges
                  .where((c) => c.taskType != 'regular')
                  .toList()
              : <Challenge>[];

          final today = DateTime.now();
          final DailyProgress? todayProgress = challengeState is ChallengeLoaded
              ? challengeState.currentProgress
                  .where((p) =>
                      p.date.year == today.year &&
                      p.date.month == today.month &&
                      p.date.day == today.day)
                  .firstOrNull
              : null;

          return StreamBuilder<List<AccountabilityTask>>(
            stream: _svc.tasksStream(widget.partner.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  _buildStatsBar(
                      challenges.length,
                      challenges
                          .where((c) =>
                              todayProgress?.challengeCompletions[c.id] == true)
                          .length,
                      challenges
                          .where((c) =>
                              todayProgress?.challengeCompletions[c.id] != true)
                          .length),
                  _buildFilterRow(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        // ── 75 Hard challenges ──────────────────
                        if (challenges.isNotEmpty) ...[
                          // Apply filter to 75 Hard challenges too
                          Builder(builder: (context) {
                            final filteredChallenges = _filter == 'All'
                                ? challenges
                                : _filter == 'Completed'
                                    ? challenges
                                        .where((c) =>
                                            todayProgress
                                                ?.challengeCompletions[c.id] ==
                                            true)
                                        .toList()
                                    : challenges
                                        .where((c) =>
                                            todayProgress
                                                ?.challengeCompletions[c.id] !=
                                            true)
                                        .toList();

                            if (filteredChallenges.isEmpty &&
                                _filter != 'All') {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(
                                  title: '75 Hard Challenges',
                                  icon: Icons.fitness_center,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 8),
                                ...filteredChallenges.map((c) {
                                  final done = todayProgress
                                          ?.challengeCompletions[c.id] ==
                                      true;
                                  return _ChallengeTaskCard(
                                    challenge: c,
                                    isCompleted: done,
                                  );
                                }),
                                const SizedBox(height: 20),
                              ],
                            );
                          }),
                        ],

                        // ── Assigned accountability tasks ───────
                        // (hidden — tasks managed separately)
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: null,
    );
  }

  // ── Stats bar ──────────────────────────────────────────────────

  Widget _buildStatsBar(int total, int completed, int pending) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatPill(label: 'Total', value: '$total', color: Colors.white),
          const SizedBox(width: 8),
          _StatPill(
              label: 'Done', value: '$completed', color: Colors.greenAccent),
          const SizedBox(width: 8),
          _StatPill(
              label: 'Pending', value: '$pending', color: Colors.yellowAccent),
          const Spacer(),
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 0 : completed / total,
                  strokeWidth: 4,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Text(
                  total == 0 ? '0%' : '${(completed / total * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: ['All', 'Pending', 'Completed'].map((f) {
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(f,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey[700],
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  // ignore: unused_element
  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        partner: widget.partner,
        accountableUid: _accountableUid,
        accountableName: _accountableName,
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      ],
    );
  }
}

// ── 75 Hard Challenge Card ────────────────────────────────────────────────────

class _ChallengeTaskCard extends StatelessWidget {
  final Challenge challenge;
  final bool isCompleted;
  const _ChallengeTaskCard(
      {required this.challenge, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? Colors.green : Colors.orange;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                challenge.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? Colors.grey[500] : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isCompleted ? 'Done' : 'Pending',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
    ]);
  }
}

// ── Add Task Sheet ─────────────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  final AccountabilityPartner partner;
  final String accountableUid;
  final String accountableName;
  const _AddTaskSheet(
      {required this.partner,
      required this.accountableUid,
      required this.accountableName});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _svc = AccountabilityService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a task title')));
      return;
    }
    setState(() => _submitting = true);
    final task = await _svc.createAccountabilityTask(
      accountableUid: widget.accountableUid,
      accountableName: widget.accountableName,
      partnershipId: widget.partner.id,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      dueDate: _dueDate,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(task != null
          ? 'Task assigned to ${widget.accountableName}!'
          : 'Failed to assign task'),
      backgroundColor: task != null ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Assign Task to ${widget.accountableName}',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                prefixIcon: Icon(Icons.task_alt_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.notes_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate != null
                          ? 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}'
                          : 'Set due date (optional)',
                      style: TextStyle(
                        color: _dueDate != null
                            ? Colors.black87
                            : Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: Icon(Icons.close,
                            size: 16, color: Colors.grey[400]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Assign Task',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
