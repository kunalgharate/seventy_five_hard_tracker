import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';

/// Insights screen — real data from ChallengeBloc.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[900]! : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.grey[900]!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Insights',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          if (state is! ChallengeLoaded || !state.hasActiveSession) {
            return Center(
              child: Text('Start a challenge to see insights.',
                  style: TextStyle(color: Colors.grey[500])),
            );
          }
          return _InsightsBody(state: state);
        },
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  final ChallengeLoaded state;
  const _InsightsBody({required this.state});

  int _computeStreak(List<DailyProgress> progress) {
    int streak = 0;
    final sorted = [...progress]..sort((a, b) => b.date.compareTo(a.date));
    for (final p in sorted) {
      if (p.isCompleted) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeBestStreak(List<DailyProgress> progress) {
    int best = 0, current = 0;
    final sorted = [...progress]..sort((a, b) => a.date.compareTo(b.date));
    for (final p in sorted) {
      if (p.isCompleted) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;

    final progress = state.currentProgress;
    final session = state.activeSession!;
    final totalDays = progress.length;
    final completedDays = progress.where((p) => p.isCompleted).length;
    final pct = totalDays > 0 ? (completedDays / totalDays * 100) : 0.0;
    final streak = _computeStreak(progress);
    final bestStreak = _computeBestStreak(progress);

    // Task performance: count per challenge
    final challenges = session.challenges;
    final taskStats = <String, (int completed, int total)>{};
    for (final c in challenges) {
      int done = 0, total = 0;
      for (final p in progress) {
        if (p.challengeCompletions.containsKey(c.id)) {
          total++;
          if (p.challengeCompletions[c.id] == true) done++;
        }
      }
      taskStats[c.title] = (done, total);
    }

    // Weekly trend (last 7 days)
    final now = DateTime.now();
    final weekDays = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final match = progress.where((p) =>
          p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day);
      return (date, match.isNotEmpty && match.first.isCompleted);
    });

    final taskColors = [
      Colors.blue,
      Colors.purple,
      Colors.deepOrange,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Stat cards ──
        _StatCard(
          cardBg: cardBg,
          textColor: textColor,
          title: 'Completion Rate',
          value: '${pct.toStringAsFixed(0)}%',
          icon: Icons.trending_up,
          color: Colors.green,
          subtitle: '$completedDays of $totalDays days',
        ),
        const SizedBox(height: 12),
        _StatCard(
          cardBg: cardBg,
          textColor: textColor,
          title: 'Current Streak',
          value: '$streak days',
          icon: Icons.local_fire_department,
          color: Colors.orange,
          subtitle: 'Best: $bestStreak days',
        ),
        const SizedBox(height: 24),

        // ── Weekly trend ──
        Text('Weekly Trend',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 12),
        Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weekDays.map((d) {
              final dayNames = [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun'
              ];
              final label = dayNames[d.$1.weekday - 1];
              final done = d.$2;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 28,
                    height: done ? 80 : 20,
                    decoration: BoxDecoration(
                      color: done ? Colors.green : Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // ── Task performance ──
        Text('Task Performance',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 12),
        ...taskStats.entries.toList().asMap().entries.map((e) {
          final idx = e.key;
          final name = e.value.key;
          final (done, total) = e.value.value;
          final p = total > 0 ? done / total : 0.0;
          final color = taskColors[idx % taskColors.length];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${(p * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color cardBg, textColor, color;
  final String title, value, subtitle;
  final IconData icon;

  const _StatCard({
    required this.cardBg,
    required this.textColor,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
              ],
            ),
          ),
          Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
