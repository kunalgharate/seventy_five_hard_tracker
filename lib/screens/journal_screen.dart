import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Journal screen — mood tracking + daily reflections.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String? _selectedMood;
  final _reflectionCtrl = TextEditingController();

  final _moods = [
    ('😊', 'Great'),
    ('🙂', 'Good'),
    ('😐', 'Okay'),
    ('😔', 'Low'),
    ('😤', 'Tough'),
  ];

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
                      color: selected ? Colors.orange : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(m.$1, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        m.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.orange : Colors.grey[500],
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
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
            onPressed: () {
              // TODO: Save journal entry via ChallengeBloc
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Journal saved!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Save Reflection'),
          ),
          const SizedBox(height: 32),

          // ── Previous entries ──
          Text(
            'Previous entries',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildPlaceholderEntry(cardBg, textColor, 'Yesterday', '😊',
              'Had a great workout session. Read 20 pages instead of 10.'),
          _buildPlaceholderEntry(cardBg, textColor, '2 days ago', '😐',
              'Missed my water goal but completed everything else.'),
          _buildPlaceholderEntry(cardBg, textColor, '3 days ago', '🙂',
              'Steady day. All tasks done before 8 PM.'),
        ],
      ),
    );
  }

  Widget _buildPlaceholderEntry(
    Color cardBg,
    Color textColor,
    String date,
    String mood,
    String text,
  ) {
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
          Text(mood, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
