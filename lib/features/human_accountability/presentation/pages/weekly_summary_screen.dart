import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_extension_service.dart';

/// Weekly accountability summary screen.
/// Shows completion %, missed tasks, streak trend, and partner dashboard.
class WeeklySummaryScreen extends StatefulWidget {
  final AccountabilityPartner partner;

  const WeeklySummaryScreen({super.key, required this.partner});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  final _svc = AccountabilityExtensionService();
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.partner.partnerUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final result = await _svc.fetchWeeklySummary(uid);
    if (mounted) {
      setState(() {
        _summary = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Weekly Summary',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No weekly data available yet.',
              style:
                  GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final pct = _summary['completionPct'] as double? ?? 0;
    final completedDays = _summary['completedDays'] as int? ?? 0;
    final totalDays = _summary['totalDays'] as int? ?? 0;
    final missedTasks = _summary['missedTasks'] as int? ?? 0;
    final completedTasks = _summary['completedTasks'] as int? ?? 0;
    final totalTasks = _summary['totalTasks'] as int? ?? 0;
    final trend = _summary['streakTrend'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.9),
                  AppColors.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Text('Weekly Completion',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.white70, letterSpacing: 1)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _WhiteStat(
                        label: 'Days Done', value: '$completedDays/$totalDays'),
                    _WhiteStat(
                        label: 'Tasks Done',
                        value: '$completedTasks/$totalTasks'),
                    _WhiteStat(
                        label: 'Missed',
                        value: '$missedTasks',
                        warning: missedTasks > 0),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Streak trend
        if (trend.isNotEmpty) ...[
          Text('Daily Streak Trend',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(trend.length, (i) {
                  final done = trend[i] as bool;
                  return Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: done
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: done ? Colors.green : Colors.red[200]!,
                          ),
                        ),
                        child: Icon(
                          done ? Icons.check : Icons.close,
                          size: 18,
                          color: done ? Colors.green : Colors.red[300],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('D${i + 1}',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Missed tasks analysis
        if (missedTasks > 0)
          Card(
            elevation: 2,
            color: Colors.red[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$missedTasks tasks missed this week',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        const SizedBox(height: 2),
                        Text(
                          'Consider sending an encouragement message.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Partner info
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(widget.partner.role.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            title: Text(widget.partner.partnerName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            subtitle: Text(widget.partner.role.label,
                style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      ],
    );
  }
}

class _WhiteStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _WhiteStat({
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: warning ? Colors.yellow[200] : Colors.white,
            )),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
