import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gradient hero card showing challenge progress — matches the design:
/// orange→red→pink gradient, "57 days to go", circular % ring,
/// current streak + best streak row.
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF6B35),
            Color(0xFFFF3D7F),
            Color(0xFFE91E63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + day badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    challengeLabel ?? '75 HARD CHALLENGE',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DAY $currentDay',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main content: days to go + circular progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keep your promise.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_daysToGo days to go',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mini progress bar
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 4,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              // Circular percentage ring
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 5,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                      ),
                    ),
                    Center(
                      child: Text(
                        '$_percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bottom row: current streak + best streak
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                '$currentStreak days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Current streak',
                style: TextStyle(
                    color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 24),
              const Icon(Icons.refresh,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                '$bestStreak days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Best streak',
                style: TextStyle(
                    color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
