import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/journal_entry.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'journal_fields.dart';
import 'journal_write_awaiter.dart';

/// Bottom sheet to edit one existing entry (mood + text + proud,
/// with mic dictation + Tron AI polish).
class JournalEntryEditorSheet extends StatefulWidget {
  final DateTime day;
  final JournalEntry entry;
  const JournalEntryEditorSheet(
      {super.key, required this.day, required this.entry});

  @override
  State<JournalEntryEditorSheet> createState() =>
      JournalEntryEditorSheetState();
}

class JournalEntryEditorSheetState extends State<JournalEntryEditorSheet> {
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
    final saved = await awaitJournalWrite(bloc);
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
              JournalFieldLabel(
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
              JournalFieldLabel(
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
