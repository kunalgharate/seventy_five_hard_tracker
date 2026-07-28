import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';

class DisciplineHeatmap extends StatelessWidget {
  final List<DailyProgress> progressList;
  final int daysToShow;

  /// If provided, only these challenge IDs are counted in the ratio.
  /// Use to exclude Regular tasks from the discipline calculation.
  final Set<String>? challengeTaskIds;

  const DisciplineHeatmap({
    super.key,
    required this.progressList,
    this.daysToShow = 70, // 10 weeks
    this.challengeTaskIds,
  });

  @override
  Widget build(BuildContext context) {
    // Generate dates going backwards from today (normalized to local midnight)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      daysToShow,
      (index) => today.subtract(Duration(days: daysToShow - 1 - index)),
    );

    // Map date to its completion ratio (0.0 to 1.0)
    final Map<String, double> ratios = {};
    for (final p in progressList) {
      final dateStr = DateFormat('yyyy-MM-dd').format(p.date);
      // Filter completions to only challenge tasks if IDs are provided
      final entries = challengeTaskIds != null
          ? Map.fromEntries(p.challengeCompletions.entries
              .where((e) => challengeTaskIds!.contains(e.key)))
          : p.challengeCompletions;
      final total = entries.length;
      if (total > 0) {
        final completed = entries.values.where((v) => v).length;
        ratios[dateStr] = completed / total;
      }
      // Empty collections left absent — renders as "No data"
    }

    // Split into columns of 7 days (weeks)
    // We want the grid to flow top-to-bottom, then left-to-right.
    // So we need to group the dates into weeks.
    // To align properly, we find the weekday of the very first date.
    final firstDateWeekday = dates.first.weekday; // 1=Mon, 7=Sun
    // Pad the beginning with nulls to align the grid
    final paddedDates = <DateTime?>[];
    // Let's use Sunday=7, Monday=1. So if first is Wednesday(3), we pad 2 (Mon, Tue)
    final padCount = firstDateWeekday - 1;
    for (int i = 0; i < padCount; i++) {
      paddedDates.add(null);
    }
    paddedDates.addAll(dates);

    // Calculate number of columns needed
    final columns = (paddedDates.length / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discipline Heatmap',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 7 * 16.0, // 7 days * 16px height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: columns,
            itemBuilder: (context, colIndex) {
              return Column(
                children: List.generate(7, (rowIndex) {
                  final index = colIndex * 7 + rowIndex;
                  if (index >= paddedDates.length) {
                    return _buildEmptyBox();
                  }
                  final date = paddedDates[index];
                  if (date == null) {
                    return _buildEmptyBox();
                  }

                  final dateStr = DateFormat('yyyy-MM-dd').format(date);
                  final ratio = ratios[dateStr];
                  return _buildHeatBox(ratio, date);
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Less ',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            _buildHeatBox(0.0, null),
            _buildHeatBox(0.25, null),
            _buildHeatBox(0.5, null),
            _buildHeatBox(0.75, null),
            _buildHeatBox(1.0, null),
            const Text(' More',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        )
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildEmptyBox() {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeatBox(double? ratio, DateTime? date) {
    Color color;
    if (ratio == null) {
      color = Colors.grey[200]!; // No data
    } else if (ratio == 0) {
      color = Colors.grey[300]!; // 0%
    } else if (ratio < 0.4) {
      color = Colors.green[200]!;
    } else if (ratio < 0.7) {
      color = Colors.green[400]!;
    } else if (ratio < 1.0) {
      color = Colors.green[600]!;
    } else {
      color = Colors.green[800]!; // 100% completed
    }

    Widget box = Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
        border: ratio == null
            ? Border.all(color: Colors.grey[300]!, width: 0.5)
            : null,
      ),
    );

    if (date != null) {
      box = Tooltip(
        message: '${DateFormat('MMM d').format(date)}\n'
            '${ratio == null ? "No data" : "${(ratio * 100).toInt()}% completed"}',
        child: box,
      );
    }

    return box;
  }
}
