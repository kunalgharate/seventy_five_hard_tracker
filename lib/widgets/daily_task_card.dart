import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/ai_accountability/presentation/screens/ai_companion_screen.dart';
import 'apple_checkbox.dart';
import 'challenge_icon_widget.dart';
import 'reminder_bottom_sheet.dart';

class DailyTaskCard extends StatefulWidget {
  final Challenge challenge;
  final bool isCompleted;
  final bool isEditable;
  final Function(bool) onToggle;
  final Function(Challenge)? onReminderUpdate;
  final int? dayNumber;

  /// UID of the accountability partner assigned to this task.
  /// When set, only that person can check it — owner sees a lock icon instead.
  final String? accountablePartnerUid;

  /// Optional callback to remove this challenge from the active session.
  final VoidCallback? onRemove;

  /// Called after a partner is successfully assigned to this task.
  final VoidCallback? onPartnerAssigned;

  /// Display name of the accountability partner assigned to this task.
  final String? partnerName;

  const DailyTaskCard({
    super.key,
    required this.challenge,
    required this.isCompleted,
    required this.isEditable,
    required this.onToggle,
    this.onReminderUpdate,
    this.dayNumber,
    this.accountablePartnerUid,
    this.onRemove,
    this.onPartnerAssigned,
    this.partnerName,
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

  void _onMenuSelected(String value) {
    if (value == 'ai') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiCompanionScreen(
            taskName: widget.challenge.title,
            taskCompleted: widget.isCompleted,
          ),
        ),
      );
    } else if (value == 'human') {
      _showHumanPartnerPicker();
    } else if (value == 'remove') {
      if (widget.onRemove == null) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Remove Task?'),
          content: Text(
              'Remove "${widget.challenge.title}" from your active challenge?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                widget.onRemove!();
              },
              child:
                  const Text('Remove', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showHumanPartnerPicker() async {
    final partners = await AccountabilityService().fetchMyPartnerships();
    final accepted =
        partners.where((p) => p.status == PartnershipStatus.accepted).toList();

    if (!mounted) return;

    if (accepted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No accepted partners yet. Invite someone first.'),
          behavior: SnackBarBehavior.floating,
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
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Assign to Partner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                'Who should be held accountable for "${widget.challenge.title}"?',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 16),
            ...accepted.map((p) => ListTile(
                  leading:
                      Text(p.role.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.partnerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.role.label),
                  onTap: () async {
                    Navigator.pop(context);
                    // The accountable person is whoever is NOT the current user
                    final myUid = AccountabilityService().currentUid;
                    final otherUid =
                        p.ownerUid == myUid ? p.partnerUid : p.ownerUid;
                    if (otherUid == null) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final taskTitle = widget.challenge.title;
                    final partnerName = p.partnerName;

                    // Create the accountability task in Firestore
                    final task =
                        await AccountabilityService().createAccountabilityTask(
                      accountableUid: otherUid,
                      accountableName: partnerName,
                      partnershipId: p.id,
                      title: taskTitle,
                      description: 'Daily challenge task from 75 Hard',
                      challengeId: widget.challenge.id,
                    );

                    messenger.showSnackBar(SnackBar(
                      content: Text(task != null
                          ? '👥 "$taskTitle" assigned to $partnerName'
                          : 'Failed to assign task. Try again.'),
                      backgroundColor: task != null ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ));
                    if (task != null) widget.onPartnerAssigned?.call();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
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
            height: 80,
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

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8), // Optimized padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Completion checkbox (left)
          _buildCompletionWidget(),
          const SizedBox(width: 12),

          // Challenge Icon
          AnimatedChallengeIcon(
            challenge: widget.challenge,
            size: 44,
            onTap: widget.isEditable
                ? () => widget.onToggle(!widget.isCompleted)
                : null,
          ),
          const SizedBox(width: 14),

          // Challenge Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.challenge.title,
                  style: TextStyle(
                    fontSize: 16,
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
                const SizedBox(height: 3),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 12,
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

          // Reminder icon (right)
          if (widget.isEditable && !widget.challenge.isReminderEnabled)
            IconButton(
              onPressed: _showGenericReminderSetup,
              icon: Icon(
                Icons.alarm_add,
                color: Colors.grey[600],
                size: 20,
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Set Reminder',
            ),

          // ⋮ menu
          if (widget.isEditable)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onSelected: _onMenuSelected,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'ai',
                  child: Row(children: [
                    Text('🤖', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Text('AI Accountability'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'human',
                  child: Row(children: [
                    Text('👥', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Text('Human Partner'),
                  ]),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompletionWidget() {
    // If a partner is assigned, only they can check it
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final hasPartner = widget.accountablePartnerUid != null &&
        widget.accountablePartnerUid!.isNotEmpty;
    final iAmAccountable = !hasPartner || widget.accountablePartnerUid == myUid;

    if (!widget.isEditable) {
      // Show status icon for non-editable cards
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

    // If partner is assigned and current user is NOT the partner — show lock
    if (hasPartner && !iAmAccountable) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
      );
    }

    // Interactive completion toggle — Apple-style checkbox
    return AppleCheckbox(
      isChecked: widget.isCompleted,
      isEnabled: widget.isEditable && iAmAccountable,
      onChanged: (value) => widget.onToggle(value),
    );
  }

  String _getStatusText() {
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
