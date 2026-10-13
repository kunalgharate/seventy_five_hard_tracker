import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/voice_input.dart';
import '../core/theme/figma_tokens.dart';
import '../core/theme/figma_widgets.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/journal_entry.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';

/// Journal screen — mood tracking + daily reflections.
///
/// A day holds MANY entries (each save appends). Entries are grouped by date
/// into accordions; tapping a date shows all of that day's entries, each with
/// edit + delete. Mic dictation + "Tron AI" polish available on every field.
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
  bool _composerExpanded = true;

  // Figma mood row: 5 moods, color-coded green → red.
  static const _moods = [
    ('😊', 'Great', Color(0xFF61B77F)),
    ('🙂', 'Good', Color(0xFFA3CF6E)),
    ('😐', 'Okay', Color(0xFFF0C64F)),
    ('😔', 'Low', Color(0xFFF29157)),
    ('😤', 'Hard', Color(0xFFE76669)),
  ];

  Future<void> _save() async {
    final mood = _selectedMood;
    final text = _reflectionCtrl.text.trim();
    final proud = _proudCtrl.text.trim();
    if (text.isEmpty && (mood ?? '').isEmpty && proud.isEmpty) return;

    setState(() => _saving = true);
    final bloc = context.read<ChallengeBloc>();
    bloc.add(
      AddJournalEntry(
        date: DateTime.now(),
        entry: JournalEntry.now(mood: mood, text: text, proud: proud),
      ),
    );

    final saved = await _awaitJournalWrite(bloc);
    if (!mounted) return;
    if (saved) {
      setState(() {
        _saving = false;
        _selectedMood = null;
        _reflectionCtrl.clear();
        _proudCtrl.clear();
        _composerExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry added!'),
          backgroundColor: Color(0xFF49AE71),
        ),
      );
    } else {
      setState(() => _saving = false);
    }
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
          // ── New entry composer (collapses to a compact affordance
          // after each successful save; entries below stay newest-first) ──
          if (!_composerExpanded)
            FigmaCard(
              onTap: () => setState(() => _composerExpanded = true),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
              radius: 20,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Add entry',
                        style: FigmaTokens.heading(15, color: textColor)),
                  ),
                  const Icon(Icons.expand_more,
                      color: FigmaTokens.muted, size: 22),
                ],
              ),
            )
          else
            FigmaCard(
              padding: const EdgeInsets.all(17),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('How are you feeling?',
                            style: FigmaTokens.heading(16, color: textColor)),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _composerExpanded = false),
                        icon: const Icon(Icons.expand_less, size: 22),
                        color: FigmaTokens.muted,
                        tooltip: 'Minimize',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
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
                                  ? (Matrix4.identity()
                                    ..scaleByDouble(1.12, 1.12, 1.12, 1.0))
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
                  _FieldLabel(
                    label: "What's on your mind?",
                    textColor: textColor,
                    controller: _reflectionCtrl,
                  ),
                  const SizedBox(height: 7),
                  _JournalField(
                    controller: _reflectionCtrl,
                    hint:
                        "Write or dictate today's progress, challenges, or anything you want to remember...",
                    minLines: 4,
                    maxLines: 6,
                    isDark: isDark,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 15),
                  _FieldLabel(
                    label: "One thing I'm proud of",
                    textColor: textColor,
                    controller: _proudCtrl,
                  ),
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

          // ── Entries grouped by date (accordions) ──
          const FigmaSectionHead(title: 'Entries by date', note: null),
          BlocBuilder<ChallengeBloc, ChallengeState>(
            builder: (context, state) {
              if (state is! ChallengeLoaded) {
                return const SizedBox.shrink();
              }
              // Group every entry under its calendar day, newest day first.
              final byDay = <DateTime, List<JournalEntry>>{};
              final dayOf = <DateTime, DateTime>{};
              for (final p in state.currentProgress) {
                if (p.journalNote == null || p.journalNote!.isEmpty) continue;
                final entries =
                    JournalEntry.decode(p.journalNote!, fallbackDate: p.date);
                if (entries.isEmpty) continue;
                final day = DateTime(p.date.year, p.date.month, p.date.day);
                dayOf[day] = day;
                byDay.putIfAbsent(day, () => []).addAll(entries);
              }
              final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
              if (days.isEmpty) {
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
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              return Column(
                children: [
                  for (int i = 0; i < days.length; i++)
                    _DayAccordion(
                      day: days[i],
                      entries: (byDay[days[i]]!
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
                      initiallyExpanded: days[i] == today || i == 0,
                      onEdit: (entry) => _openEditor(days[i], entry),
                      onDelete: (entry) => _confirmDelete(days[i], entry),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(DateTime day, JournalEntry entry) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntryEditorSheet(day: day, entry: entry),
    );
  }

  Future<void> _confirmDelete(DateTime day, JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This journal entry will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ChallengeBloc>().add(
            DeleteJournalEntry(date: day, entryId: entry.id),
          );
    }
  }
}

/// Label row with mic dictation + Tron AI polish for a field.
class _FieldLabel extends StatelessWidget {
  final String label;
  final Color textColor;
  final TextEditingController controller;
  const _FieldLabel({
    required this.label,
    required this.textColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: FigmaTokens.body(11,
                  weight: FontWeight.w700, color: textColor)),
        ),
        TronPolishButton(controller: controller),
        MicDictationButton(controller: controller),
      ],
    );
  }
}

