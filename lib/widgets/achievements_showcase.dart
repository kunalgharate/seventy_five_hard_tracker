import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';

class AchievementsShowcase extends StatelessWidget {
  final ChallengeLoaded state;

  const AchievementsShowcase({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate stats across all sessions
    int maxDays = 0;
    bool hasCompleted = false;

    for (var session in state.allSessions) {
      if (session.isCompleted) {
        hasCompleted = true;
        // A completed session means all 75 days were done
        if (75 > maxDays) maxDays = 75;
      }
    }

    // Use actual completed-day count from current progress
    final currentDays = state.currentProgress.where((p) => p.isCompleted).length;
    if (currentDays > maxDays) maxDays = currentDays;

    final achievements = [
      _Achievement(
        id: 'first_blood',
        title: 'First Step',
        description: 'Completed your first day',
        icon: Icons.directions_run,
        color: Colors.blue,
        isUnlocked: maxDays >= 1,
      ),
      _Achievement(
        id: 'bronze',
        title: 'Bronze Mettle',
        description: 'Completed 14 days',
        icon: Icons.shield,
        color: const Color(0xFFCD7F32), // Bronze
        isUnlocked: maxDays >= 14,
      ),
      _Achievement(
        id: 'silver',
        title: 'Silver Mettle',
        description: 'Completed 30 days',
        icon: Icons.shield,
        color: const Color(0xFFC0C0C0), // Silver
        isUnlocked: maxDays >= 30,
      ),
      _Achievement(
        id: 'gold',
        title: 'Gold Mettle',
        description: 'Completed 60 days',
        icon: Icons.shield,
        color: const Color(0xFFFFD700), // Gold
        isUnlocked: maxDays >= 60,
      ),
      _Achievement(
        id: 'diamond',
        title: 'Diamond Mettle',
        description: 'Finished 75 Hard',
        icon: Icons.diamond,
        color: const Color(0xFFB9F2FF), // Diamond
        isUnlocked: hasCompleted,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final a = achievements[index];
              return _buildBadge(a);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(_Achievement a) {
    return Tooltip(
      message: '${a.title}\n${a.description}',
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: a.isUnlocked ? a.color.withValues(alpha: 0.15) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: a.isUnlocked ? a.color.withValues(alpha: 0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              a.icon,
              size: 32,
              color: a.isUnlocked ? a.color : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              a.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: a.isUnlocked ? Colors.grey[800] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const _Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}
