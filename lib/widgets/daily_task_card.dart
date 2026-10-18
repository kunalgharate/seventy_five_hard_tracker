import 'package:flutter/material.dart';
import 'package:seventy_five_hard_tracker/widgets/task_detail_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/models/collaborator.dart';
import 'package:seventy_five_hard_tracker/widgets/collaborator_dialog.dart';
import 'apple_checkbox.dart';
import 'challenge_icon_widget.dart';
import 'reminder_bottom_sheet.dart';
import 'task_type_card.dart';

class DailyTaskCard extends StatefulWidget {
  final Challenge challenge;
  final bool isCompleted;
  final bool isEditable;
  final Function(bool) onToggle;
  final Function(Challenge)? onReminderUpdate;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;
  final int? dayNumber;
  final String? accountablePartnerUid;
  final String? partnerName;
  final AccountabilityTaskStatus? accountabilityStatus;

  /// True when the current user is only the REVIEWER of this task (a partner
  /// assigned it). The owner completes it and uploads proof; the reviewer
  /// must not see a completion checkbox here.
  final bool isReviewOnly;
  final ProofStatus? proofStatus;

  /// Date-scoped done-state from the linked accountability task (computed by
  /// the parent via `task.isDoneToday`). A previous day's approval must not
  /// render as approved today. Defaults to true (no linked task info).
  final bool accountabilityDoneToday;
  final VoidCallback? onSubmitProof;
  final VoidCallback? onReviewProof;
  final VoidCallback? onViewProof;

  /// Called when the user tries to toggle a task that has reviewers.
  /// The parent should open the proof upload sheet instead of toggling.
  final VoidCallback? onProofRequired;

  const DailyTaskCard({
    super.key,
    required this.challenge,
    required this.isCompleted,
    required this.isEditable,
    required this.onToggle,
    this.onReminderUpdate,
    this.onRemove,
    this.onEdit,
    this.dayNumber,
    this.accountablePartnerUid,
    this.partnerName,
    this.accountabilityStatus,
    this.isReviewOnly = false,
    this.proofStatus,
    this.accountabilityDoneToday = true,
    this.onSubmitProof,
    this.onReviewProof,
    this.onViewProof,
    this.onProofRequired,
  });

  @override
  State<DailyTaskCard> createState() => _DailyTaskCardState();
}

