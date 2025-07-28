import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/challenge.dart';
import 'challenge_icon_widget.dart';

class DailyTaskCard extends StatefulWidget {
  final Challenge challenge;
  final bool isCompleted;
  final bool isEditable;
  final Function(bool) onToggle;
  final Function(Challenge)? onReminderUpdate;
  final int? dayNumber;

  const DailyTaskCard({
    super.key,
    required this.challenge,
    required this.isCompleted,
    required this.isEditable,
    required this.onToggle,
    this.onReminderUpdate,
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
    
    // State variables for the modal
    bool tempReminderEnabled = widget.challenge.isReminderEnabled;
    String tempReminderType = 'once'; // Default type
    String tempReminderTime = widget.challenge.reminderTime ?? '09:00';
    int tempIntervalMinutes = 120; // Default 2 hours
    List<String> tempCustomTimes = widget.challenge.reminderTime != null 
        ? [widget.challenge.reminderTime!] 
        : ['09:00'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.notifications, color: Colors.orange[600], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Set Reminder',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enable/Disable Toggle
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications, color: Colors.orange[600], size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enable Reminders',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Get notified for this task',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: tempReminderEnabled,
                                onChanged: (value) {
                                  setModalState(() {
                                    tempReminderEnabled = value;
                                    if (value && tempReminderTime.isEmpty) {
                                      tempReminderTime = '09:00';
                                    }
                                  });
                                },
                                activeColor: Colors.orange[600],
                              ),
                            ],
                          ),
                        ),
                        
                        if (tempReminderEnabled) ...[
                          const SizedBox(height: 20),
                          
                          // Reminder Type Selection
                          Text(
                            'Reminder Type',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // All 5 reminder types with full functionality
                          _buildFunctionalReminderType(
                            'once',
                            'Once',
                            'Single reminder at specific time',
                            Icons.schedule_outlined,
                            tempReminderType,
                            (type) => setModalState(() => tempReminderType = type),
                          ),
                          _buildFunctionalReminderType(
                            'multiple',
                            'Multiple Times',
                            'Several reminders throughout the day',
                            Icons.schedule,
                            tempReminderType,
                            (type) => setModalState(() {
                              tempReminderType = type;
                              if (tempCustomTimes.length < 2) {
                                tempCustomTimes = ['09:00', '18:00'];
                              }
                            }),
                          ),
                          _buildFunctionalReminderType(
                            'hourly',
                            'Every Hour',
                            'Hourly reminders during active hours',
                            Icons.access_time,
                            tempReminderType,
                            (type) => setModalState(() => tempReminderType = type),
                          ),
                          _buildFunctionalReminderType(
                            'interval',
                            'Every X Hours',
                            'Regular intervals (15 min - 12 hours)',
                            Icons.timer,
                            tempReminderType,
                            (type) => setModalState(() => tempReminderType = type),
                          ),
                          _buildFunctionalReminderType(
                            'custom',
                            'Custom Schedule',
                            'Flexible timing for any pattern',
                            Icons.tune,
                            tempReminderType,
                            (type) => setModalState(() => tempReminderType = type),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Type-specific configuration
                          if (tempReminderType == 'once') ...[
                            _buildTimeSelector(
                              'Reminder Time',
                              tempReminderTime,
                              (time) => setModalState(() => tempReminderTime = time),
                            ),
                          ] else if (tempReminderType == 'multiple') ...[
                            _buildMultipleTimeSelector(
                              'Reminder Times',
                              tempCustomTimes,
                              (times) => setModalState(() => tempCustomTimes = times),
                            ),
                          ] else if (tempReminderType == 'hourly') ...[
                            _buildHourlyConfiguration(
                              tempReminderTime,
                              (time) => setModalState(() => tempReminderTime = time),
                            ),
                          ] else if (tempReminderType == 'interval') ...[
                            _buildIntervalConfiguration(
                              tempIntervalMinutes,
                              tempReminderTime,
                              (minutes) => setModalState(() => tempIntervalMinutes = minutes),
                              (time) => setModalState(() => tempReminderTime = time),
                            ),
                          ] else if (tempReminderType == 'custom') ...[
                            _buildCustomScheduleConfiguration(
                              tempCustomTimes,
                              (times) => setModalState(() => tempCustomTimes = times),
                            ),
                          ],
                          
                          const SizedBox(height: 30),
                        ] else ...[
                          const SizedBox(height: 20),
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
                                  'Enable reminders to configure settings',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Prepare reminder data based on type
                              String? finalReminderTime;
                              String? reminderData;
                              
                              if (tempReminderEnabled) {
                                switch (tempReminderType) {
                                  case 'once':
                                    finalReminderTime = tempReminderTime;
                                    reminderData = 'once:$tempReminderTime';
                                    break;
                                  case 'multiple':
                                    finalReminderTime = tempCustomTimes.first;
                                    reminderData = 'multiple:${tempCustomTimes.join(',')}';
                                    break;
                                  case 'hourly':
                                    finalReminderTime = tempReminderTime;
                                    reminderData = 'hourly:$tempReminderTime';
                                    break;
                                  case 'interval':
                                    finalReminderTime = tempReminderTime;
                                    reminderData = 'interval:$tempIntervalMinutes:$tempReminderTime';
                                    break;
                                  case 'custom':
                                    finalReminderTime = tempCustomTimes.first;
                                    reminderData = 'custom:${tempCustomTimes.join(',')}';
                                    break;
                                }
                              }
                              
                              // Update the challenge
                              final updatedChallenge = widget.challenge.copyWith(
                                isReminderEnabled: tempReminderEnabled,
                                reminderTime: finalReminderTime,
                              );
                              
                              widget.onReminderUpdate!(updatedChallenge);
                              Navigator.pop(context);
                              
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tempReminderEnabled 
                                        ? _getSuccessMessage(tempReminderType, tempReminderTime, tempCustomTimes, tempIntervalMinutes)
                                        : 'Reminder disabled',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                  ),
                                  backgroundColor: tempReminderEnabled ? Colors.green : Colors.orange,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              tempReminderEnabled ? 'Save Reminder Settings' : 'Disable Reminder',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFunctionalReminderType(
    String id,
    String title,
    String subtitle,
    IconData icon,
    String selectedType,
    Function(String) onSelect,
  ) {
    final isSelected = selectedType == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelect(id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.orange[300]! : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.orange[600] : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.orange[700] : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.orange[600],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String title, String currentTime, Function(String) onTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final timeParts = currentTime.split(':');
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              ),
            );
            
            if (time != null) {
              final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              onTimeChanged(timeString);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('h:mm a').format(
                      DateTime(2024, 1, 1, int.parse(currentTime.split(':')[0]), int.parse(currentTime.split(':')[1])),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleTimeSelector(String title, List<String> times, Function(List<String>) onTimesChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  if (!times.contains(timeString)) {
                    onTimesChanged([...times, timeString]..sort());
                  }
                }
              },
              icon: Icon(Icons.add, size: 16, color: Colors.orange[600]),
              label: Text(
                'Add Time',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.orange[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (times.isEmpty)
          Text(
            'No times added',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          )
        else
          Column(
            children: times.map((timeStr) {
              final timeParts = timeStr.split(':');
              final displayTime = DateFormat('h:mm a').format(
                DateTime(2024, 1, 1, int.parse(timeParts[0]), int.parse(timeParts[1])),
              );
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayTime,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(timeParts[0]),
                            minute: int.parse(timeParts[1]),
                          ),
                        );
                        if (time != null) {
                          final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          final newTimes = [...times];
                          final index = times.indexOf(timeStr);
                          newTimes[index] = timeString;
                          onTimesChanged(newTimes..sort());
                        }
                      },
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.orange[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (times.length > 1)
                      GestureDetector(
                        onTap: () {
                          final newTimes = [...times];
                          newTimes.remove(timeStr);
                          onTimesChanged(newTimes);
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red[600],
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHourlyConfiguration(String startTime, Function(String) onStartTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Time',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildTimeSelector('', startTime, onStartTimeChanged),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hourly reminders will continue until 10:00 PM or when you mark the task as complete',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalConfiguration(
    int intervalMinutes,
    String startTime,
    Function(int) onIntervalChanged,
    Function(String) onStartTimeChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interval',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildIntervalOption('15 min', 15, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('30 min', 30, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('1 hour', 60, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('2 hours', 120, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('3 hours', 180, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('4 hours', 240, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('6 hours', 360, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('8 hours', 480, intervalMinutes, onIntervalChanged),
            _buildIntervalOption('12 hours', 720, intervalMinutes, onIntervalChanged),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Start Time',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildTimeSelector('', startTime, onStartTimeChanged),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getIntervalDescription(intervalMinutes),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalOption(String label, int minutes, int currentInterval, Function(int) onIntervalChanged) {
    final isSelected = currentInterval == minutes;
    return GestureDetector(
      onTap: () => onIntervalChanged(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[600] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomScheduleConfiguration(List<String> times, Function(List<String>) onTimesChanged) {
    return _buildMultipleTimeSelector('Custom Times', times, onTimesChanged);
  }

  String _getIntervalDescription(int intervalMinutes) {
    if (intervalMinutes < 60) {
      return 'Reminder every $intervalMinutes minutes until task is completed';
    } else {
      final hours = intervalMinutes / 60;
      if (hours == hours.round()) {
        return 'Reminder every ${hours.round()} hour${hours > 1 ? 's' : ''} until task is completed';
      } else {
        return 'Reminder every ${hours.toStringAsFixed(1)} hours until task is completed';
      }
    }
  }

  String _getSuccessMessage(String type, String time, List<String> customTimes, int intervalMinutes) {
    switch (type) {
      case 'once':
        return 'Reminder set for ${DateFormat('h:mm a').format(DateTime(2024, 1, 1, int.parse(time.split(':')[0]), int.parse(time.split(':')[1])))}';
      case 'multiple':
        return 'Multiple reminders set (${customTimes.length} times)';
      case 'hourly':
        return 'Hourly reminders enabled starting at ${DateFormat('h:mm a').format(DateTime(2024, 1, 1, int.parse(time.split(':')[0]), int.parse(time.split(':')[1])))}';
      case 'interval':
        final hours = intervalMinutes / 60;
        final intervalText = intervalMinutes < 60 
            ? '$intervalMinutes minutes' 
            : hours == hours.round() 
                ? '${hours.round()} hour${hours > 1 ? 's' : ''}'
                : '${hours.toStringAsFixed(1)} hours';
        return 'Reminders set every $intervalText starting at ${DateFormat('h:mm a').format(DateTime(2024, 1, 1, int.parse(time.split(':')[0]), int.parse(time.split(':')[1])))}';
      case 'custom':
        return 'Custom reminder schedule set (${customTimes.length} time${customTimes.length > 1 ? 's' : ''})';
      default:
        return 'Reminder settings saved';
    }
  }

  Widget _buildGenericReminderType(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // For now, just show that it's selected
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title selected - Full implementation coming soon'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[600], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_completionController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCompleted ? _scaleAnimation.value : 
                 (widget.isEditable ? _pulseAnimation.value : 1.0),
          child: _buildCard(),
        );
      },
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced vertical margin
      child: Stack( // Use Stack to position alarm icon at top right
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
                      Colors.green[400]!.withOpacity(0.1),
                      Colors.green[600]!.withOpacity(0.05),
                    ]
                  : widget.isEditable
                      ? [
                          Colors.blue[400]!.withOpacity(0.1),
                          Colors.purple[400]!.withOpacity(0.05),
                        ]
                      : [
                          Colors.red[400]!.withOpacity(0.1),
                          Colors.orange[400]!.withOpacity(0.05),
                        ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isCompleted
                  ? [
                      Colors.green[400]!.withOpacity(0.5),
                      Colors.green[600]!.withOpacity(0.2),
                    ]
                  : widget.isEditable
                      ? [
                          Colors.blue[400]!.withOpacity(0.5),
                          Colors.purple[400]!.withOpacity(0.2),
                        ]
                      : [
                          Colors.red[400]!.withOpacity(0.5),
                          Colors.orange[400]!.withOpacity(0.2),
                        ],
            ),
            child: _buildCardContent(),
          ),
          
          // Alarm icon positioned at top right
          if (widget.challenge.isReminderEnabled && widget.challenge.reminderTime != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.isEditable ? _showGenericReminderSetup : null,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100]?.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
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
                        DateFormat('h:mm a').format(
                          DateTime(2024, 1, 1, 
                            int.parse(widget.challenge.reminderTime!.split(':')[0]), 
                            int.parse(widget.challenge.reminderTime!.split(':')[1])),
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // Optimized padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Better alignment
        children: [
          // Challenge Icon
          AnimatedChallengeIcon(
            challenge: widget.challenge,
            size: 44, // Optimized size
            onTap: widget.isEditable ? () => widget.onToggle(!widget.isCompleted) : null,
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
                    decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
              color: (widget.isCompleted ? Colors.green : Colors.red).withOpacity(0.3),
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
              color: (widget.isCompleted ? Colors.green : Colors.grey).withOpacity(0.3),
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
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isCompleted ? Icons.check : Icons.radio_button_unchecked,
                  size: 16,
                  color: widget.isCompleted ? Colors.green[600] : Colors.grey[600],
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
    if (widget.challenge.reminderTime != null && widget.challenge.isReminderEnabled) {
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
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
}
