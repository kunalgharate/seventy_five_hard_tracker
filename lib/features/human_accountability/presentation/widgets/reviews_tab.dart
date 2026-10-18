import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_state.dart';

/// Overhauled Reviews tab — shows four sections:
/// 1. Incoming review requests (accept/decline)
/// 2. Tasks to review (approve/reject proof)
/// 3. My pending tasks (awaiting reviewer action)
/// 4. Review history
class ReviewsTabV2 extends StatefulWidget {
  const ReviewsTabV2({super.key});

  @override
  State<ReviewsTabV2> createState() => _ReviewsTabV2State();
}

class _ReviewsTabV2State extends State<ReviewsTabV2> {
  @override
  void initState() {
    super.initState();
    context.read<AccountabilityBloc>().add(LoadReviewTabData());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountabilityBloc, AccountabilityState>(
      listenWhen: (_, state) =>
          state is ReviewRequestAccepted ||
          state is ReviewRequestDeclined ||
          state is ProofApproved ||
          state is ProofRejected,
      listener: (context, state) {
        String? msg;
        Color color = Colors.green;
        if (state is ReviewRequestAccepted) {
          msg = 'Review request accepted';
        } else if (state is ReviewRequestDeclined) {
          msg = 'Review request declined';
          color = Colors.orange;
        } else if (state is ProofApproved) {
          msg = state.autoCompleted
              ? 'Task approved and completed!'
              : 'Proof approved';
        } else if (state is ProofRejected) {
          msg = 'Proof rejected';
          color = Colors.red;
        }
        if (msg != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      buildWhen: (_, state) =>
          state is ReviewTabLoaded || state is AccountabilityLoading,
      builder: (context, state) {
        if (state is ReviewTabLoaded) {
          return _buildSections(state);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildSections(ReviewTabLoaded state) {
    final hasContent = state.incomingRequests.isNotEmpty ||
        state.tasksToReview.isNotEmpty ||
        state.myPendingTasks.isNotEmpty ||
        state.reviewHistory.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add reviewers to your tasks or wait\n'
              'for someone to add you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AccountabilityBloc>().add(LoadReviewTabData());
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (state.incomingRequests.isNotEmpty) ...[
            _SectionHeader(
              title: 'Review Requests',
              icon: Icons.person_add,
              color: Colors.blue,
              count: state.incomingRequests.length,
            ),
            const SizedBox(height: 8),
            ...state.incomingRequests.map((t) => _ReviewRequestCard(task: t)),
            const SizedBox(height: 20),
          ],
          if (state.tasksToReview.isNotEmpty) ...[
            _SectionHeader(
              title: 'Tasks to Review',
              icon: Icons.rate_review,
              color: Colors.orange,
              count: state.tasksToReview.length,
            ),
            const SizedBox(height: 8),
            ...state.tasksToReview.map((t) => _ProofReviewCard(task: t)),
            const SizedBox(height: 20),
          ],
          if (state.myPendingTasks.isNotEmpty) ...[
            _SectionHeader(
              title: 'Awaiting Review',
              icon: Icons.hourglass_top,
              color: Colors.purple,
              count: state.myPendingTasks.length,
            ),
            const SizedBox(height: 8),
            ...state.myPendingTasks.map((t) => _MyPendingCard(task: t)),
            const SizedBox(height: 20),
          ],
          if (state.reviewHistory.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Review History',
              icon: Icons.history,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            ...state.reviewHistory.take(20).map((t) => _HistoryCard(task: t)),
          ],
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? count;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Review request card (accept / decline) ──────────────────────────────────

class _ReviewRequestCard extends StatelessWidget {
  final AccountabilityTask task;
  const _ReviewRequestCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, size: 20, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.assignedByName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'wants you to review',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                task.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context
                        .read<AccountabilityBloc>()
                        .add(DeclineReviewRequest(task.id)),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context
                        .read<AccountabilityBloc>()
                        .add(AcceptReviewRequest(task.id)),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Proof review card (approve / reject) ────────────────────────────────────

class _ProofReviewCard extends StatelessWidget {
  final AccountabilityTask task;
  const _ProofReviewCard({required this.task});

  @override
  Widget build(BuildContext context) {
    // I already approved but quorum isn't reached: don't offer Approve
    // again — show the waiting state instead.
    final myUid = AccountabilityService().currentUid;
    final iApproved = myUid != null && task.hasApprovedBy(myUid);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  child: const Icon(Icons.camera_alt,
                      size: 20, color: Colors.orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.assignedByName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'submitted proof for review',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                if (task.expiresAt != null)
                  _ExpiryBadge(expiresAt: task.expiresAt!),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (task.proofUrl != null) ...[
                    const SizedBox(height: 8),
                    // Shared tappable image — tap opens full screen.
                    _ProofImage(url: task.proofUrl!, height: 150),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (iApproved)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_top, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'You approved — waiting for other reviewers',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context, task),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context
                          .read<AccountabilityBloc>()
                          .add(ApproveProof(task.id)),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, AccountabilityTask task) {
    final commentCtrl = TextEditingController();
    final bloc = context.read<AccountabilityBloc>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Why is the proof for "${task.title}" not acceptable?'),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final comment = commentCtrl.text.trim();
              if (comment.isEmpty) return;
              Navigator.pop(ctx);
              bloc.add(RejectProof(task.id, comment: comment));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Expiry badge ────────────────────────────────────────────────────────────

class _ExpiryBadge extends StatelessWidget {
  final DateTime expiresAt;
  const _ExpiryBadge({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final hours = remaining.inHours;
    final isUrgent = hours < 4;
    final color = isUrgent ? Colors.red : Colors.orange;
    final text = remaining.isNegative
        ? 'Expired'
        : hours > 0
            ? '${hours}h left'
            : '${remaining.inMinutes}m left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── My pending task card ────────────────────────────────────────────────────

class _MyPendingCard extends StatelessWidget {
  final AccountabilityTask task;
  const _MyPendingCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final reviewers = task.accountableUserIds
        .where((uid) => uid != task.assignedByUid)
        .toList();
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.purple.withValues(alpha: 0.15),
                  child: const Icon(Icons.hourglass_top,
                      size: 20, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reviewers.isEmpty
                            ? 'Waiting for reviewer approval...'
                            : 'Waiting for ${task.accountableName} to review',
                        style:
                            TextStyle(fontSize: 12, color: Colors.purple[400]),
                      ),
                    ],
                  ),
                ),
                if (task.expiresAt != null)
                  _ExpiryBadge(expiresAt: task.expiresAt!),
              ],
            ),
            if (task.proofUrl != null) ...[
              const SizedBox(height: 10),
              // Both sides see the submitted photo — tap to view full screen.
              _ProofImage(url: task.proofUrl!, height: 130),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tappable proof photo (shared by owner + reviewer cards) ──────────────────

class _ProofImage extends StatelessWidget {
  final String url;
  final double height;
  const _ProofImage({required this.url, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 80,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}

// ── History card ────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final AccountabilityTask task;
  const _HistoryCard({required this.task});

  bool get _isApproved =>
      task.status == AccountabilityTaskStatus.approved ||
      task.proofStatus == ProofStatus.approved;

  bool get _isExpired =>
      task.status == AccountabilityTaskStatus.expired ||
      task.reviewDecision == 'expired';

  DateTime? get _reviewedAt => task.reviewedAt ?? task.proofReviewedAt;

  String get _reviewerName {
    final entries = [...task.approvals, ...task.rejections];
    for (final e in entries.reversed) {
      final name = e['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    return task.accountableName;
  }

  String? get _comment {
    if (task.proofReviewComment != null &&
        task.proofReviewComment!.isNotEmpty) {
      return task.proofReviewComment;
    }
    if (task.reviewComment != null && task.reviewComment!.isNotEmpty) {
      return task.reviewComment;
    }
    for (final e in task.approvals.reversed) {
      final c = e['comment'];
      if (c is String && c.isNotEmpty) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _isApproved;
    final isExpired = _isExpired;
    final color =
        isApproved ? Colors.green : isExpired ? Colors.orange : Colors.red;
    final icon = isApproved
        ? Icons.check_circle
        : isExpired
            ? Icons.schedule
            : Icons.cancel;
    final myUid = AccountabilityService().currentUid;
    final isMyTask = task.assignedByUid == myUid;
    final reviewedAt = _reviewedAt;
    final comment = _comment;
    final reviewer = _reviewerName;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    isMyTask
                        ? isApproved
                            ? 'Approved by $reviewer'
                            : isExpired
                                ? 'Expired — no review decision in time'
                                : 'Rejected by $reviewer — resubmit proof'
                        : isApproved
                            ? 'You approved '
                                '${task.assignedByName}\'s task'
                            : isExpired
                                ? 'Expired — ${task.assignedByName}\'s task'
                                : 'You rejected '
                                '${task.assignedByName}\'s task',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (comment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '"$comment"',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isApproved ? 'Approved' : 'Rejected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (reviewedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d').format(reviewedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