/// One date accordion: header shows the date + entry count, tapping expands
/// to all of that day's entries with edit/delete on each.
class _DayAccordion extends StatelessWidget {
  final DateTime day;
  final List<JournalEntry> entries;
  final bool initiallyExpanded;
  final void Function(JournalEntry) onEdit;
  final void Function(JournalEntry) onDelete;

  const _DayAccordion({
    required this.day,
    required this.entries,
    this.initiallyExpanded = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final String title;
    if (day == today) {
      title = 'Today';
    } else if (day == yesterday) {
      title = 'Yesterday';
    } else {
      title = DateFormat('EEEE, MMM d').format(day);
    }
    final moods = entries
        .map((e) => e.mood)
        .where((m) => (m ?? '').isNotEmpty)
        .cast<String>()
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FigmaCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        radius: 16,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            leading: Text(
              moods.isNotEmpty ? moods.last : '📝',
              style: const TextStyle(fontSize: 26),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}'
              '${moods.isNotEmpty ? ' · ${moods.join(' ')}' : ''}',
              style: FigmaTokens.body(11, color: FigmaTokens.muted),
            ),
            children: [
              for (final entry in entries)
                _EntryTile(
                  entry: entry,
                  onEdit: () => onEdit(entry),
                  onDelete: () => onDelete(entry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One entry inside a day accordion, with edit + delete (full CRUD).
class _EntryTile extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.mood != null && entry.mood!.isNotEmpty) ...[
                      Text(entry.mood!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      DateFormat('h:mm a').format(entry.createdAt),
                      style: FigmaTokens.body(11, color: FigmaTokens.muted),
                    ),
                  ],
                ),
                if (entry.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry.text,
                      style: FigmaTokens.body(13, color: scheme.onSurface)),
                ],
                if (entry.proud.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🏆 ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(entry.proud,
                            style: FigmaTokens.body(12,
                                color: scheme.onSurface,
                                weight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit entry',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
            tooltip: 'Delete entry',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to edit one existing entry (mood + text + proud,
/// with mic dictation + Tron AI polish).
class _EntryEditorSheet extends StatefulWidget {
  final DateTime day;
  final JournalEntry entry;
  const _EntryEditorSheet({required this.day, required this.entry});

  @override
  State<_EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends State<_EntryEditorSheet> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _proudCtrl;
  String? _mood;
  bool _saving = false;

  static const _moods = ['😊', '🙂', '😐', '😔', '😤'];

  @override
  void initState() {
    super.initState();
    _mood = widget.entry.mood;
    _textCtrl = TextEditingController(text: widget.entry.text);
    _proudCtrl = TextEditingController(text: widget.entry.proud);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _proudCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_textCtrl.text.trim().isEmpty &&
        (_mood ?? '').isEmpty &&
        _proudCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')),
      );
      return;
    }
    setState(() => _saving = true);
    final bloc = context.read<ChallengeBloc>();
    bloc.add(
      UpdateJournalEntry(
        date: widget.day,
        entry: JournalEntry(
          id: widget.entry.id,
          createdAt: widget.entry.createdAt,
          mood: _mood,
          text: _textCtrl.text.trim(),
          proud: _proudCtrl.text.trim(),
        ),
      ),
    );
    final saved = await _awaitJournalWrite(bloc);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Edit entry · ${DateFormat('MMM d').format(widget.day)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final m in _moods)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _mood = _mood == m ? null : m),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _mood == m ? scheme.primary : scheme.outline,
                            width: _mood == m ? 2 : 1,
                          ),
                        ),
                        child: Center(
                            child:
                                Text(m, style: const TextStyle(fontSize: 20))),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _FieldLabel(
                label: 'Reflection',
                textColor: scheme.onSurface,
                controller: _textCtrl,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'What happened today?',
                ),
              ),
              const SizedBox(height: 12),
              _FieldLabel(
                label: "Proud of",
                textColor: scheme.onSurface,
                controller: _proudCtrl,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _proudCtrl,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'One proud moment…',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update entry'),
                ),
              ),
            ],
          ),
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

Future<bool> _awaitJournalWrite(ChallengeBloc bloc) async {
  try {
    final state = await bloc.stream
        .firstWhere((s) => s is ChallengeLoaded || s is ChallengeError)
        .timeout(const Duration(seconds: 4));
    return state is ChallengeLoaded;
  } catch (_) {
    return false;
  }
}
