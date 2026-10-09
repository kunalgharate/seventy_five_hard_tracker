import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/figma_tokens.dart';

/// Gradient hero card showing challenge progress — matches the Figma
/// "challenge-hero" scene: orange→coral→pink gradient, "N days to go",
/// circular % orbit, day pill, decorative ring flourish, and a
/// current-streak + best-streak row.
class ChallengeHeroCard extends StatelessWidget {
  final int currentDay;
  final int totalDays;
  final int currentStreak;
  final int bestStreak;
  final String? challengeLabel;

  const ChallengeHeroCard({
    super.key,
    required this.currentDay,
    this.totalDays = 75,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.challengeLabel,
  });

  int get _daysToGo => max(0, totalDays - currentDay);
  double get _progress =>
      totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;
  int get _percentage => (_progress * 100).round();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: FigmaTokens.brandGradient,
        borderRadius: BorderRadius.circular(FigmaTokens.rCardLg),
        boxShadow: FigmaTokens.gradientShadow,
      ),
      child: Stack(
        children: [
          // Decorative ring flourish (Figma .challenge-hero:after)
          Positioned(
            right: -85,
            bottom: -105,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 42,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: label + day pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          (challengeLabel ?? '75 Hard Challenge').toUpperCase(),
                          style: FigmaTokens.body(9,
                              weight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(FigmaTokens.rChip),
                      ),
                      child: Text(
                        'DAY $currentDay',
                        style: FigmaTokens.body(9,
                            weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main: kicker + days-to-go + progress orbit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keep your promise.',
                          style: FigmaTokens.body(11,
                              color: Colors.white.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_daysToGo days to go',
                          style: FigmaTokens.heading(25, color: Colors.white),
                        ),
                      ],
                    ),
                    _ProgressOrbit(progress: _progress, percent: _percentage),
                  ],
                ),
                const SizedBox(height: 17),

                // Thin progress track
                ClipRRect(
                  borderRadius: BorderRadius.circular(FigmaTokens.rChip),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 15),

                // Streak stats
                Row(
                  children: [
                    _StreakStat(
                      icon: Icons.local_fire_department,
                      value: '$currentStreak days',
                      label: 'Current streak',
                    ),
                    const SizedBox(width: 30),
                    _StreakStat(
                      icon: Icons.emoji_events,
                      value: '$bestStreak days',
                      label: 'Best streak',
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

/// Circular progress "orbit" matching the Figma conic-gradient ring.
class _ProgressOrbit extends StatelessWidget {
  final double progress;
  final int percent;
  const _ProgressOrbit({required this.progress, required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Text(
            '$percent%',
            style: FigmaTokens.body(10,
                weight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StreakStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StreakStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    FigmaTokens.body(10, weight: FontWeight.w700, color: Colors.white)),
            Text(label,
                style: FigmaTokens.body(8,
                    color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ],
    );
  }
}
