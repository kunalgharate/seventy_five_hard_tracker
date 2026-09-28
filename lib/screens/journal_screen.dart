import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';

/// Journal screen — mood tracking + daily reflections.
/// Stores mood as prefix in journalNote: "😊|reflection text"
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String? _selectedMood;
  final _reflectionCtrl = TextEditingController();
  bool _saving = false;

  static const _moods = [
    ('😊', 'Great'),
    ('🙂', 'Good'),
    ('😐', 'Okay'),
    ('😔', 'Low'),
    ('😤', 'Tough'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTodayEntry();
  }

  void _loadTodayEntry() {
    final state = context.read<ChallengeBloc>().state;
    if (state is ChallengeLoaded) {
      final today = DateTime.now();
      final progress = state.currentProgress
          .where((p) =>
              p.date.year == today.year &&
              p.date.month == today.month &&
              p.date.day == today.day)
          .firstOrNull;
      if (progress?.journalNote != null &&
          progress!.journalNote!.isNotEmpty) {
        final parts = progress.journalNote!.split('|');
        if (parts.length >= 2 && parts[0].length <= 2) {
          _selectedMood = parts[0];
          _reflectionCtrl.text = parts.sublist(1).join('|');
        } else {
          _reflectionCtrl.text = progress.journalNote!;
        }
        setState(() {});
      }
    }
  }

  Future<void> _save() async {
    final mood = _selectedMood ?? '';
    final text = _reflectionCtrl.text.trim();
    if (text.isEmpty && mood.isEmpty) return;

    setState(() => _saving = true);

    final journalNote =
        mood.isNotEmpty ? '$mood|$text' : text;

    context.read<ChallengeBloc>().add(
          AddJournalNote(
            date: DateTime.now(),
            note: journalNote,
          ),
        );

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Parse mood + text from a stored journalNote.
  static (String?, String) parseJournalNote(String? note) {
    if (note == null || note.isEmpty) return (null, '');
    final parts = note.split('|');
    if (parts.length >= 2 && parts[0].length <= 2) {
      return (parts[0], parts.sublist(1).join('|'));
    }
    return (null, note);
  }

  @override
  void dispose() {
    _reflectionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[900]! : const Color(0xFFF5F5F5);
    final cardBg = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Journal',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mood selector ──
          Text(
            'How are you feeling today?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moods.map((m) {
              final selected = _selectedMood == m.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedMood = m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.orange.withValues(alpha: 0.15)
                        : cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          selected ? Colors.orange : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(m.$1,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        m.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? Colors.orange
                              : Colors.grey[500],
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Daily reflection ──
          Text(
            'Daily reflection',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What did you learn about yourself today?',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _reflectionCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Write your thoughts...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(color: textColor),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Reflection'),
          ),
          const SizedBox(height: 32),

          // ── Previous entries (from real data) ──
          Text(
            'Previous entries',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          BlocBuilder<ChallengeBloc, ChallengeState>(
            builder: (context, state) {
              if (state is! ChallengeLoaded) {
                return const SizedBox.shrink();
              }
              final entries = state.currentProgress
                  .where((p) =>
                      p.journalNote != null &&
                      p.journalNote!.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'No journal entries yet.\nStart writing today!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 14),
                  ),
                );
              }

              return Column(
                children: entries.take(14).map((p) {
                  final (mood, text) =
                      parseJournalNote(p.journalNote);
                  return _buildEntry(
                      cardBg, textColor, p.date, mood, text);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(
    Color cardBg,
    Color textColor,
    DateTime date,
    String? mood,
    String text,
  ) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final dateStr = isToday
        ? 'Today'
        : DateFormat('EEEE, MMM d').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mood ?? '📝', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(fontSize: 13, color: textColor),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
