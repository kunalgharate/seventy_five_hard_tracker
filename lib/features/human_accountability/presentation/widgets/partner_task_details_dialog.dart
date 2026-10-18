import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';

/// Read-only details for a task shared with an accountability partner.
/// Opened from the Squad partner card so tasks stay viewable after
/// approval (proof photo, dates, reviewer comment, status).
class PartnerTaskDetailsDialog extends StatelessWidget {
  final AccountabilityTask task;

  const PartnerTaskDetailsDialog({super.key, required this.task});

  static Future<void> show(BuildContext context, AccountabilityTask task) {
    return showDialog<void>(
      context: context,
      builder: (_) => PartnerTaskDetailsDialog(task: task),
    );
  }

  ({String label, MaterialColor color}) get _status {
    final status = task.status;
    final proof = task.proofStatus;
    // Done-states are date-scoped: a previous day's approval shows as
    // needing today's proof (history dates below still show the record).
    if ((status == AccountabilityTaskStatus.approved ||
            proof == ProofStatus.approved) &&
        task.isDoneToday) {
      return (label: 'Approved', color: Colors.green);
    }
    if (status == AccountabilityTaskStatus.rejected ||
        proof == ProofStatus.rejected) {
      return (label: 'Rejected', color: Colors.red);
    }
    if (status == AccountabilityTaskStatus.completed && task.isDoneToday) {
      return (label: 'Completed', color: Colors.green);
    }
    if (status == AccountabilityTaskStatus.pendingReview ||
        proof == ProofStatus.submitted) {
      return (label: 'Awaiting Review', color: Colors.orange);
    }
    if ((status == AccountabilityTaskStatus.approved ||
            status == AccountabilityTaskStatus.completed ||
            proof == ProofStatus.approved) &&
        !task.isDoneToday) {
      return (label: 'Needs today\u2019s proof', color: Colors.orange);
    }
    if (status == AccountabilityTaskStatus.declined) {
      return (label: 'Declined', color: Colors.red);
    }
    if (status == AccountabilityTaskStatus.expired) {
      return (label: 'Expired', color: Colors.red);
    }
    return (label: status.label, color: Colors.orange);
  }

  DateTime? get _submittedAt =>
      task.submittedAt ?? task.proofSubmittedAt ?? task.assignedAt;

  DateTime? get _reviewedAt =>
      task.reviewedAt ?? task.proofReviewedAt ?? task.completedAt;

  String? get _comment {
    if (task.reviewComment != null && task.reviewComment!.isNotEmpty) {
      return task.reviewComment;
    }
    if (task.proofReviewComment != null &&
        task.proofReviewComment!.isNotEmpty) {
      return task.proofReviewComment;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final dateFmt = DateFormat('MMM d, yyyy • h:mm a');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title.isNotEmpty ? task.title : 'Untitled Task',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: status.color[700],
                    ),
                  ),
                ),
              ],
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                task.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'From',
              value: task.assignedByName,
            ),
            if (_submittedAt != null)
              _DetailRow(
                icon: Icons.schedule,
                label: 'Submitted',
                value: dateFmt.format(_submittedAt!),
              ),
            if (_reviewedAt != null)
              _DetailRow(
                icon: Icons.fact_check_outlined,
                label: 'Reviewed',
                value: dateFmt.format(_reviewedAt!),
              ),
            if (_comment != null) ...[
              const SizedBox(height: 12),
              Text(
                'Reviewer comment',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _comment!,
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
            ],
            if (task.proofUrl != null) ...[
              const SizedBox(height: 16),
              Text(
                'Photo proof',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              _ProofImage(url: task.proofUrl!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable proof photo (same pattern as reviews_tab.dart) ─────────────────

class _ProofImage extends StatelessWidget {
  final String url;
  const _ProofImage({required this.url});

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
          height: 160,
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
