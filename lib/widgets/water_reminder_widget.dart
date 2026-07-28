import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/core/constants/app_constants.dart';
import 'liquid_wave_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WaterReminderWidget extends StatefulWidget {
  final DateTime selectedDate;
  final List<DateTime> completedTimes;
  final Function(DateTime) onWaterLogged;
  final Function(DateTime) onWaterRemoved;
  final bool isEditable;

  const WaterReminderWidget({
    super.key,
    required this.selectedDate,
    required this.completedTimes,
    required this.onWaterLogged,
    required this.onWaterRemoved,
    this.isEditable = true,
  });

  @override
  State<WaterReminderWidget> createState() => _WaterReminderWidgetState();
}

class _WaterReminderWidgetState extends State<WaterReminderWidget> {
  bool _isExpanded = false;

  final List<int> _defaultHours = [
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22
  ];

  int get _completedCount {
    return widget.completedTimes
        .where((time) =>
            time.day == widget.selectedDate.day &&
            time.month == widget.selectedDate.month &&
            time.year == widget.selectedDate.year)
        .length;
  }

  bool _isTimeCompleted(int hour) {
    return widget.completedTimes.any((time) =>
        time.day == widget.selectedDate.day &&
        time.month == widget.selectedDate.month &&
        time.year == widget.selectedDate.year &&
        time.hour == hour);
  }

  void _toggleWaterIntake(int hour) {
    final dateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      hour,
    );

    if (_isTimeCompleted(hour)) {
      widget.onWaterRemoved(dateTime);
    } else {
      widget.onWaterLogged(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int count = _completedCount;
    final double percent = (count / kWaterGoal).clamp(0.0, 1.0);
    final bool isDone = count >= kWaterGoal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isDone ? 8 : 2,
      shadowColor: isDone ? Colors.blue.withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: SizedBox(
                height: 100,
                child: Stack(
                  children: [
                    // The animated liquid wave background
                    Positioned.fill(
                      child: LiquidWaveIndicator(
                        value: percent,
                        valueColor:
                            isDone ? Colors.blue[400]! : Colors.blue[300]!,
                        backgroundColor: Colors.blue[50]!,
                      ),
                    ),

                    // The foreground content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: Icon(
                              Icons.water_drop,
                              color:
                                  isDone ? Colors.blue[600] : Colors.blue[400],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1 Gallon Water',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDone ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  isDone
                                      ? 'Hydration complete!'
                                      : '$count of 8 glasses',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDone
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: isDone ? Colors.white : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content with staggered animations
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Log Now / Custom Time button
                    if (widget.isEditable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _logNow,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Log Now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue[700],
                                  side: BorderSide(color: Colors.blue[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _addCustomTime,
                                icon: const Icon(Icons.access_time, size: 18),
                                label: const Text('Custom'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue[700],
                                  side: BorderSide(color: Colors.blue[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Preset hour chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _defaultHours.map((hour) {
                        final isCompleted = _isTimeCompleted(hour);
                        return InkWell(
                          onTap: widget.isEditable
                              ? () => _toggleWaterIntake(hour)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 70,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.blue[50]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.blue[200]!
                                    : Colors.grey[300]!,
                                width: isCompleted ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.water_drop
                                      : Icons.water_drop_outlined,
                                  color:
                                      isCompleted ? Colors.blue : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatHour(hour),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCompleted
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCompleted
                                        ? Colors.blue[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Show custom-time entries (outside 7-22 range)
                    if (_customTimeEntries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Custom entries',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _customTimeEntries.map((dt) {
                          return Chip(
                            label: Text(
                              _formatTime(dt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: widget.isEditable
                                ? const Icon(Icons.close, size: 16)
                                : null,
                            onDeleted: widget.isEditable
                                ? () => widget.onWaterRemoved(dt)
                                : null,
                            backgroundColor: Colors.blue[50],
                            side: BorderSide(color: Colors.blue[200]!),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ).animate().fadeIn().slideY(begin: 0.1),
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    ).animate(target: isDone ? 1 : 0).shimmer(duration: 2000.ms);
  }

  /// Entries logged at times outside the default 7-22 preset range.
  List<DateTime> get _customTimeEntries {
    return widget.completedTimes.where((time) {
      if (time.day != widget.selectedDate.day ||
          time.month != widget.selectedDate.month ||
          time.year != widget.selectedDate.year) {
        return false;
      }
      // Not covered by any preset hour
      return !_defaultHours.any((h) => time.hour == h);
    }).toList()
      ..sort((a, b) => a.compareTo(b));
  }

  void _logNow() {
    if (!widget.isEditable) return;
    widget.onWaterLogged(DateTime.now());
  }

  void _addCustomTime() {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    ).then((time) {
      if (time != null && widget.isEditable) {
        final dateTime = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          time.hour,
          time.minute,
        );
        widget.onWaterLogged(dateTime);
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour $period';
  }
}
