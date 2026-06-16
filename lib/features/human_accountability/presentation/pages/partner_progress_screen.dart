import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_extension_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'accountability_chat_screen.dart';

/// Shows a partner's full progress: streak, discipline score,
/// weekly grid, missed tasks, and daily completion details.
class PartnerProgressScreen extends StatefulWidget {
  final AccountabilityPartner partner;

  const PartnerProgressScreen({super.key, required this.partner});

  @override
  State<PartnerProgressScreen> createState() => _PartnerProgressScreenState();
}

class _PartnerProgressScreenState extends State<PartnerProgressScreen> {
  final _svc = AccountabilityExtensionService();
  List<Map<String, dynamic>> _progress = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myUid = AccountabilityService().currentUid;
    final uid = widget.partner.ownerUid == myUid
        ? widget.partner.partnerUid
        : widget.partner.ownerUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final results = await Future.wait([
      _svc.fetchPartnerFullProgress(uid),
      _svc.fetchWeeklySummary(uid),
    ]);
    if (mounted) {
      setState(() {
        _progress = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '${widget.partner.partnerName}\'s Progress',
        actions: [
          if (widget.partner.partnerUid != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Send Message',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AccountabilityChatScreen(partner: widget.partner),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _progress.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No progress data yet.',
              style:
                  GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildWeeklyGrid(),
        const SizedBox(height: 16),
        _buildProgressList(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final pct = (_summary['completionPct'] as double? ?? 0).toStringAsFixed(0);
    final completed = _summary['completedDays'] as int? ?? 0;
    final total = _summary['totalDays'] as int? ?? 0;
    final missed = _summary['missedTasks'] as int? ?? 0;
    final currentDay = _summary['currentDay'] as int? ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoleChip(role: widget.partner.role),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.partner.partnerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.partner.role.label,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (currentDay > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Day $currentDay',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatTile(
                    label: 'Completion', value: '$pct%', color: Colors.green),
                _StatTile(
                    label: 'Days Done',
                    value: '$completed/$total',
                    color: AppColors.primary),
                _StatTile(
                    label: 'Missed Tasks',
                    value: '$missed',
                    color: missed > 0 ? Colors.red : Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (_summary['completionPct'] as double? ?? 0) / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyGrid() {
    final trend = _summary['streakTrend'] as List? ?? [];
    if (trend.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 Days',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(trend.length, (i) {
                final done = trend[i] as bool;
                final daysAgo = trend.length - 1 - i;
                final date = DateTime.now().subtract(Duration(days: daysAgo));
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
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        done ? Icons.check : Icons.close,
                        size: 18,
                        color: done ? Colors.green : Colors.red[300],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('E').format(date),
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily History',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ..._progress.take(14).map((d) {
          final dateKey = d['dateKey'] as String? ?? '';
          final completed = d['completedTasks'] as int? ?? 0;
          final total = d['totalTasks'] as int? ?? 0;
          final done = d['dayCompleted'] as bool? ?? false;
          final day = d['currentDay'] as int? ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_circle : Icons.cancel,
                  color: done ? Colors.green : Colors.red[300],
                  size: 22,
                ),
              ),
              title: Text(
                dateKey,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Day $day · $completed/$total tasks'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: done
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  done ? 'Done' : 'Missed',
                  style: TextStyle(
                      fontSize: 11,
                      color: done ? Colors.green[700] : Colors.red[400],
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final PartnerRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child:
          Center(child: Text(role.emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_extension_service.dart';
import 'accountability_chat_screen.dart';

/// Shows a partner's full progress: streak, discipline score,
/// weekly grid, missed tasks, and daily completion details.
class PartnerProgressScreen extends StatefulWidget {
  final AccountabilityPartner partner;

  const PartnerProgressScreen({super.key, required this.partner});

  @override
  State<PartnerProgressScreen> createState() => _PartnerProgressScreenState();
}

class _PartnerProgressScreenState extends State<PartnerProgressScreen> {
  final _svc = AccountabilityExtensionService();
  List<Map<String, dynamic>> _progress = [];
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
    final results = await Future.wait([
      _svc.fetchPartnerFullProgress(uid),
      _svc.fetchWeeklySummary(uid),
    ]);
    if (mounted) {
      setState(() {
        _progress = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '${widget.partner.partnerName}\'s Progress',
        actions: [
          if (widget.partner.partnerUid != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Send Message',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AccountabilityChatScreen(partner: widget.partner),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _progress.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No progress data yet.',
              style:
                  GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildWeeklyGrid(),
        const SizedBox(height: 16),
        _buildProgressList(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final pct = (_summary['completionPct'] as double? ?? 0).toStringAsFixed(0);
    final completed = _summary['completedDays'] as int? ?? 0;
    final total = _summary['totalDays'] as int? ?? 0;
    final missed = _summary['missedTasks'] as int? ?? 0;
    final currentDay = _summary['currentDay'] as int? ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoleChip(role: widget.partner.role),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.partner.partnerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.partner.role.label,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (currentDay > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Day $currentDay',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatTile(
                    label: 'Completion', value: '$pct%', color: Colors.green),
                _StatTile(
                    label: 'Days Done',
                    value: '$completed/$total',
                    color: AppColors.primary),
                _StatTile(
                    label: 'Missed Tasks',
                    value: '$missed',
                    color: missed > 0 ? Colors.red : Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (_summary['completionPct'] as double? ?? 0) / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyGrid() {
    final trend = _summary['streakTrend'] as List? ?? [];
    if (trend.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 Days',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(trend.length, (i) {
                final done = trend[i] as bool;
                final daysAgo = trend.length - 1 - i;
                final date = DateTime.now().subtract(Duration(days: daysAgo));
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
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        done ? Icons.check : Icons.close,
                        size: 18,
                        color: done ? Colors.green : Colors.red[300],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('E').format(date),
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily History',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ..._progress.take(14).map((d) {
          final dateKey = d['dateKey'] as String? ?? '';
          final completed = d['completedTasks'] as int? ?? 0;
          final total = d['totalTasks'] as int? ?? 0;
          final done = d['dayCompleted'] as bool? ?? false;
          final day = d['currentDay'] as int? ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_circle : Icons.cancel,
                  color: done ? Colors.green : Colors.red[300],
                  size: 22,
                ),
              ),
              title: Text(
                dateKey,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Day $day · $completed/$total tasks'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: done
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  done ? 'Done' : 'Missed',
                  style: TextStyle(
                      fontSize: 11,
                      color: done ? Colors.green[700] : Colors.red[400],
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final PartnerRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child:
          Center(child: Text(role.emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}
