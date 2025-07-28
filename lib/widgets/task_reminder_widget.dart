import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../models/challenge.dart';

class TaskReminderWidget extends StatefulWidget {
  final Challenge challenge;
  final DateTime selectedDate;
  final TaskReminder? existingReminder;
  final Function(TaskReminder) onReminderUpdated;
  final Function(DateTime) onTaskCompleted;
  final Function(DateTime) onTaskUncompleted;
  final bool isEditable;

  const TaskReminderWidget({
    super.key,
    required this.challenge,
    required this.selectedDate,
    this.existingReminder,
    required this.onReminderUpdated,
    required this.onTaskCompleted,
    required this.onTaskUncompleted,
    this.isEditable = true,
  });

  @override
  State<TaskReminderWidget> createState() => _TaskReminderWidgetState();
}

class _TaskReminderWidgetState extends State<TaskReminderWidget> {
  bool _isExpanded = false;
  late TaskReminder _reminder;

  @override
  void initState() {
    super.initState();
    _reminder = widget.existingReminder ?? _createDefaultReminder();
  }

  TaskReminder _createDefaultReminder() {
    // Create default reminder based on challenge type
    ReminderType defaultType;
    List<DateTime> defaultTimes = [];
    int intervalHours = 1;
    DateTime startTime = DateTime(2024, 1, 1, 7, 0); // 7 AM
    DateTime endTime = DateTime(2024, 1, 1, 22, 0); // 10 PM

    switch (widget.challenge.title.toLowerCase()) {
      case 'drink water':
        defaultType = ReminderType.hourly;
        startTime = DateTime(2024, 1, 1, 7, 0);
        endTime = DateTime(2024, 1, 1, 22, 0);
        break;
      case 'take vitamins':
      case 'take medicine':
        defaultType = ReminderType.interval;
        intervalHours = 8; // Every 8 hours
        defaultTimes = [
          DateTime(2024, 1, 1, 8, 0), // 8 AM
          DateTime(2024, 1, 1, 16, 0), // 4 PM
        ];
        break;
      case 'workout':
      case 'gym':
        defaultType = ReminderType.daily;
        defaultTimes = [
          DateTime(2024, 1, 1, 6, 0), // 6 AM
          DateTime(2024, 1, 1, 18, 0), // 6 PM
        ];
        break;
      default:
        defaultType = ReminderType.daily;
        defaultTimes = [DateTime(2024, 1, 1, 9, 0)]; // 9 AM
    }

    return TaskReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      challengeId: widget.challenge.id,
      type: defaultType,
      customTimes: defaultTimes,
      intervalHours: intervalHours,
      startTime: startTime,
      endTime: endTime,
      createdAt: DateTime.now(),
    );
  }

  Color _getTaskColor() {
    switch (widget.challenge.title.toLowerCase()) {
      case 'drink water':
        return Colors.blue;
      case 'take vitamins':
      case 'take medicine':
        return Colors.green;
      case 'workout':
      case 'gym':
        return Colors.red;
      default:
        return const Color(0xFFFFA726);
    }
  }

  IconData _getTaskIcon() {
    switch (widget.challenge.title.toLowerCase()) {
      case 'drink water':
        return Icons.water_drop;
      case 'take vitamins':
      case 'take medicine':
        return Icons.medication;
      case 'workout':
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.notifications;
    }
  }

  void _toggleTaskCompletion(DateTime dateTime) {
    if (_reminder.isTimeCompleted(dateTime)) {
      widget.onTaskUncompleted(dateTime);
      setState(() {
        _reminder.completedTimes.removeWhere((time) =>
            time.year == dateTime.year &&
            time.month == dateTime.month &&
            time.day == dateTime.day &&
            time.hour == dateTime.hour &&
            (_reminder.type == ReminderType.custom || _reminder.type == ReminderType.daily
                ? time.minute == dateTime.minute
                : true));
      });
    } else {
      widget.onTaskCompleted(dateTime);
      setState(() {
        _reminder.completedTimes.add(dateTime);
      });
    }
    widget.onReminderUpdated(_reminder);
  }

  @override
  Widget build(BuildContext context) {
    final taskColor = _getTaskColor();
    final taskIcon = _getTaskIcon();
    final reminderTimes = _reminder.getReminderTimesForDate(widget.selectedDate);
    final completionPercentage = _reminder.getCompletionPercentageForDate(widget.selectedDate);
    final completedCount = _reminder.getCompletionCountForDate(widget.selectedDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    taskColor.withOpacity(0.1),
                    taskColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: taskColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      taskIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.challenge.title} Reminders',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _getReminderDescription(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: completionPercentage >= 1.0 ? Colors.green[100] : taskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedCount/${reminderTimes.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: completionPercentage >= 1.0 ? Colors.green[700] : taskColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reminder type selector
                  _buildReminderTypeSelector(),
                  
                  const SizedBox(height: 16),
                  
                  // Reminder times display
                  _buildReminderTimesDisplay(reminderTimes, taskColor),
                  
                  const SizedBox(height: 16),
                  
                  // Progress bar
                  _buildProgressBar(completionPercentage, taskColor),
                  
                  const SizedBox(height: 16),
                  
                  // Quick actions
                  _buildQuickActions(taskColor),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getReminderDescription() {
    switch (_reminder.type) {
      case ReminderType.hourly:
        return 'Every hour from ${DateFormat('h a').format(_reminder.startTime)} to ${DateFormat('h a').format(_reminder.endTime)}';
      case ReminderType.interval:
        return 'Every ${_reminder.intervalHours} hours';
      case ReminderType.daily:
        return '${_reminder.customTimes.length} time${_reminder.customTimes.length > 1 ? 's' : ''} daily';
      case ReminderType.custom:
        return '${_reminder.customTimes.length} custom reminder${_reminder.customTimes.length > 1 ? 's' : ''}';
    }
  }

  Widget _buildReminderTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminder Type',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ReminderType.values.map((type) {
            final isSelected = _reminder.type == type;
            return FilterChip(
              label: Text(
                _getReminderTypeLabel(type),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: isSelected,
              onSelected: widget.isEditable ? (selected) {
                if (selected) {
                  setState(() {
                    _reminder.type = type;
                  });
                  widget.onReminderUpdated(_reminder);
                }
              } : null,
              selectedColor: _getTaskColor(),
              backgroundColor: Colors.grey[100],
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getReminderTypeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.hourly:
        return 'Hourly';
      case ReminderType.interval:
        return 'Interval';
      case ReminderType.daily:
        return 'Daily';
      case ReminderType.custom:
        return 'Custom';
    }
  }

  Widget _buildReminderTimesDisplay(List<DateTime> reminderTimes, Color taskColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Reminders',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        if (reminderTimes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'No reminders set for today',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: reminderTimes.length,
            itemBuilder: (context, index) {
              final time = reminderTimes[index];
              final isCompleted = _reminder.isTimeCompleted(time);
              final isPast = DateTime.now().isAfter(time);
              
              return InkWell(
                onTap: widget.isEditable ? () => _toggleTaskCompletion(time) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? taskColor
                        : isPast 
                            ? Colors.red[100]
                            : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted 
                          ? taskColor
                          : isPast 
                              ? Colors.red[300]!
                              : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCompleted ? _getTaskIcon() : Icons.schedule,
                        color: isCompleted 
                            ? Colors.white
                            : isPast 
                                ? Colors.red[600]
                                : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('h:mm a').format(time),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isCompleted 
                              ? Colors.white
                              : isPast 
                                  ? Colors.red[600]
                                  : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProgressBar(double completionPercentage, Color taskColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Progress',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${(completionPercentage * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: completionPercentage >= 1.0 ? Colors.green[700] : taskColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: completionPercentage,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            completionPercentage >= 1.0 ? Colors.green[500]! : taskColor,
          ),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildQuickActions(Color taskColor) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.isEditable ? _showReminderSettings : null,
            icon: const Icon(Icons.settings, size: 18),
            label: Text(
              'Settings',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: taskColor,
              side: BorderSide(color: taskColor.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.isEditable ? _markNowCompleted : null,
            icon: Icon(_getTaskIcon(), size: 18),
            label: Text(
              'Mark Now',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: taskColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showReminderSettings() {
    // TODO: Implement reminder settings dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reminder Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Reminder settings will be implemented here.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(color: _getTaskColor()),
            ),
          ),
        ],
      ),
    );
  }

  void _markNowCompleted() {
    final now = DateTime.now();
    final currentTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      now.hour,
      now.minute,
    );
    _toggleTaskCompletion(currentTime);
  }
}
