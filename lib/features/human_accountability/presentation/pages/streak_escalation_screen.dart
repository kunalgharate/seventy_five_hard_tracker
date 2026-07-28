import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/streak_action.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_extension_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';

/// Allows a partner to flag repeated failures, request streak reviews,
/// and view the full streak action audit history.
class StreakEscalationScreen extends StatefulWidget {
  final AccountabilityPartner partner;

  /// Current streak of the subject user — passed from the caller.
  final int currentStreak;

  const StreakEscalationScreen({
    super.key,
    required this.partner,
    required this.currentStreak,
  });

  @override
  State<StreakEscalationScreen> createState() => _StreakEscalationScreenState();
}

class _StreakEscalationScreenState extends State<StreakEscalationScreen> {
  final _svc = AccountabilityExtensionService();
  final _reasonCtrl = TextEditingController();
  List<StreakAction> _actions = [];
  bool _loading = true;
  bool _submitting = false;

  String get _myUid => AccountabilityService().currentUid ?? '';
  bool get _isPartner => widget.partner.ownerUid != _myUid;

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActions() async {
    final uid = widget.partner.ownerUid == _myUid
        ? widget.partner.partnerUid
        : widget.partner.ownerUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final actions = await _svc.fetchStreakActions(uid);
    if (mounted) {
      setState(() {
        _actions = actions;
        _loading = false;
      });
    }
  }

  Future<void> _flagStreak() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason')),
      );
      return;
    }
    final subjectUid = widget.partner.ownerUid == _myUid
        ? widget.partner.partnerUid!
        : widget.partner.ownerUid;

    setState(() => _submitting = true);
    final result = await _svc.flagStreak(
      subjectUid: subjectUid,
      reason: reason,
      currentStreak: widget.currentStreak,
    );
    setState(() => _submitting = false);

    if (!mounted) return;
    if (result != null) {
      _reasonCtrl.clear();
      _loadActions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Streak flagged. User has been notified.'),
            backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _requestReview() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason')),
      );
      return;
    }
    final subjectUid = widget.partner.ownerUid == _myUid
        ? widget.partner.partnerUid!
        : widget.partner.ownerUid;

    setState(() => _submitting = true);
    final result = await _svc.requestStreakReview(
      subjectUid: subjectUid,
      reason: reason,
      currentStreak: widget.currentStreak,
    );
    setState(() => _submitting = false);

    if (!mounted) return;
    if (result != null) {
      _reasonCtrl.clear();
      _loadActions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Review request sent.'),
            backgroundColor: Colors.blue),
      );
    }
  }

  Future<void> _acknowledgeAction(StreakAction action, bool confirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(confirm ? 'Confirm Streak Reset' : 'Deny Streak Reset'),
        content: Text(confirm
            ? 'Are you sure you want to confirm this streak reset? This cannot be undone.'
            : 'Deny the streak reset request from ${action.initiatorName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirm ? Colors.red : Colors.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm ? 'Confirm Reset' : 'Deny',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _svc.acknowledgeStreakAction(
      actionId: action.id,
      confirmed: confirm,
      subjectUid: action.subjectUid,
    );
    _loadActions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Streak Escalation'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Action form (only for partners, not the subject)
                if (_isPartner) ...[
                  _buildActionForm(),
                  const SizedBox(height: 20),
                ],

                // Audit history
                Text('Audit History',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                if (_actions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No streak actions recorded.',
                          style: TextStyle(color: Colors.grey[500])),
                    ),
                  )
                else
                  ..._actions.map((a) => _buildActionCard(a)),
              ],
            ),
    );
  }

  Widget _buildActionForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Take Action',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Flag repeated failures or request a streak review.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g. Missed 5 consecutive days without explanation',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.edit_note_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _flagStreak,
                    icon: const Icon(Icons.flag_outlined, color: Colors.orange),
                    label: const Text('Flag',
                        style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _requestReview,
                    icon: const Icon(Icons.search),
                    label: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Request Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(StreakAction action) {
    final needsAck = !action.acknowledged &&
        action.subjectUid == _myUid &&
        action.type == StreakActionType.reviewRequested;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ActionBadge(type: action.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.type.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                          'by ${action.initiatorName} · streak was ${action.currentStreakAtAction}d',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM d')
                      .format(action.createdAt ?? DateTime.now()),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(action.reason, style: const TextStyle(fontSize: 13)),
            ),
            if (action.acknowledged) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text('Acknowledged',
                      style: TextStyle(fontSize: 11, color: Colors.green[700])),
                ],
              ),
            ],
            if (needsAck) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _acknowledgeAction(action, false),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green)),
                      child: const Text('Deny Reset',
                          style: TextStyle(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acknowledgeAction(action, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      child: const Text('Confirm Reset'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final StreakActionType type;
  const _ActionBadge({required this.type});

  Color get _color {
    switch (type) {
      case StreakActionType.flagged:
        return Colors.orange;
      case StreakActionType.reviewRequested:
        return Colors.blue;
      case StreakActionType.resetConfirmed:
        return Colors.red;
      case StreakActionType.resetDenied:
        return Colors.green;
    }
  }

  String get _emoji {
    switch (type) {
      case StreakActionType.flagged:
        return '🚩';
      case StreakActionType.reviewRequested:
        return '🔍';
      case StreakActionType.resetConfirmed:
        return '❌';
      case StreakActionType.resetDenied:
        return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 18))),
    );
  }
}
