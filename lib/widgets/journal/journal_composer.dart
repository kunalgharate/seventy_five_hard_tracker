import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/journal_entry.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import '../../core/theme/figma_tokens.dart';
import '../../core/theme/figma_widgets.dart';
import 'journal_fields.dart';
import 'journal_write_awaiter.dart';

/// New-entry composer — mood picker + reflection/proud fields.
/// Collapses to a compact affordance after each successful save.
class JournalComposer extends StatefulWidget {
  const JournalComposer({super.key});

  @override
  State<JournalComposer> createState() => _JournalComposerState();
}

class _JournalComposerState extends State<JournalComposer> {
  final _reflectionCtrl = TextEditingController();
  final _proudCtrl = TextEditingController();
  bool _composerExpanded = true;
  bool _saving = false;
  String? _selectedMood;

  // Figma mood row: 5 moods, color-coded green → red.
  static const _moods = [
    ('😊', 'Great', Color(0xFF61B77F)),
    ('🙂', 'Good', Color(0xFFA3CF6E)),
    ('😐', 'Okay', Color(0xFFF0C64F)),
    ('😔', 'Low', Color(0xFFF29157)),
    ('😤', 'Hard', Color(0xFFE76669)),
  ];

  @override
  void dispose() {
    _reflectionCtrl.dispose();
    _proudCtrl.dispose();
    super.dispose();
  }

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

    final saved = await awaitJournalWrite(bloc);
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? FigmaTokens.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : FigmaTokens.ink;
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
              const Icon(Icons.expand_more, color: FigmaTokens.muted, size: 22),
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
                    onPressed: () => setState(() => _composerExpanded = false),
                    icon: const Icon(Icons.expand_less, size: 22),
                    color: FigmaTokens.muted,
                    tooltip: 'Minimize',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
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
                    onTap: () => setState(() =>
                        _selectedMood = _selectedMood == m.$1 ? null : m.$1),
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
                                color: selected ? m.$3 : FigmaTokens.muted)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              JournalFieldLabel(
                label: "What's on your mind?",
                textColor: textColor,
                controller: _reflectionCtrl,
              ),
              const SizedBox(height: 7),
              JournalField(
                controller: _reflectionCtrl,
                hint:
                    "Write or dictate today's progress, challenges, or anything you want to remember...",
                minLines: 4,
                maxLines: 6,
                isDark: isDark,
                textColor: textColor,
              ),
              const SizedBox(height: 15),
              JournalFieldLabel(
                label: "One thing I'm proud of",
                textColor: textColor,
                controller: _proudCtrl,
              ),
              const SizedBox(height: 7),
              JournalField(
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
    ]);
  }
}
