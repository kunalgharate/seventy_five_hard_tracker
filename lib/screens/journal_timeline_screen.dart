import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/journal_entry.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/main.dart';

/// One journal entry card on the timeline.
class _TimelineItem {
  final DateTime date;
  final JournalEntry entry;
  final bool completed;
  const _TimelineItem({
    required this.date,
    required this.entry,
    required this.completed,
  });
}

class JournalTimelineScreen extends StatelessWidget {
  const JournalTimelineScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1618) : const Color(0xFFFAF7F5),
      appBar: const CustomAppBar(
        title: 'Journal History',
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<ChallengeBloc, ChallengeState>(
          builder: (context, state) {
            if (state is ChallengeLoaded) {
              // Load journal entries from ALL sessions, not just active
              final bloc = context.read<ChallengeBloc>();
              final allProgress = <DailyProgress>[];
              for (final session in state.allSessions) {
                final sessionProgress =
                    bloc.repository.getProgressForSession(session.startDate);
                allProgress.addAll(sessionProgress);
              }

              // Expand every day's entries into individual cards (a day can
              // hold many entries), newest first.
              final items = <_TimelineItem>[];
              for (final p in allProgress) {
                if (p.journalNote == null || p.journalNote!.trim().isEmpty) {
                  continue;
                }
                for (final e in JournalEntry.decode(p.journalNote!,
                    fallbackDate: p.date)) {
                  items.add(_TimelineItem(
                      date: p.date, entry: e, completed: p.isCompleted));
                }
              }
              items.sort((a, b) {
                final c = b.date.compareTo(a.date);
                return c != 0
                    ? c
                    : b.entry.createdAt.compareTo(a.entry.createdAt);
              });
              // Dedupe: overlapping sessions can return the same
              // DailyProgress (same date key) twice, decoding the same
              // journalNote twice. Items are newest-first, so keep the
              // first occurrence of each entry id + dateKey.
              final seen = <String>{};
              final deduped = <_TimelineItem>[];
              for (final item in items) {
                final key =
                    '${item.date.year}-${item.date.month}-${item.date.day}|${item.entry.id}';
                if (seen.add(key)) deduped.add(item);
              }
              items
                ..clear()
                ..addAll(deduped);

              if (items.isEmpty) {
                return _buildEmptyState(context);
              }

              return _buildTimeline(
                  context, state.activeSession, state.allSessions, items);
            }
            return _buildEmptyState(context);
          },
        ),
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
          ).animate().scale(
              delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
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

  Widget _buildTimeline(BuildContext context, ChallengeSession? activeSession,
      List<ChallengeSession> allSessions, List<_TimelineItem> items) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          // Normalize to date-only to avoid time-of-day drift in day calculation
          final progressDate =
              DateTime(item.date.year, item.date.month, item.date.day);

          // Find the session this entry belongs to
          int dayNumber = index + 1;
          for (final session in allSessions) {
            final startDate = DateTime(session.startDate.year,
                session.startDate.month, session.startDate.day);
            final diff = progressDate.difference(startDate).inDays;
            if (diff >= 0 && diff < 75) {
              dayNumber = diff + 1;
              break;
            }
          }

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 600),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _TimelineCard(
                  item: item,
                  dayNumber: dayNumber,
                  isFirst: index == 0,
                  isLast: index == items.length - 1,
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
  final _TimelineItem item;
  final int dayNumber;
  final bool isFirst;
  final bool isLast;

  const _TimelineCard({
    required this.item,
    required this.dayNumber,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = item.entry;
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
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: scheme.outlineVariant),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
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
                            [
                              DateFormat('MMM d, yyyy').format(item.date),
                              if (!entry.id.startsWith('legacy-'))
                                DateFormat('h:mm a').format(entry.createdAt),
                            ].join(' · '),
                            style: GoogleFonts.inter(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (entry.mood != null && entry.mood!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            entry.mood!,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      if (entry.text.isNotEmpty)
                        Text(
                          entry.text,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.6,
                            color: scheme.onSurface,
                          ),
                        ),
                      if (entry.proud.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '🏆 ${entry.proud}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],

                      // Extra flair if day was fully completed
                      if (item.completed) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium,
                                color: Colors.amber, size: 20),
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
