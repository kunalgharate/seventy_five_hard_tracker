import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/challenge.dart';
import 'challenge_icon_widget.dart';
import 'reminder_bottom_sheet.dart';
import 'task_note_bottom_sheet.dart';

class DailyTaskCard extends StatefulWidget {
  final Challenge challenge;
  final bool isCompleted;
  final bool isEditable;
  final Function(bool) onToggle;
  final Function(Challenge)? onReminderUpdate;
  final Function(String)? onNoteAdded;
  final String? existingNote;
  final int? dayNumber;

  const DailyTaskCard({
    super.key,
    required this.challenge,
    required this.isCompleted,
    required this.isEditable,
    required this.onToggle,
    this.onReminderUpdate,
    this.onNoteAdded,
    this.existingNote,
    this.dayNumber,
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

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 6), // Reduced vertical margin
      child: Stack(
        // Use Stack to position alarm icon at top right
        children: [
          GlassmorphicContainer(
            width: double.infinity,
            height: 85, // Optimized height
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

          // Alarm icon positioned at top right
          if (widget.challenge.isReminderEnabled &&
              widget.challenge.reminderTime != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.isEditable ? _showGenericReminderSetup : null,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100]?.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm,
                        color: Colors.orange[700],
                        size: 14,
                      ),
                      const SizedBox(width: 4),
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
        ],
      ),
    ).animate().slideX(delay: ((widget.dayNumber ?? 0) * 100).ms);
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8), // Optimized padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Better alignment
        children: [
          // Challenge Icon
          AnimatedChallengeIcon(
            challenge: widget.challenge,
            size: 44, // Optimized size
            onTap: widget.isEditable
                ? () => widget.onToggle(!widget.isCompleted)
                : null,
          ),
          const SizedBox(width: 14), // Optimized spacing

          // Challenge Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title with better space utilization
                Text(
                  widget.challenge.title,
                  style: TextStyle(
                    fontSize: 16, // Restored to 16 for better readability
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
                    height: 1.2, // Tighter line height
                  ),
                  maxLines: 2, // Allow 2 lines for longer titles
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3), // Minimal spacing
                // Status text
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 12, // Restored to 12 for readability
                    color: widget.isCompleted
                        ? Colors.green[600]
                        : widget.isEditable
                            ? Colors.grey[600]
                            : Colors.red[600],
                    fontWeight: FontWeight.w500,
                    height: 1.1, // Tight line height
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Reminder and completion section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Note Icon
              if (widget.isEditable)
                IconButton(
                  onPressed: () => _showNoteBottomSheet(context),
                  icon: Icon(
                    widget.existingNote != null &&
                            widget.existingNote!.isNotEmpty
                        ? Icons.note
                        : Icons.note_add_outlined,
                    color: widget.existingNote != null &&
                            widget.existingNote!.isNotEmpty
                        ? Colors.blue[700]
                        : Colors.grey[600],
                    size: 20,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Add Note',
                ),

              // Generic Reminder Setup Icon (only when no reminder is set)
              if (widget.isEditable && !widget.challenge.isReminderEnabled)
                IconButton(
                  onPressed: _showGenericReminderSetup,
                  icon: Icon(
                    Icons.alarm_add,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Set Reminder',
                ),

              // Completion Button/Status
              _buildCompletionWidget(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionWidget() {
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

    // Interactive completion toggle for editable cards - more user-friendly design
    return GestureDetector(
      onTap: () => widget.onToggle(!widget.isCompleted),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50, // Fixed width for better touch target
        height: 32, // Fixed height
        decoration: BoxDecoration(
          color: widget.isCompleted ? Colors.green[600] : Colors.grey[300],
          borderRadius: BorderRadius.circular(16), // Pill shape
          boxShadow: [
            BoxShadow(
              color: (widget.isCompleted ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: widget.isCompleted ? 22 : 4,
              top: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isCompleted
                      ? Icons.check
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color:
                      widget.isCompleted ? Colors.green[600] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
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
      return 'Reminder: ${widget.challenge.reminderTime}';
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

      // Remove overlay after animation with fade out
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          overlayEntry.remove();
        }
      });
    });
  }

  void _showNoteBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskNoteBottomSheet(
        taskTitle: widget.challenge.title,
        existingNote: widget.existingNote,
        onSave: (note) {
          if (widget.onNoteAdded != null) {
            widget.onNoteAdded!(note);
          }
        },
      ),
    );
  }
}
