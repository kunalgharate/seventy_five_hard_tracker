import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/journal_entry.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import '../../core/theme/figma_tokens.dart';
import '../../core/theme/figma_widgets.dart';
import 'journal_entry_editor.dart';

class JournalEntriesByDay {
  const JournalEntriesByDay({required this.entries, required this.days});

  final Map<DateTime, List<JournalEntry>> entries;
  final List<DateTime> days;
}

/// Maps every DailyProgress' journalNote into day-grouped decoded entries —
/// session-scoped and session-less records merged, newest day and newest
/// entry first. Pure: unit-testable outside the widget tree.
JournalEntriesByDay groupJournalEntries(List<DailyProgress> progress) {
  final entriesByDay = <DateTime, List<JournalEntry>>{};
  for (final dayProgress in progress) {
    final note = dayProgress.journalNote;
    if (note == null || note.isEmpty) continue;
    final entries = JournalEntry.decode(note, fallbackDate: dayProgress.date);
    if (entries.isEmpty) continue;
    final day = DateTime(
      dayProgress.date.year,
      dayProgress.date.month,
      dayProgress.date.day,
    );
    // Session-scoped and session-less records can both hold a day's
    // entries — dedupe by id so merged content never shows twice.
    final dayEntries = entriesByDay.putIfAbsent(day, () => []);
    final seenIds = dayEntries.map((e) => e.id).toSet();
    dayEntries.addAll(entries.where((e) => !seenIds.contains(e.id)));
  }
  for (final entries in entriesByDay.values) {
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  final days = entriesByDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return JournalEntriesByDay(entries: entriesByDay, days: days);
}

/// Entries grouped by day as an expandable list fed straight from
/// ChallengeBloc — sessions loop + session-less journal records.
class JournalEntriesList extends StatefulWidget {
  const JournalEntriesList({super.key});

  @override
  State<JournalEntriesList> createState() => _JournalEntriesListState();
}

class _JournalEntriesListState extends State<JournalEntriesList> {
  List<(DateTime, String)>? _cachedSignature;
  JournalEntriesByDay? _cachedEntries;

  JournalEntriesByDay _entriesFor(List<DailyProgress> progress) {
    final signature = <(DateTime, String)>[
      for (final day in progress)
        if (day.journalNote != null && day.journalNote!.isNotEmpty)
          (day.date, day.journalNote!),
    ];
    final cached = _cachedEntries;
    if (cached != null &&
        _cachedSignature != null &&
        listEquals(signature, _cachedSignature)) {
      return cached;
    }
    final result = groupJournalEntries(progress);
    _cachedSignature = signature;
    _cachedEntries = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChallengeBloc, ChallengeState>(
      builder: (context, state) {
        if (state is! ChallengeLoaded) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        // Load journal entries from ALL sessions (not just active) so
        // entries from previous challenges/restarts remain visible,
        // plus session-less records written with no active challenge.
        final bloc = context.read<ChallengeBloc>();
        final allProgress = <DailyProgress>[
          for (final session in state.allSessions)
            ...bloc.repository.getProgressForSession(
              session.startDate,
              sessionId: session.id,
              totalDaysTarget: session.totalDaysTarget,
            ),
          ...bloc.repository.getSessionlessProgress(),
        ];
        final journalEntries = _entriesFor(allProgress);
        final days = journalEntries.days;
        if (days.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: Text(
                    'No journal entries yet.\nStart writing today!',
                    textAlign: TextAlign.center,
                    style: FigmaTokens.body(13, color: FigmaTokens.muted),
                  ),
                ),
              ),
            ),
          );
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dayIndexByKey = <Key, int>{
          for (var i = 0; i < days.length; i++)
            ValueKey<int>(days[i].millisecondsSinceEpoch): i,
        };
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final day = days[index];
                return _DayAccordion(
                  key: ValueKey<int>(day.millisecondsSinceEpoch),
                  day: day,
                  entries: journalEntries.entries[day]!,
                  initiallyExpanded: day == today || index == 0,
                  onEdit: (entry) => _openEditor(day, entry),
                  onDelete: (entry) => _confirmDelete(day, entry),
                );
              },
              childCount: days.length,
              findChildIndexCallback: (key) => dayIndexByKey[key],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor(DateTime day, JournalEntry entry) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntryEditorSheet(day: day, entry: entry),
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

/// One date accordion: header shows the date + entry count, tapping expands
/// to all of that day's entries with edit/delete on each.
class _DayAccordion extends StatelessWidget {
  final DateTime day;
  final List<JournalEntry> entries;
  final bool initiallyExpanded;
  final void Function(JournalEntry) onEdit;
  final void Function(JournalEntry) onDelete;

  const _DayAccordion({
    super.key,
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
            key: PageStorageKey<int>(day.millisecondsSinceEpoch),
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            leading: Text(
              moods.isNotEmpty ? moods.first : '📝',
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
