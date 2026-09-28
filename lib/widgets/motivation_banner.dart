import 'package:flutter/material.dart';

/// Warm-toned inline motivational quote banner for the Today screen.
class MotivationBanner extends StatelessWidget {
  final String quote;

  const MotivationBanner({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quote,
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange[800],
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
