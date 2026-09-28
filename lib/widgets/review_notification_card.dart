import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inline notification card shown on the Today screen between
/// the challenge hero and task list — "Priya approved your task ✓".
class ReviewNotificationCard extends StatelessWidget {
  final String reviewerName;
  final String taskName;
  final String action; // 'approved', 'rejected', 'feedback'
  final String? comment;
  final VoidCallback? onDismiss;

  const ReviewNotificationCard({
    super.key,
    required this.reviewerName,
    required this.taskName,
    required this.action,
    this.comment,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850]! : Colors.white;

    Color iconColor;
    IconData icon;
    String actionText;

    switch (action) {
      case 'approved':
        iconColor = Colors.green;
        icon = Icons.check_circle;
        actionText = 'approved your $taskName';
        break;
      case 'rejected':
        iconColor = Colors.red;
        icon = Icons.cancel;
        actionText = 'rejected your $taskName';
        break;
      default:
        iconColor = Colors.blue;
        icon = Icons.comment;
        actionText = 'left feedback on your $taskName';
    }

    return Dismissible(
      key: Key('notif_${reviewerName}_$taskName'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss?.call(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Reviewer avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Text(
                reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                      children: [
                        TextSpan(
                          text: '$reviewerName  ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: actionText),
                      ],
                    ),
                  ),
                  if (comment != null && comment!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        comment!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Action icon
            Icon(icon, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}
