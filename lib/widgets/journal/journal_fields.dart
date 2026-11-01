import 'package:flutter/material.dart';
import '../../core/theme/figma_tokens.dart';
import '../voice_input.dart';

/// Label row with mic dictation + Tron AI polish for a field.
class JournalFieldLabel extends StatelessWidget {
  final String label;
  final Color textColor;
  final TextEditingController controller;
  const JournalFieldLabel({
    super.key,
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

/// Figma-styled soft input field used in the journal entry card.
class JournalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool isDark;
  final Color textColor;
  const JournalField({
    super.key,
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
