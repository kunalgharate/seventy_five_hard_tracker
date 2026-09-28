import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/models/collaborator.dart';
import 'package:seventy_five_hard_tracker/widgets/collaborator_dialog.dart';

/// Bottom sheet showing full task details: description, type badge,
/// reviewers, proof status, comment thread, and action buttons.
class TaskDetailSheet extends StatefulWidget {
  final String challengeId;
  final String taskName;
  final String? description;
  final bool isCompleted;
  final String taskType; // 'hard' or 'regular'

  const TaskDetailSheet({
    super.key,
    required this.challengeId,
    required this.taskName,
    this.description,
    required this.isCompleted,
    this.taskType = 'hard',
  });

  static Future<bool?> show({
    required BuildContext context,
    required String challengeId,
    required String taskName,
    String? description,
    bool isCompleted = false,
    String taskType = 'hard',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailSheet(
        challengeId: challengeId,
        taskName: taskName,
        description: description,
        isCompleted: isCompleted,
        taskType: taskType,
      ),
    );
  }

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  AccountabilityTask? _task;
  List<Collaborator> _collaborators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final svc = AccountabilityService();
    final task = await svc.fetchTaskByChallengeId(widget.challengeId);
    final collabs = await svc.getTaskCollaborators(widget.challengeId);
    if (mounted) {
      setState(() {
        _task = task;
        _collaborators = collabs?.collaborators ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildHeader(textColor),
                        const SizedBox(height: 16),
                        if (widget.description != null &&
                            widget.description!.isNotEmpty)
                          _buildDescription(textColor),
                        _buildStatusSection(textColor),
                        const SizedBox(height: 16),
                        _buildReviewersSection(textColor, cardBg),
                        if (_task != null && _task!.proofUrl != null) ...[
                          const SizedBox(height: 16),
                          _buildProofSection(textColor),
                        ],
                        if (_task != null &&
                            (_task!.approvals.isNotEmpty ||
                                _task!.rejections.isNotEmpty)) ...[
                          const SizedBox(height: 16),
                          _buildCommentThread(textColor, cardBg),
                        ],
                        const SizedBox(height: 20),
                        _buildActions(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    final isHard = widget.taskType == 'hard';
    final typeColor = isHard ? Colors.deepOrange : Colors.purple;
    final typeLabel = isHard ? '75 HARD' : 'ROUTINE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.taskName,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.description!,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Color textColor) {
    if (_task == null) return const SizedBox.shrink();

    final status = _task!.status;
    final proof = _task!.proofStatus;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case AccountabilityTaskStatus.pendingReview:
        statusColor = Colors.orange;
        statusText = 'Awaiting Review';
        statusIcon = Icons.hourglass_top;
        break;
      case AccountabilityTaskStatus.approved:
        statusColor = Colors.green;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case AccountabilityTaskStatus.rejected:
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.error_outline;
        break;
      case AccountabilityTaskStatus.requested:
        statusColor = Colors.blue;
        statusText = 'Waiting for Reviewer';
        statusIcon = Icons.person_add;
        break;
      default:
        statusColor = Colors.grey;
        statusText = proof == ProofStatus.notRequired ? 'Pending' : proof.label;
        statusIcon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          if (_task!.expiresAt != null) ...[
            const Spacer(),
            Text(
              _formatExpiry(_task!.expiresAt!),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiry(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours > 0) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  Widget _buildReviewersSection(Color textColor, Color cardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviewers',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await CollaboratorDialog.show(
                  context: context,
                  taskId: widget.challengeId,
                  taskName: widget.taskName,
                );
                _loadData();
              },
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1,
                      size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Invite',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_collaborators.isEmpty)
          Text(
            'No reviewers yet. Tap "Invite" to add.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _collaborators.map((c) {
              return Chip(
                avatar: CollaboratorDialog.buildAvatar(c, size: 24),
                label: Text(c.name, style: const TextStyle(fontSize: 12)),
                backgroundColor: cardBg,
                side: BorderSide(color: Colors.grey[300]!),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildProofSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proof',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _task!.proofUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 100,
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
        if (_task!.proofSubmittedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Submitted ${DateFormat('MMM d, h:mm a').format(_task!.proofSubmittedAt!)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentThread(Color textColor, Color cardBg) {
    final allComments = <Map<String, dynamic>>[];

    for (final a in _task!.approvals) {
      allComments.add({...a, '_type': 'approved'});
    }
    for (final r in _task!.rejections) {
      allComments.add({...r, '_type': 'rejected'});
    }
    allComments.sort((a, b) {
      final aTime = a['timestamp'];
      final bTime = b['timestamp'];
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Comments',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        ...allComments.map((c) {
          final isApproval = c['_type'] == 'approved';
          final color = isApproval ? Colors.green : Colors.red;
          final icon = isApproval ? Icons.check_circle : Icons.cancel;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['name'] ?? 'Reviewer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (c['comment'] != null &&
                          (c['comment'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            c['comment'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Close'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              await CollaboratorDialog.show(
                context: context,
                taskId: widget.challengeId,
                taskName: widget.taskName,
              );
              _loadData();
            },
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Invite Reviewer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
