import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/custom_app_bar.dart';
import '../core/theme/figma_tokens.dart';
import '../core/theme/figma_widgets.dart';
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
  final _proudCtrl = TextEditingController();
  bool _saving = false;

  // Figma mood row: 5 moods, color-coded green → red.
  static const _moods = [
    ('😊', 'Great', Color(0xFF61B77F)),
    ('🙂', 'Good', Color(0xFFA3CF6E)),
    ('😐', 'Okay', Color(0xFFF0C64F)),
    ('😔', 'Low', Color(0xFFF29157)),
    ('😤', 'Hard', Color(0xFFE76669)),
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
      if (progress?.journalNote != null && progress!.journalNote!.isNotEmpty) {
        final (mood, text, proud) = _parseFull(progress.journalNote!);
        _selectedMood = mood;
        _reflectionCtrl.text = text;
        _proudCtrl.text = proud;
        setState(() {});
      }
    }
  }

  Future<void> _save() async {
    final mood = _selectedMood ?? '';
    final text = _reflectionCtrl.text.trim();
    final proud = _proudCtrl.text.trim();
    if (text.isEmpty && mood.isEmpty && proud.isEmpty) return;

    setState(() => _saving = true);

    // Storage format: "mood|reflection" with an optional proud-of segment
    // appended after a unit-separator (\u241F) to stay backward compatible.
    var journalNote = mood.isNotEmpty ? '$mood|$text' : text;
    if (proud.isNotEmpty) journalNote = '$journalNote\u241F$proud';

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
          backgroundColor: Color(0xFF49AE71),
        ),
      );
    }
  }

  /// Parse mood + text from a stored journalNote (public, used by other screens).
  static (String?, String) parseJournalNote(String? note) {
    final (mood, text, _) = _parseFull(note);
    return (mood, text);
  }

  /// Parse mood + reflection + proud-of from a stored note.
  static (String?, String, String) _parseFull(String? note) {
    if (note == null || note.isEmpty) return (null, '', '');
    String proud = '';
    var rest = note;
    final sepIndex = note.indexOf('\u241F');
    if (sepIndex != -1) {
      proud = note.substring(sepIndex + 1);
      rest = note.substring(0, sepIndex);
    }
    final parts = rest.split('|');
    if (parts.length >= 2 && parts[0].length <= 2) {
      return (parts[0], parts.sublist(1).join('|'), proud);
    }
    return (null, rest, proud);
  }

  @override
  void dispose() {
    _reflectionCtrl.dispose();
    _proudCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FigmaTokens.darkBg : FigmaTokens.soft;
    final cardBg = isDark ? FigmaTokens.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : FigmaTokens.ink;

    return Scaffold(
      backgroundColor: bg,
      appBar: const CustomAppBar(title: 'Daily journal', centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          // ── Journal entry card ──
          FigmaCard(
            padding: const EdgeInsets.all(17),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How are you feeling?',
                    style: FigmaTokens.heading(16, color: textColor)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _moods.map((m) {
                    final selected = _selectedMood == m.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMood = m.$1),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            transform: selected
                                ? (Matrix4.identity()..scaleByDouble(1.12, 1.12, 1.12, 1.0))
                                : Matrix4.identity(),
                            transformAlignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: m.$3,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? m.$3 : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cardBg,
                                  spreadRadius: selected ? 4 : 6,
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(m.$2,
                              style: FigmaTokens.body(9,
                                  weight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color:
                                      selected ? m.$3 : FigmaTokens.muted)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text("What's on your mind?",
                    style: FigmaTokens.body(11,
                        weight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 7),
                _JournalField(
                  controller: _reflectionCtrl,
                  hint:
                      "Write about today's progress, challenges, or anything you want to remember...",
                  minLines: 4,
                  maxLines: 6,
                  isDark: isDark,
                  textColor: textColor,
                ),
                const SizedBox(height: 15),
                Text("One thing I'm proud of",
                    style: FigmaTokens.body(11,
                        weight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 7),
                _JournalField(
                  controller: _proudCtrl,
                  hint: 'I showed up even when it was difficult.',
                  minLines: 1,
                  maxLines: 2,
                  isDark: isDark,
                  textColor: textColor,
                ),
                const SizedBox(height: 18),
                FigmaGradientButton(
                  label: 'Save reflection',
                  icon: Icons.menu_book,
                  loading: _saving,
                  onTap: _save,
                ),
              ],
            ),
          ),

          // ── Previous entries ──
          const FigmaSectionHead(title: 'Previous entries', note: null),
          BlocBuilder<ChallengeBloc, ChallengeState>(
            builder: (context, state) {
              if (state is! ChallengeLoaded) {
                return const SizedBox.shrink();
              }
              final entries = state.currentProgress
                  .where(
                      (p) => p.journalNote != null && p.journalNote!.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text(
                      'No journal entries yet.\nStart writing today!',
                      textAlign: TextAlign.center,
                      style: FigmaTokens.body(13, color: FigmaTokens.muted),
                    ),
                  ),
                );
              }

              return Column(
                children: entries.take(14).map((p) {
                  final (mood, text) = parseJournalNote(p.journalNote);
                  return _buildEntry(cardBg, textColor, p.date, mood, text);
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
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final dateStr = isToday ? 'Today' : DateFormat('EEEE, MMM d').format(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FigmaCard(
        padding: const EdgeInsets.all(14),
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mood ?? '📝', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: FigmaTokens.body(12,
                          weight: FontWeight.w700, color: FigmaTokens.muted)),
                  const SizedBox(height: 4),
                  Text(text,
                      style: FigmaTokens.body(13, color: textColor),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma-styled soft input field used in the journal entry card.
class _JournalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool isDark;
  final Color textColor;
  const _JournalField({
    required this.controller,
    required this.hint,
    required this.minLines,
    required this.maxLines,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FigmaTokens.darkBg : const Color(0xFFF9F6F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? FigmaTokens.darkLine : const Color(0xFFF1ECE9)),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        style: FigmaTokens.body(12, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: FigmaTokens.body(12, color: FigmaTokens.muted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
