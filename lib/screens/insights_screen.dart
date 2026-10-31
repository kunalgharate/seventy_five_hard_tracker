import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/custom_app_bar.dart';
import '../core/theme/figma_tokens.dart';
import '../core/theme/figma_widgets.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_state.dart';

/// Insights screen — real data from ChallengeBloc, styled to match the Figma
/// design (dark highlight card, gradient bar chart, 2x2 metrics grid,
/// per-habit performance bars).
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FigmaTokens.darkBg : FigmaTokens.soft;

    return Scaffold(
      backgroundColor: bg,
      appBar: const CustomAppBar(title: 'Your insights', centerTitle: false),
      body: SafeArea(
        child: BlocBuilder<ChallengeBloc, ChallengeState>(
          builder: (context, state) {
            if (state is! ChallengeLoaded || !state.hasActiveSession) {
              return Center(
                child: Text('Start a challenge to see insights.',
                    style: FigmaTokens.body(13, color: FigmaTokens.muted)),
              );
            }
            return _InsightsBody(state: state);
          },
        ),
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

    final progress = state.currentProgress;
    final session = state.activeSession!;
    final totalDays = progress.length;
    final completedDays = progress.where((p) => p.isCompleted).length;
    final pct = totalDays > 0 ? (completedDays / totalDays * 100) : 0.0;
    final streak = _computeStreak(progress);
    final bestStreak = _computeBestStreak(progress);
    final perfectDays = completedDays;

    // Challenge-task performance: completion ratio per non-regular challenge
    // in the active session. Habits (regular tasks) live in RegularTaskBloc
    // and render in their own "Habit performance" section below.
    final challenges =
        session.challenges.where((c) => c.taskType != 'regular').toList();
    final challengeStats = <String, double>{};
    for (final c in challenges) {
      int done = 0, total = 0;
      for (final p in progress) {
        if (p.challengeCompletions.containsKey(c.id)) {
          total++;
          if (p.challengeCompletions[c.id] == true) done++;
        }
      }
      challengeStats[c.title] = total > 0 ? done / total : 0.0;
    }

    // Weekly completion % per day (last 7 days) — ratio of tasks done that day
    final now = DateTime.now();
    final weekBars = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final match = progress.where((p) =>
          p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day);
      double ratio = 0;
      if (match.isNotEmpty) {
        final p = match.first;
        final total = session.challenges.length;
        if (total > 0) {
          final done = p.challengeCompletions.values.where((v) => v).length;
          ratio = done / total;
        }
      }
      return (date, ratio);
    });

    // "This week" completion rate = avg of weekly bar ratios
    final weekPct = weekBars.isEmpty
        ? 0
        : (weekBars.map((e) => e.$2).reduce((a, b) => a + b) /
                weekBars.length *
                100)
            .round();

    final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final perfBarColors = [
      const Color(0xFF328CE6),
      const Color(0xFF8862DC),
      FigmaTokens.coral,
      const Color(0xFF328CE6),
      const Color(0xFF8862DC),
      FigmaTokens.coral,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        // ── Dark highlight card: this week % + trend + bar chart ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: FigmaTokens.darkCardGradient,
            borderRadius: BorderRadius.circular(FigmaTokens.rCardLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: FigmaTokens.coral),
                            const SizedBox(width: 6),
                            Text('THIS WEEK',
                                style: FigmaTokens.body(9,
                                    weight: FontWeight.w800,
                                    color: FigmaTokens.coral)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text('$weekPct%',
                            style:
                                FigmaTokens.heading(32, color: Colors.white)),
                        Text('completion rate',
                            style: FigmaTokens.body(10,
                                color: const Color(0xFFCABDC2))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64CB88).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(FigmaTokens.rChip),
                    ),
                    child: Text('↑ ${pct.toStringAsFixed(0)}%',
                        style: FigmaTokens.body(10,
                            weight: FontWeight.w800,
                            color: const Color(0xFF82D09D))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(weekBars.length, (i) {
                    final ratio = weekBars[i].$2;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 23),
                              height: (ratio * 72).clamp(8, 72),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    FigmaTokens.orange,
                                    FigmaTokens.pink
                                  ],
                                ),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(5),
                                  bottom: Radius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(dayLetters[i],
                                style: FigmaTokens.body(8,
                                    color: const Color(0xFFAB9DA3))),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),

        // ── 2x2 metrics grid ──
        Row(
          children: [
            Expanded(
                child: _Metric(
                    icon: Icons.local_fire_department,
                    tint: const Color(0xFFE86D24),
                    bg: const Color(0xFFFFF0E5),
                    value: '$streak',
                    label: 'Current streak')),
            const SizedBox(width: 9),
            Expanded(
                child: _Metric(
                    icon: Icons.emoji_events,
                    tint: const Color(0xFFDF4E78),
                    bg: const Color(0xFFFFEAF0),
                    value: '$completedDays',
                    label: 'Total check-ins')),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
                child: _Metric(
                    icon: Icons.calendar_today,
                    tint: const Color(0xFFC49122),
                    bg: const Color(0xFFFFF5D9),
                    value: '$perfectDays',
                    label: 'Perfect days')),
            const SizedBox(width: 9),
            Expanded(
                child: _Metric(
                    icon: Icons.my_location,
                    tint: const Color(0xFF43966B),
                    bg: const Color(0xFFE7F5EC),
                    value: '$bestStreak',
                    label: 'Best streak')),
          ],
        ),

        // ── Habit performance (habits data source: RegularTaskBloc) ──
        const FigmaSectionHead(title: 'Habit performance', note: null),
        BlocBuilder<RegularTaskBloc, RegularTaskState>(
          builder: (context, rState) {
            if (rState is! RegularTaskLoaded || rState.tasks.isEmpty) {
              return FigmaCard(
                child: Text(
                  rState is RegularTaskLoaded
                      ? 'No habits yet. Add one from the Habits tab.'
                      : 'Loading habits…',
                  style: FigmaTokens.body(12, color: FigmaTokens.muted),
                ),
              );
            }
            final completions = rState.recentCompletions;
            final entries = rState.tasks.asMap().entries.map((e) {
              final task = e.value;
              int done = 0;
              for (final c in completions) {
                if (c.taskCompletions[task.id] == true) done++;
              }
              final ratio =
                  completions.isNotEmpty ? done / completions.length : 0.0;
              return (task.title, ratio);
            }).toList();
            return FigmaCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final name = e.value.$1;
                  final ratio = e.value.$2;
                  final isLast = idx == entries.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                  color: isDark
                                      ? FigmaTokens.darkLine
                                      : FigmaTokens.line)),
                    ),
                    child: FigmaPerformanceBar(
                      label: name,
                      percent: (ratio * 100).round(),
                      color: perfBarColors[idx % perfBarColors.length],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),

        // ── Challenges (challenge-sessions data source: ChallengeBloc) ──
        const FigmaSectionHead(title: 'Challenges', note: null),
        FigmaCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: challengeStats.isEmpty
              ? Text(
                  'No challenge tasks in the active session.',
                  style: FigmaTokens.body(12, color: FigmaTokens.muted),
                )
              : Column(
                  children:
                      challengeStats.entries.toList().asMap().entries.map((e) {
                    final idx = e.key;
                    final name = e.value.key;
                    final ratio = e.value.value;
                    final isLast = idx == challengeStats.length - 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(
                                    color: isDark
                                        ? FigmaTokens.darkLine
                                        : FigmaTokens.line)),
                      ),
                      child: FigmaPerformanceBar(
                        label: name,
                        percent: (ratio * 100).round(),
                        color: perfBarColors[idx % perfBarColors.length],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 4),
        _ChallengeSessionsList(state: state),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ChallengeSessionsList extends StatelessWidget {
  final ChallengeLoaded state;
  const _ChallengeSessionsList({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessions = [...state.allSessions]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    if (sessions.length <= 1) return const SizedBox.shrink();
    final past =
        sessions.where((s) => s.id != state.activeSession?.id).take(3).toList();
    if (past.isEmpty) return const SizedBox.shrink();
    final titleColor = isDark ? Colors.white : FigmaTokens.ink;
    return FigmaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: past.asMap().entries.map((e) {
          final idx = e.key;
          final s = e.value;
          final isLast = idx == past.length - 1;
          final status =
              s.isCompleted ? 'Completed' : (s.isActive ? 'Active' : 'Ended');
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: isDark
                              ? FigmaTokens.darkLine
                              : FigmaTokens.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Day ${s.currentDay}/${s.totalDaysTarget} · ${s.challenges.length} tasks',
                    style: FigmaTokens.body(12,
                        weight: FontWeight.w600, color: titleColor),
                  ),
                ),
                Text(status,
                    style: FigmaTokens.body(11, color: FigmaTokens.muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color bg;
  final String value;
  final String label;
  const _Metric({
    required this.icon,
    required this.tint,
    required this.bg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : FigmaTokens.ink;
    return FigmaCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: FigmaTokens.heading(16, color: textColor)),
                const SizedBox(height: 2),
                Text(label,
                    style: FigmaTokens.body(8, color: FigmaTokens.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
