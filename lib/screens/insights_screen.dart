import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Insights screen — charts, streaks, task performance, leaderboard.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _period = 'Week';

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
          'Insights',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Period toggle ──
          Row(
            children: ['Week', 'Month', 'All Time'].map((p) {
              final selected = _period == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _period = p),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.orange : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? Colors.orange : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Completion rate card ──
          _buildStatCard(
            cardBg,
            textColor,
            'Completion Rate',
            '87%',
            Icons.trending_up,
            Colors.green,
            '+5% from last week',
          ),
          const SizedBox(height: 12),

          // ── Streak card ──
          _buildStatCard(
            cardBg,
            textColor,
            'Current Streak',
            '18 days',
            Icons.local_fire_department,
            Colors.orange,
            'Best: 24 days',
          ),
          const SizedBox(height: 12),

          // ── Tasks completed card ──
          _buildStatCard(
            cardBg,
            textColor,
            'Tasks Completed',
            '54',
            Icons.check_circle_outline,
            Colors.blue,
            'This $_period',
          ),
          const SizedBox(height: 24),

          // ── Task performance breakdown ──
          Text(
            'Task Performance',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildTaskPerformance(
              cardBg, textColor, 'Drink 3L water', 0.95, Colors.blue),
          _buildTaskPerformance(
              cardBg, textColor, 'Read 10 pages', 0.78, Colors.purple),
          _buildTaskPerformance(
              cardBg, textColor, '45 min workout', 0.85, Colors.deepOrange),
          _buildTaskPerformance(
              cardBg, textColor, 'Daily reflection', 0.62, Colors.pink),
          const SizedBox(height: 24),

          // ── Weekly trend ──
          Text(
            'Weekly Trend',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar('Mon', 0.8, Colors.orange),
                _buildBar('Tue', 1.0, Colors.green),
                _buildBar('Wed', 0.6, Colors.orange),
                _buildBar('Thu', 1.0, Colors.green),
                _buildBar('Fri', 0.9, Colors.orange),
                _buildBar('Sat', 0.7, Colors.orange),
                _buildBar('Sun', 0.0, Colors.grey[300]!),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Squad leaderboard ──
          Text(
            'Squad Leaderboard',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildLeaderRow(cardBg, textColor, 1, 'You', '18 days', true),
          _buildLeaderRow(cardBg, textColor, 2, 'Priya', '15 days', false),
          _buildLeaderRow(cardBg, textColor, 3, 'Jordan', '12 days', false),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    Color cardBg,
    Color textColor,
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPerformance(
    Color cardBg,
    Color textColor,
    String name,
    double pct,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
              Text('${(pct * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double pct, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 100 * pct,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildLeaderRow(
    Color cardBg,
    Color textColor,
    int rank,
    String name,
    String streak,
    bool isYou,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isYou ? Colors.orange.withValues(alpha: 0.08) : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isYou
            ? Border.all(color: Colors.orange.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1
                  ? Colors.amber
                  : rank == 2
                      ? Colors.grey[400]
                      : Colors.brown[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isYou ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                streak,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