class _DailyTaskCardState extends State<DailyTaskCard>
    with TickerProviderStateMixin {
  late AnimationController _completionController;
  late AnimationController _pulseController;
  OverlayEntry? _activeOverlayEntry;
  List<Collaborator> _collaborators = [];

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.isCompleted) {
      _completionController.forward();
    } else if (widget.isEditable) {
      _pulseController.repeat(reverse: true);
    }
    _loadCollaborators();
  }

  Future<void> _loadCollaborators() async {
    final result =
        await AccountabilityService().getTaskCollaborators(widget.challenge.id);
    if (!mounted) return;
    setState(() {
      _collaborators = result?.collaborators ?? [];
    });
  }

  /// Whether this task has collaborator reviewers assigned.
  bool get _hasReviewers => _collaborators.isNotEmpty;

  /// Whether this challenge is linked to a Squad accountability task
  /// (reviewer assigned via partnership, not via the collaborator dialog).
  /// The Today screen doesn't pass partner props, so the collaborator list
  /// stays empty for these tasks — the accountability status is the signal.
  bool get _hasAccountabilityTask => widget.accountabilityStatus != null;

  /// Opens the task detail bottom sheet.
  void _openTaskDetail() {
    TaskDetailSheet.show(
      context: context,
      challengeId: widget.challenge.id,
      taskName: widget.challenge.title,
      description: widget.challenge.category,
      isCompleted: widget.isCompleted,
      taskType: widget.challenge.taskType,
    );
  }

  /// Intercepts the toggle: if reviewers exist and task is being completed,
  /// open proof upload instead of toggling. Also intercepts rejected tasks
  /// to allow proof resubmission. Otherwise, normal toggle.
  void _handleToggle(bool newValue) {
    // Reviewer role: the owner completes this task and uploads proof.
    if (widget.isReviewOnly) return;
    // The reviewer hasn't accepted the task yet — a proof cannot be reviewed
    // until they do, so block the upload instead of opening the sheet.
    if (newValue && _isRequestedAndUnaccepted()) {
      final reviewer = _collaborators.isNotEmpty
          ? _collaborators.first.name
          : 'your partner';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waiting for $reviewer to accept this task first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (newValue &&
        (_hasReviewers || _hasAccountabilityTask) &&
        widget.onProofRequired != null) {
      // User is trying to complete → require proof upload
      widget.onProofRequired!();
    } else if (newValue &&
        (widget.proofStatus == ProofStatus.rejected ||
            widget.accountabilityStatus == AccountabilityTaskStatus.rejected) &&
        widget.onProofRequired != null) {
      // Rejected — allow resubmission
      widget.onProofRequired!();
    } else {
      widget.onToggle(newValue);
    }
  }

  @override
  void didUpdateWidget(DailyTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted != oldWidget.isCompleted) {
      if (widget.isCompleted) {
        _completionController.forward();
        _pulseController.stop();
        _showCompletionAnimation();
      } else {
        _completionController.reverse();
        if (widget.isEditable) {
          _pulseController.repeat(reverse: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _activeOverlayEntry?.remove();
    _activeOverlayEntry = null;
    _completionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _showGenericReminderSetup() {
    if (widget.onReminderUpdate == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderBottomSheet(
        challenge: widget.challenge,
        onSave: (updated) => widget.onReminderUpdate!(updated),
      ),
    );
  }

  void _showCollaboratorDialog() {
    showDialog(
      context: context,
      builder: (context) => CollaboratorDialog(
        taskId: widget.challenge.id,
        taskName: widget.challenge.title,
      ),
    ).then((_) => _loadCollaborators());
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard();
  }

  // Helper method to extract display time from reminder data
  String _getDisplayTime(String reminderData) {
    // Handle different reminder formats
    if (reminderData.startsWith('once:')) {
      return reminderData.substring(5); // Extract time after "once:"
    } else if (reminderData.startsWith('multiple:')) {
      final times = reminderData.substring(9).split(',');
      return times.first; // Show first time
    } else if (reminderData.startsWith('hourly:')) {
      return reminderData.substring(7); // Extract start time after "hourly:"
    } else if (reminderData.startsWith('interval:')) {
      final parts = reminderData.substring(9).split(':');
      return '${parts[1]}:${parts[2]}'; // Extract start time
    } else if (reminderData.startsWith('custom:')) {
      final times = reminderData.substring(7).split(',');
      return times.first; // Show first time
    } else {
      // Fallback for simple time format
      return reminderData;
    }
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Alarm badge above the card to avoid overlap
          if (widget.challenge.isReminderEnabled &&
              widget.challenge.reminderTime != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: GestureDetector(
                onTap: widget.isEditable ? _showGenericReminderSetup : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange[100]?.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange[300]!, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm,
                        color: Colors.orange[700],
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          () {
                            final displayTime =
                                _getDisplayTime(widget.challenge.reminderTime!);
                            final timeParts = displayTime.split(':');
                            final hour = int.parse(timeParts[0]);
                            final minute = int.parse(timeParts[1]);
                            return DateFormat('h:mm a')
                                .format(DateTime(2024, 1, 1, hour, minute));
                          }(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          _buildCleanCard(),
        ],
      ),
    );
  }

  /// Status accent color used for the card's left edge and progress bar.
  /// Completed = green, active = category color, missed = red.
  Color _statusAccent() {
    if (widget.isCompleted) return Colors.green;
    if (!widget.isEditable) return Colors.red;
    return TaskTypeStyle.of(widget.challenge.category).accent;
  }

  /// Theme-aware card that renders through [TaskTypeCard]: category header
  /// (icon, label, tagline), status-colored left edge and a completion
  /// progress bar. The body keeps all existing checkbox/toggle behaviour.
  Widget _buildCleanCard() {
    return TaskTypeCard(
      category: widget.challenge.category,
      isCompleted: widget.isCompleted,
      accent: _statusAccent(),
      child: _buildCardContent(),
    );
  }

  bool get _hasPartner =>
      widget.accountablePartnerUid != null &&
      widget.accountablePartnerUid!.isNotEmpty;
  bool get _assignedToMe =>
      !_hasPartner &&
      widget.partnerName != null &&
      widget.partnerName!.isNotEmpty;
  bool get _hasAccountabilityConnection => _hasPartner || _assignedToMe;

  /// True if the current user is the task owner (accountable person = the one who completes the task).
  bool _isOwner(String? myUid) {
    if (myUid == null) return false;
    if (_hasPartner) return widget.accountablePartnerUid == myUid;
    // If a partner name is shown but no UID, this was assigned to me
    if (_assignedToMe) return true;
    return true; // No accountability connection at all = I'm the owner
  }

  /// True if the current user is the reviewer/assigner (assigned the task to someone else).
  bool _isAssigner(String? myUid) {
    if (myUid == null) return false;
    return _hasPartner && widget.accountablePartnerUid != myUid;
  }

  Widget _buildCardContent() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildCompletionWidget(),
          const SizedBox(width: 8),
          AnimatedChallengeIcon(
            challenge: widget.challenge,
            size: 36,
            onTap: (widget.isEditable &&
                    _isOwner(myUid) &&
                    !widget.isReviewOnly &&
                    !_isRequestedAndUnaccepted())
                ? () => _handleToggle(!widget.isCompleted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _openTaskDetail(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.challenge.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isCompleted
                          ? Colors.green[700]
                          : widget.isEditable
                              ? Theme.of(context).textTheme.titleMedium?.color
                              : Colors.red[700],
                      decoration: widget.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.green,
                      decorationThickness: 2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_collaborators.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _buildCollaboratorAvatars(),
                  ],
                  if (_hasReviewers) ...[
                    const SizedBox(height: 3),
                    _buildReviewStatusBadge(),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isCompleted
                          ? Colors.green[600]
                          : widget.isEditable
                              ? Colors.grey[600]
                              : Colors.red[600],
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          _buildTrailingActions(myUid),
        ],
      ),
    );
  }

  Widget _buildTrailingActions(String? myUid) {
    final actions = <Widget>[];
    const btnSize = 24.0;
    const iconSize = 16.0;

    if (widget.isEditable && !widget.challenge.isReminderEnabled) {
      actions.add(IconButton(
        onPressed: _showGenericReminderSetup,
        icon: Icon(Icons.alarm_add, color: Colors.grey[500], size: iconSize),
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: btnSize, minHeight: btnSize),
        tooltip: 'Set Reminder',
      ));
    }

    if (widget.isEditable) {
      actions.add(IconButton(
        onPressed: _showCollaboratorDialog,
        icon: Icon(
          _collaborators.isNotEmpty
              ? Icons.person_add_alt_1
              : Icons.person_add_alt_1_outlined,
          color:
              _collaborators.isNotEmpty ? AppColors.primary : Colors.grey[500],
          size: iconSize,
        ),
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: btnSize, minHeight: btnSize),
        tooltip: 'Manage Collaborators',
      ));
    }

    if (widget.isEditable &&
        (_hasAccountabilityConnection ||
            _hasAccountabilityTask ||
            widget.isReviewOnly ||
            widget.accountabilityStatus ==
                AccountabilityTaskStatus.pendingReview ||
            widget.proofStatus == ProofStatus.submitted)) {
      actions.add(_buildProofButton());
    }

    if (widget.isEditable && widget.onEdit != null) {
      actions.add(IconButton(
        onPressed: widget.onEdit,
        icon:
            Icon(Icons.edit_outlined, color: Colors.grey[600], size: iconSize),
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: btnSize, minHeight: btnSize),
        tooltip: 'Edit Task',
      ));
    }

    if (widget.isEditable && widget.onRemove != null) {
      actions.add(IconButton(
        onPressed: _confirmRemove,
        icon:
            Icon(Icons.delete_outline, color: Colors.red[400], size: iconSize),
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: btnSize, minHeight: btnSize),
        tooltip: 'Remove Task',
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    // Wrap (instead of Row) so the buttons flow onto a second line on narrow
    // screens instead of overflowing the card with a RenderFlex stripe.
    // Flexible bounds the width to the space left by the title; on normal
    // widths this renders exactly like the old single-line Row.
    return Flexible(
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions
            .map((w) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: w,
                ))
            .toList(),
      ),
    );
  }

  bool _isRequestedAndUnaccepted() {
    return widget.accountabilityStatus == AccountabilityTaskStatus.requested;
  }

  void _confirmRemove() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Task?'),
        content:
            Text('Remove "${widget.challenge.title}" from this challenge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        widget.onRemove?.call();
      }
    });
  }

  Widget _buildCompletionWidget() {
    // Task assigned to ME for REVIEW (a partner owns it). The owner completes
    // it and uploads proof; I review the proof. Show a real checkbox (not an
    // eye icon) so the review task is visible inline — tapping it opens the
    // proof review when proof is submitted, otherwise explains the wait.
    // Once approved, the checkbox reflects checked on BOTH sides — but only
    // for TODAY's approval. A previous day's approval needs fresh proof.
    if (widget.isReviewOnly) {
      final approvedNow = widget.accountabilityDoneToday &&
          (widget.accountabilityStatus == AccountabilityTaskStatus.approved ||
              widget.accountabilityStatus ==
                  AccountabilityTaskStatus.completed ||
              widget.proofStatus == ProofStatus.approved);
      final checked = widget.isCompleted || approvedNow;
      final hasProofToReview = widget.accountabilityStatus ==
              AccountabilityTaskStatus.pendingReview ||
          widget.proofStatus == ProofStatus.submitted;
      final tip = widget.partnerName != null && widget.partnerName!.isNotEmpty
          ? '${widget.partnerName} completes this — tap checkbox to review the proof'
          : 'Your partner completes this — tap checkbox to review the proof';
      return Tooltip(
        message: tip,
        child: AppleCheckbox(
          isChecked: checked,
          isEnabled: widget.isEditable,
          onChanged: (_) {
            if (hasProofToReview && widget.onReviewProof != null) {
              widget.onReviewProof!();
            } else if (checked) {
              // Already approved — nothing to do, checkbox reflects both sides.
              return;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Waiting for the owner to submit proof — only the owner can add proof.'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      );
    }

    // Show pending review indicator when waiting for partner
    if (widget.accountabilityStatus == AccountabilityTaskStatus.pendingReview) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange[600],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.hourglass_top, color: Colors.white, size: 20),
      );
    }

    // Show rejected indicator
    if (widget.accountabilityStatus == AccountabilityTaskStatus.rejected ||
        widget.accountabilityStatus == AccountabilityTaskStatus.expired) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 20),
      );
    }

    if (!widget.isEditable) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isCompleted ? Colors.green[600] : Colors.red[600],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (widget.isCompleted ? Colors.green : Colors.red)
                  .withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          widget.isCompleted ? Icons.check : Icons.close,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    // Interactive completion toggle for editable cards - Apple-style checkbox
    return AppleCheckbox(
      isChecked: widget.isCompleted,
      isEnabled: widget.isEditable,
      onChanged: (value) => _handleToggle(value),
    );
  }

  /// Shows the current review status as a compact colored badge.
  Widget _buildReviewStatusBadge() {
    final accStatus = widget.accountabilityStatus;
    final proof = widget.proofStatus;

    String text;
    Color color;
    IconData icon;

    if (accStatus == AccountabilityTaskStatus.requested &&
        !widget.isEditable) {
      text = 'Awaiting acceptance';
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else if (accStatus == AccountabilityTaskStatus.pendingReview ||
        proof == ProofStatus.submitted) {
      text = 'Awaiting review';
      color = Colors.orange;
      icon = Icons.hourglass_top;
    } else if ((accStatus == AccountabilityTaskStatus.approved ||
            proof == ProofStatus.approved) &&
        widget.accountabilityDoneToday) {
      text = 'Approved';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (accStatus == AccountabilityTaskStatus.rejected ||
        proof == ProofStatus.rejected) {
      text = 'Tap to resubmit proof';
      color = Colors.red;
      icon = Icons.refresh;
    } else if (accStatus == AccountabilityTaskStatus.requested &&
        widget.isEditable) {
      text = 'Waiting for reviewer';
      color = Colors.blue;
      icon = Icons.person_add;
    } else {
      // No status to show — task has reviewers but no proof action yet
      text = 'Proof required';
      color = Colors.grey;
      icon = Icons.camera_alt_outlined;
    }

    final isRejected = accStatus == AccountabilityTaskStatus.rejected ||
        proof == ProofStatus.rejected;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    // Make tappable when rejected so user can resubmit proof
    if (isRejected && widget.onProofRequired != null) {
      badge = GestureDetector(
        onTap: widget.onProofRequired,
        child: badge,
      );
    }

    return badge;
  }

  Widget _buildCollaboratorAvatars() {
    const avatarSize = 22.0;
    const overlap = 8.0;
    final displayList = _collaborators.take(5).toList();
    final extraCount = _collaborators.length - displayList.length;

    return SizedBox(
      height: avatarSize,
      child: Stack(
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
                      fontSize: 9,
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

  Widget _buildProofButton() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = _isAssigner(myUid);
    final status = widget.proofStatus;
    const btnSize = 24.0;
    const iconS = 16.0;
    const zeroEdge = EdgeInsets.zero;
    const btnConstraints =
        BoxConstraints(minWidth: btnSize, minHeight: btnSize);

    Widget iconBtn(
        IconData icon, Color color, VoidCallback? onPressed, String tooltip) {
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: iconS),
        padding: zeroEdge,
        constraints: btnConstraints,
        tooltip: tooltip,
      );
    }

    // ── REVIEWER view (task assigned to me for review) ──
    // Owner adds proof; I only review. Never show an upload button here.
    if (widget.isReviewOnly) {
      if (status == ProofStatus.submitted ||
          widget.accountabilityStatus ==
              AccountabilityTaskStatus.pendingReview) {
        return iconBtn(Icons.rate_review_outlined, Colors.orange[600]!,
            widget.onReviewProof, 'Review Photo Proof');
      }
      if (status == ProofStatus.approved ||
          widget.accountabilityStatus == AccountabilityTaskStatus.approved) {
        return iconBtn(Icons.check_circle, Colors.green[600]!,
            widget.onViewProof, 'View Approved Proof');
      }
      // Waiting for owner to submit proof — no upload action for reviewer.
      return iconBtn(Icons.hourglass_empty, Colors.grey[400]!, null,
          'Waiting for owner to submit proof');
    }

    // ── CREATOR (assigned this task to a collaborator) ──
    // Also covers the owner side of a Squad accountability task: the Today
    // screen doesn't pass creator props, so fall back to the accountability
    // status (not review-only + a linked task = I'm the one who proves it).
    if (isCreator || (!widget.isReviewOnly && _hasAccountabilityTask)) {
      // Reviewer hasn't accepted yet — nothing to upload against.
      if (_isRequestedAndUnaccepted()) {
        return iconBtn(Icons.lock_outline, Colors.orange[600]!, null,
            'Waiting for reviewer to accept');
      }
      if (status == null || status == ProofStatus.notRequired) {
        return iconBtn(Icons.camera_alt_outlined, Colors.grey[500]!,
            widget.onSubmitProof, 'Upload Photo Proof');
      }
      switch (status) {
        case ProofStatus.submitted:
          return iconBtn(Icons.hourglass_bottom, Colors.orange[600]!, null,
              'Awaiting Review');
        case ProofStatus.approved:
          return iconBtn(Icons.check_circle, Colors.green[600]!,
              widget.onViewProof, 'View Approved Proof');
        case ProofStatus.rejected:
          return iconBtn(Icons.camera_alt, Colors.red[400]!,
              widget.onSubmitProof, 'Resubmit Photo Proof');
        default:
          return const SizedBox.shrink();
      }
    }

    // ── COLLABORATOR (task was assigned to them) ──
    if (status == null || status == ProofStatus.notRequired) {
      return const SizedBox.shrink();
    }
    switch (status) {
      case ProofStatus.submitted:
        return iconBtn(Icons.rate_review_outlined, Colors.orange[600]!,
            widget.onReviewProof, 'Review Photo Proof');
      case ProofStatus.approved:
        return iconBtn(Icons.check_circle, Colors.green[600]!,
            widget.onViewProof, 'View Approved Proof');
      case ProofStatus.rejected:
        return iconBtn(Icons.cancel, Colors.red[400]!, null, 'Proof Rejected');
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStatusText() {
    final proofStatus = widget.proofStatus;
    if (proofStatus != null && proofStatus != ProofStatus.notRequired) {
      switch (proofStatus) {
        case ProofStatus.submitted:
          return 'Proof submitted — awaiting review';
        case ProofStatus.approved:
          return 'Proof approved ✓';
        case ProofStatus.rejected:
          return 'Proof was rejected — resubmit';
        default:
          break;
      }
    }

    // Show accountability task status when applicable — BEFORE generic checks
    // so pendingReview/approved override the raw isCompleted flag.
    // pending/requested stay gated behind isEditable — no fake "tap" labels on missed days.
    final accStatus = widget.accountabilityStatus;
    if (accStatus != null) {
      // For creator with pending accepted task and proof required, show upload prompt
      if (accStatus == AccountabilityTaskStatus.pending &&
          widget.isEditable &&
          (_hasAccountabilityConnection || _hasAccountabilityTask) &&
          !widget.isReviewOnly &&
          (proofStatus == null || proofStatus == ProofStatus.notRequired)) {
        return 'Proof required — upload photo';
      }

      switch (accStatus) {
        case AccountabilityTaskStatus.requested when !widget.isEditable:
          return 'Missed';
        case AccountabilityTaskStatus.pending when !widget.isEditable:
          // Non-editable past day — falls through to the generic 'Missed' check.
          break;
        case AccountabilityTaskStatus.requested:
          return 'Pending — awaiting your acceptance';
        case AccountabilityTaskStatus.pending:
          return 'Accepted — tap to complete';
        case AccountabilityTaskStatus.completed when !widget.isEditable:
          return 'Missed';
        case AccountabilityTaskStatus.completed:
          return 'Completed ✓';
        case AccountabilityTaskStatus.approved:
          return 'Partner approved ✓';
        case AccountabilityTaskStatus.declined:
          return 'Declined';
        case AccountabilityTaskStatus.pendingReview:
          return '⏳ Waiting for partner review';
        case AccountabilityTaskStatus.rejected:
          return '❌ Partner rejected — needs improvement';
        case AccountabilityTaskStatus.expired:
          return '⏰ Review expired — marked incomplete';
      }
    }

    if (widget.isCompleted) {
      return 'Completed ✓';
    }
    if (!widget.isEditable) {
      return 'Missed';
    }

    if (widget.challenge.reminderTime != null &&
        widget.challenge.isReminderEnabled) {
      final p = widget.partnerName;
      if (p != null && p.isNotEmpty) {
        return '👥 $p';
      }
      return 'Reminder: ${widget.challenge.reminderTime}';
    }
    if (widget.partnerName != null && widget.partnerName!.isNotEmpty) {
      return '👥 ${widget.partnerName}';
    }
    return 'Tap to complete';
  }

  void _showCompletionAnimation() {
    if (!widget.isEditable || !mounted) return;

    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Create overlay entry for celebration animation
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 50, // Fixed position at top, below status bar
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            child: Container(
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${widget.challenge.title} completed!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      _activeOverlayEntry = overlayEntry;

      // Remove overlay after animation
      Future.delayed(const Duration(milliseconds: 1200), () {
        overlayEntry.remove();
        if (_activeOverlayEntry == overlayEntry) {
          _activeOverlayEntry = null;
        }
      });
    });
  }
}
