import 'package:flutter/material.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';

class ProgressStats extends StatelessWidget {
  final int currentDay;
  final int totalDays;
  final ChallengeSession session;
  final List<DailyProgress> progress;

  const ProgressStats({
    super.key,
    required this.currentDay,
    required this.totalDays,
    required this.session,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final completedDays = progress.where((p) => p.isCompleted).length;
    final progressPercentage = (completedDays / totalDays * 100).clamp(0, 100);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day $currentDay of $totalDays',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Started: ${_formatDate(session.startDate)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                CircularProgressIndicator(
                  value: progressPercentage / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressPercentage == 100 ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progressPercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progressPercentage == 100 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedDays days completed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${progressPercentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStreakInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfo() {
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    // Calculate streaks
    final sortedProgress = progress.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (int i = 0; i < sortedProgress.length; i++) {
      if (sortedProgress[i].isCompleted) {
        tempStreak++;
        if (i == sortedProgress.length - 1) {
          currentStreak = tempStreak;
        }
      } else {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 0;
        currentStreak = 0;
      }
    }

    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Current Streak', '$currentStreak days', Icons.local_fire_department),
        _buildStatItem('Best Streak', '$longestStreak days', Icons.emoji_events),
        _buildStatItem('Remaining', '${totalDays - currentDay + 1} days', Icons.schedule),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
