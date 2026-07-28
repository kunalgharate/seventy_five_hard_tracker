import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/main.dart';

class JournalTimelineScreen extends StatelessWidget {
  const JournalTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(
        title: 'Journal History',
      ),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          if (state is ChallengeLoaded) {
            // Source journal entries from all sessions' progress
            final allProgress = state.currentProgress;
            final entries = allProgress
                .where((p) => p.journalNote != null && p.journalNote!.trim().isNotEmpty)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date)); // Newest first

            if (entries.isEmpty) {
              return _buildEmptyState(context);
            }

            // Use the active session for day-number calculation if available,
            // otherwise pass null and compute from the entry's own date.
            return _buildTimeline(context, state.activeSession, entries);
          }
          return _buildEmptyState(context);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 100,
            color: Colors.grey[300],
          ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            'The Pages Are Blank',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Write your first journal entry on\nthe Home Screen to start your timeline.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, ChallengeSession? session, List<DailyProgress> entries) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final progress = entries[index];
          // Normalize to date-only to avoid time-of-day drift in day calculation
          final progressDate = DateTime(progress.date.year, progress.date.month, progress.date.day);
          int dayNumber;
          if (session != null) {
            final startDate = DateTime(session.startDate.year, session.startDate.month, session.startDate.day);
            dayNumber = progressDate.difference(startDate).inDays + 1;
          } else {
            dayNumber = index + 1;
          }
          
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 600),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _TimelineCard(
                  progress: progress,
                  dayNumber: dayNumber,
                  isFirst: index == 0,
                  isLast: index == entries.length - 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final DailyProgress progress;
  final int dayNumber;
  final bool isFirst;
  final bool isLast;

  const _TimelineCard({
    required this.progress,
    required this.dayNumber,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Line & Node
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vertical Line
                Positioned(
                  top: isFirst ? 30 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 30 : null,
                  child: Container(
                    width: 3,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                // Node
                Positioned(
                  top: 24,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.primary, width: 4),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Day $dayNumber',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(progress.date),
                            style: GoogleFonts.inter(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        progress.journalNote!,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      
                      // Extra flair if day was fully completed
                      if (progress.isCompleted) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Flawless Day Completed',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[700],
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
