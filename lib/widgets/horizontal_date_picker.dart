import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'smooth_scroll_behavior.dart';

class HorizontalDatePicker extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime) onDateSelected;
  final List<DateTime>? completedDates;
  final List<DateTime>? incompleteDates;

  const HorizontalDatePicker({
    super.key,
    required this.selectedDate,
    required this.startDate,
    required this.endDate,
    required this.onDateSelected,
    this.completedDates,
    this.incompleteDates,
  });

  @override
  State<HorizontalDatePicker> createState() => _HorizontalDatePickerState();
}

class _HorizontalDatePickerState extends State<HorizontalDatePicker> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Auto-scroll to selected date after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  void didUpdateWidget(HorizontalDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _scrollToSelectedDate();
    }
  }

  void _scrollToSelectedDate() {
    if (!_scrollController.hasClients) return;
    
    final daysDifference = widget.selectedDate.difference(widget.startDate).inDays;
    final itemWidth = 68.0; // Width of each date item
    final screenWidth = MediaQuery.of(context).size.width;
    final scrollPosition = (daysDifference * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    
    // Clamp the scroll position to valid range
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetPosition = scrollPosition.clamp(0.0, maxScroll);
    
    // Only animate if the position is significantly different
    final currentPosition = _scrollController.offset;
    if ((targetPosition - currentPosition).abs() > 50) {
      _scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(widget.selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFA726),
                  ),
                ),
                Text(
                  'Day ${widget.selectedDate.difference(widget.startDate).inDays + 1} of 75',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: widget.endDate.difference(widget.startDate).inDays + 1,
              itemBuilder: (context, index) {
                final date = widget.startDate.add(Duration(days: index));
                final isSelected = _isSameDay(date, widget.selectedDate);
                final isToday = _isSameDay(date, DateTime.now());
                final isCompleted = widget.completedDates?.any((d) => _isSameDay(d, date)) ?? false;
                final isIncomplete = widget.incompleteDates?.any((d) => _isSameDay(d, date)) ?? false;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        print('Date tapped: $date'); // Debug print
                        widget.onDateSelected(date);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: isSelected
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFA726),
                                    Color(0xFFFF7043),
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : isToday
                                  ? Colors.blue[50]
                                  : Colors.grey[100],
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : isToday
                                    ? Colors.blue[300]!
                                    : Colors.grey[300]!,
                            width: isToday ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFA726).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? Colors.blue[700]
                                        : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? Colors.blue[700]
                                        : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Progress indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isCompleted || isIncomplete)
                                    ? (isSelected
                                        ? Colors.white
                                        : isCompleted
                                            ? Colors.green[600]
                                            : Colors.red[600])
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
