import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
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

class DailyTaskCard extends StatefulWidget {
  final Challenge challenge;
  final bool isCompleted;
  final bool isEditable;
  final Function(bool) onToggle;
  final Function(Challenge)? onReminderUpdate;
  final VoidCallback? onRemove;
  final int? dayNumber;
  final String? accountablePartnerUid;
  final String? partnerName;
  final AccountabilityTaskStatus? accountabilityStatus;
  final ProofStatus? proofStatus;
  final VoidCallback? onSubmitProof;
  final VoidCallback? onReviewProof;
  final VoidCallback? onViewProof;

  const DailyTaskCard({
    super.key,
    required this.challenge,
    required this.isCompleted,
    required this.isEditable,
    required this.onToggle,
    this.onReminderUpdate,
    this.onRemove,
    this.dayNumber,
    this.accountablePartnerUid,
    this.partnerName,
    this.accountabilityStatus,
    this.proofStatus,
    this.onSubmitProof,
    this.onReviewProof,
    this.onViewProof,
  });

  @override
  State<DailyTaskCard> createState() => _DailyTaskCardState();
}

class _DailyTaskCardState extends State<DailyTaskCard>
    with TickerProviderStateMixin {
  late AnimationController _completionController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
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

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _completionController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

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

  void _confirmRemoveTask() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Task?'),
        content: const Text(
          'This will remove the task from your active challenge. Your existing progress for other tasks will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onRemove!();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
    return AnimatedBuilder(
      animation: Listenable.merge([_completionController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCompleted
              ? _scaleAnimation.value
              : (widget.isEditable ? _pulseAnimation.value : 1.0),
          child: _buildCard(),
        );
      },
    );
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
                      Text(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          GlassmorphicContainer(
            width: double.infinity,
            height: 88,
            borderRadius: 16,
            blur: 20,
            alignment: Alignment.bottomCenter,
            border: 2,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isCompleted
                  ? [
                      Colors.green[400]!.withValues(alpha: 0.1),
                      Colors.green[600]!.withValues(alpha: 0.05),
                    ]
                  : widget.isEditable
                      ? [
                          Colors.blue[400]!.withValues(alpha: 0.1),
                          Colors.purple[400]!.withValues(alpha: 0.05),
                        ]
                      : [
                          Colors.red[400]!.withValues(alpha: 0.1),
                          Colors.orange[400]!.withValues(alpha: 0.05),
                        ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isCompleted
                  ? [
                      Colors.green[400]!.withValues(alpha: 0.5),
                      Colors.green[600]!.withValues(alpha: 0.2),
                    ]
                  : widget.isEditable
                      ? [
                          Colors.blue[400]!.withValues(alpha: 0.5),
                          Colors.purple[400]!.withValues(alpha: 0.2),
                        ]
                      : [
                          Colors.red[400]!.withValues(alpha: 0.5),
                          Colors.orange[400]!.withValues(alpha: 0.2),
                        ],
            ),
            child: _buildCardContent(),
          ),
        ],
      ),
    ).animate().slideX(delay: ((widget.dayNumber ?? 0) * 100).ms);
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
                    !_isRequestedAndUnaccepted())
                ? () => widget.onToggle(!widget.isCompleted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
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
                            ? Colors.grey[800]
                            : Colors.red[700],
                    decoration:
                        widget.isCompleted ? TextDecoration.lineThrough : null,
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

    if (widget.isEditable && _hasAccountabilityConnection) {
      actions.add(_buildProofButton());
    }

    // Remove task option (long-press or explicit button)
    if (widget.isEditable && widget.onRemove != null) {
      actions.add(IconButton(
        onPressed: () => _confirmRemoveTask(),
        icon:
            Icon(Icons.delete_outline, color: Colors.red[300], size: iconSize),
        padding: EdgeInsets.zero,
        constraints:
            const BoxConstraints(minWidth: btnSize, minHeight: btnSize),
        tooltip: 'Remove Task',
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map((w) => Padding(
                padding: const EdgeInsets.only(left: 2),
                child: w,
              ))
          .toList(),
    );
  }

  bool _isRequestedAndUnaccepted() {
    return widget.accountabilityStatus == AccountabilityTaskStatus.requested;
  }

  Widget _buildCompletionWidget() {
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
      onChanged: (value) => widget.onToggle(value),
    );
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

    // ── CREATOR (assigned this task to a collaborator) ──
    if (isCreator) {
      if (status == null || status == ProofStatus.not_required) {
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
    if (status == null || status == ProofStatus.not_required) {
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
    if (proofStatus != null && proofStatus != ProofStatus.not_required) {
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

    if (widget.isCompleted) {
      return 'Completed ✓';
    }
    if (!widget.isEditable) {
      return 'Missed';
    }

    // Show accountability task status when applicable
    final accStatus = widget.accountabilityStatus;
    if (accStatus != null) {
      // For creator with pending accepted task and proof required, show upload prompt
      if (accStatus == AccountabilityTaskStatus.pending &&
          _hasAccountabilityConnection &&
          (proofStatus == null || proofStatus == ProofStatus.not_required)) {
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        if (_isAssigner(myUid)) {
          return 'Proof required — upload photo';
        }
      }

      switch (accStatus) {
        case AccountabilityTaskStatus.requested:
          return 'Pending — awaiting your acceptance';
        case AccountabilityTaskStatus.pending:
          return 'Accepted — tap to complete';
        case AccountabilityTaskStatus.completed:
          return 'Completed ✓';
        case AccountabilityTaskStatus.approved:
          return 'Approved ✓';
        case AccountabilityTaskStatus.declined:
          return 'Declined';
      }
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
