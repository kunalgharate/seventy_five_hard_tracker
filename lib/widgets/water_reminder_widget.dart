import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
  
  // Default hourly reminders from 7 AM to 10 PM
  final List<int> _defaultHours = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];

  bool _isTimeCompleted(int hour) {
    return widget.completedTimes.any((time) => 
      time.day == widget.selectedDate.day &&
      time.month == widget.selectedDate.month &&
      time.year == widget.selectedDate.year &&
      time.hour == hour
    );
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

  void _addCustomTime() {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: const Color(0xFFFFA726),
              dayPeriodTextColor: const Color(0xFFFFA726),
            ),
          ),
          child: child!,
        );
      },
    ).then((time) {
      if (time != null) {
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

  int get _completedCount {
    return widget.completedTimes.where((time) => 
      time.day == widget.selectedDate.day &&
      time.month == widget.selectedDate.month &&
      time.year == widget.selectedDate.year
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().day == widget.selectedDate.day &&
        DateTime.now().month == widget.selectedDate.month &&
        DateTime.now().year == widget.selectedDate.year;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Colors.blue[100]!.withOpacity(0.3),
                    Colors.cyan[50]!.withOpacity(0.2),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[500],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.water_drop,
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
                          'Water Intake Tracker',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '$_completedCount glasses logged today',
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
                      color: _completedCount >= 8 ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_completedCount/8',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _completedCount >= 8 ? Colors.green[700] : Colors.orange[700],
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hourly Water Reminders',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Hourly grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _defaultHours.length,
                    itemBuilder: (context, index) {
                      final hour = _defaultHours[index];
                      final isCompleted = _isTimeCompleted(hour);
                      final isPast = isToday && DateTime.now().hour > hour;
                      
                      return InkWell(
                        onTap: widget.isEditable ? () => _toggleWaterIntake(hour) : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCompleted 
                                ? Colors.blue[500]
                                : isPast 
                                    ? Colors.red[100]
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCompleted 
                                  ? Colors.blue[700]!
                                  : isPast 
                                      ? Colors.red[300]!
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isCompleted ? Icons.water_drop : Icons.water_drop_outlined,
                                color: isCompleted 
                                    ? Colors.white
                                    : isPast 
                                        ? Colors.red[600]
                                        : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('h a').format(DateTime(2024, 1, 1, hour)),
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
                  
                  const SizedBox(height: 16),
                  
                  // Custom time and quick actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.isEditable ? _addCustomTime : null,
                          icon: const Icon(Icons.add_alarm, size: 18),
                          label: Text(
                            'Custom Time',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[600],
                            side: BorderSide(color: Colors.blue[300]!),
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
                          onPressed: widget.isEditable ? () => _toggleWaterIntake(DateTime.now().hour) : null,
                          icon: const Icon(Icons.water_drop, size: 18),
                          label: Text(
                            'Log Now',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[500],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Goal Progress',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${(_completedCount / 8 * 100).round()}%',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _completedCount >= 8 ? Colors.green[700] : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_completedCount / 8).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _completedCount >= 8 ? Colors.green[500]! : Colors.blue[500]!,
                        ),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
