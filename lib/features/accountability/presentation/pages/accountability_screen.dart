import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/features/accountability/presentation/bloc/accountability_state.dart';
import 'package:seventy_five_hard_tracker/features/accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/accountability/data/models/partner_review.dart';
import 'package:seventy_five_hard_tracker/features/accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/main.dart';

// ── Main screen ──────────────────────────────────────────────────────────────

class AccountabilityScreen extends StatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  State<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends State<AccountabilityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    context.read<AccountabilityBloc>().add(LoadAccountabilityData());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Accountability',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context
                .read<AccountabilityBloc>()
                .add(LoadAccountabilityData()),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: BlocConsumer<AccountabilityBloc, AccountabilityState>(
              listener: _handleStateChange,
              builder: (context, state) {
                if (state is AccountabilityLoading ||
                    state is AccountabilityInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AccountabilityError) {
                  return _buildError(state.message);
                }
                final loaded = state is AccountabilityLoaded ? state : null;
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _DashboardTab(partners: loaded?.partners ?? []),
                    _PartnersTab(partners: loaded?.partners ?? []),
                    _ReviewsTab(reviews: loaded?.myReviews ?? []),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.primary,
      child: TabBar(
        controller: _tabs,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(
              icon: Icon(Icons.dashboard_outlined, size: 18),
              text: 'Dashboard'),
          Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Partners'),
          Tab(
              icon: Icon(Icons.rate_review_outlined, size: 18),
              text: 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'invite',
          onPressed: () => _showInviteSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Invite Partner',
          child: const Icon(Icons.person_add_outlined),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'join',
          mini: true,
          onPressed: () => _showJoinSheet(context),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          tooltip: 'Join with code',
          child: const Icon(Icons.qr_code_scanner),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<AccountabilityBloc>()
                  .add(LoadAccountabilityData()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, AccountabilityState state) {
    if (state is PartnerInvited) {
      _showInviteCodeDialog(context, state.partner);
    } else if (state is InviteAccepted) {
      _showSnack('You are now connected with ${state.partner.partnerName}!',
          isSuccess: true);
    } else if (state is ReviewSubmitted) {
      _showSnack('Review submitted!', isSuccess: true);
    } else if (state is AccountabilityError) {
      _showSnack(state.message, isSuccess: false);
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Invite sheet ─────────────────────────────────────────────────

  void _showInviteSheet(BuildContext context) {
    final syncService = CloudSyncService();
    if (!syncService.isSignedIn) {
      _showSnack('Sign in first (Profile tab) to use accountability features.',
          isSuccess: false);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AccountabilityBloc>(),
        child: const _InvitePartnerSheet(),
      ),
    );
  }

  void _showJoinSheet(BuildContext context) {
    final syncService = CloudSyncService();
    if (!syncService.isSignedIn) {
      _showSnack('Sign in first (Profile tab) to use accountability features.',
          isSuccess: false);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AccountabilityBloc>(),
        child: const _JoinWithCodeSheet(),
      ),
    );
  }

  void _showInviteCodeDialog(
      BuildContext context, AccountabilityPartner partner) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with ${partner.partnerName}:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    partner.inviteCode,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: partner.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'They enter this code in the "Join with code" button.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final List<AccountabilityPartner> partners;
  const _DashboardTab({required this.partners});

  @override
  Widget build(BuildContext context) {
    final accepted =
        partners.where((p) => p.status == PartnershipStatus.accepted).toList();
    final pending =
        partners.where((p) => p.status == PartnershipStatus.pending).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const _SectionHeader(title: 'Your Progress', icon: Icons.bar_chart),
        const SizedBox(height: 8),
        _MyProgressCard(),
        const SizedBox(height: 20),
        const _SectionHeader(
            title: 'Weekly Consistency', icon: Icons.calendar_today),
        const SizedBox(height: 8),
        _WeeklyConsistencyCard(),
        const SizedBox(height: 20),
        if (accepted.isNotEmpty) ...[
          const _SectionHeader(
              title: 'Partner Activity', icon: Icons.people_outline),
          const SizedBox(height: 8),
          ...accepted.map((p) => _PartnerActivityCard(partner: p)),
          const SizedBox(height: 20),
        ],
        const _SectionHeader(title: 'Summary', icon: Icons.info_outline),
        const SizedBox(height: 8),
        _SummaryCard(
          accepted: accepted.length,
          pending: pending.length,
        ),
      ],
    );
  }
}

class _MyProgressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Pull stats from ChallengeBloc state via context
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Progress',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            const Row(
              children: [
                _StatBox(label: 'Completed', value: '—', color: Colors.green),
                SizedBox(width: 8),
                _StatBox(label: 'Missed', value: '—', color: Colors.red),
                SizedBox(width: 8),
                _StatBox(
                    label: 'Current Day', value: '—', color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Complete tasks on the 75 Hard tab to update your progress.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyConsistencyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Build last 7 days labels
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateFormat('E').format(d);
    });

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
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: days.map((day) {
                final isToday = day == DateFormat('E').format(now);
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isToday ? Icons.today : Icons.circle_outlined,
                        size: 16,
                        color: isToday ? Colors.white : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(day,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                isToday ? AppColors.primary : Colors.grey[600],
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal)),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Consistency data updates as you complete daily tasks.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerActivityCard extends StatefulWidget {
  final AccountabilityPartner partner;
  const _PartnerActivityCard({required this.partner});

  @override
  State<_PartnerActivityCard> createState() => _PartnerActivityCardState();
}

class _PartnerActivityCardState extends State<_PartnerActivityCard> {
  List<Map<String, dynamic>> _weeklyData = [];
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
    final data = await AccountabilityService().fetchPartnerWeeklyProgress(uid);
    if (mounted) {
      setState(() {
        _weeklyData = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoleAvatar(role: widget.partner.role, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.partner.partnerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(widget.partner.role.label,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_weeklyData.isEmpty)
              Text('No activity data yet.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]))
            else
              _buildWeekRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weeklyData.take(7).map((d) {
        final done = d['dayCompleted'] as bool? ?? false;
        final dateKey = d['dateKey'] as String? ?? '';
        final label = dateKey.length >= 10
            ? DateFormat('E').format(DateTime.parse(dateKey))
            : '?';
        return Column(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.cancel_outlined,
              color: done ? Colors.green : Colors.red[300],
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        );
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int accepted;
  final int pending;
  const _SummaryCard({required this.accepted, required this.pending});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _StatBox(
                label: 'Active Partners',
                value: '$accepted',
                color: Colors.green),
            const SizedBox(width: 8),
            _StatBox(
                label: 'Pending Invites',
                value: '$pending',
                color: Colors.orange),
          ],
        ),
      ),
    );
  }
}

// ── Partners Tab ─────────────────────────────────────────────────────────────

class _PartnersTab extends StatelessWidget {
  final List<AccountabilityPartner> partners;
  const _PartnersTab({required this.partners});

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        title: 'No partners yet',
        subtitle:
            'Invite a friend, trainer, or mentor to keep you accountable.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: partners.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PartnerCard(partner: partners[i]),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final AccountabilityPartner partner;
  const _PartnerCard({required this.partner});

  @override
  Widget build(BuildContext context) {
    final isPending = partner.status == PartnershipStatus.pending;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _RoleAvatar(role: partner.role, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner.partnerName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(partner.role.label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  _StatusChip(status: partner.status),
                  if (isPending) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: partner.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      child: Row(
                        children: [
                          Text('Code: ',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          Text(partner.inviteCode,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  color: AppColors.primary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy,
                              size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'remove') {
                  _confirmRemove(context, partner);
                } else if (v == 'review') {
                  _openReviewSheet(context, partner);
                }
              },
              itemBuilder: (_) => [
                if (!isPending && partner.partnerUid != null)
                  const PopupMenuItem(
                      value: 'review', child: Text('Review their progress')),
                const PopupMenuItem(
                    value: 'remove', child: Text('Remove partner')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, AccountabilityPartner partner) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Partner?'),
        content: Text(
            'Remove ${partner.partnerName} as your accountability partner?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<AccountabilityBloc>().add(RemovePartner(partner.id));
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openReviewSheet(BuildContext context, AccountabilityPartner partner) {
    if (partner.partnerUid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AccountabilityBloc>(),
        child: _ReviewSheet(partner: partner),
      ),
    );
  }
}

// ── Reviews Tab ──────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final List<PartnerReview> reviews;
  const _ReviewsTab({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.rate_review_outlined,
        title: 'No reviews yet',
        subtitle:
            'Once partners review your progress, their feedback appears here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ReviewCard(review: reviews[i]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final PartnerReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isApproved = review.decision == ReviewDecision.approved;
    final isRejected = review.decision == ReviewDecision.rejected;
    final color = isApproved
        ? Colors.green
        : isRejected
            ? Colors.red
            : Colors.orange;
    final icon = isApproved
        ? Icons.check_circle
        : isRejected
            ? Icons.cancel
            : Icons.hourglass_empty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(review.reviewerName,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      Text(
                        DateFormat('MMM d').format(review.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(review.decision.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (review.comment != null && review.comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${review.comment}"',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('For: ${review.dateKey}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invite Partner Bottom Sheet ──────────────────────────────────────────────

class _InvitePartnerSheet extends StatefulWidget {
  const _InvitePartnerSheet();

  @override
  State<_InvitePartnerSheet> createState() => _InvitePartnerSheetState();
}

class _InvitePartnerSheetState extends State<_InvitePartnerSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  PartnerRole _role = PartnerRole.friend;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('Invite Accountability Partner',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Partner Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Role',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PartnerRole.values.map((r) {
                      final selected = _role == r;
                      return ChoiceChip(
                        label: Text('${r.emoji} ${r.label}'),
                        selected: selected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _role = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Create Invite',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a partner name')));
      return;
    }
    setState(() => _loading = true);
    context.read<AccountabilityBloc>().add(InvitePartner(
          partnerName: name,
          partnerEmail:
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          role: _role,
        ));
    Navigator.pop(context);
  }
}

// ── Join With Code Sheet ─────────────────────────────────────────────────────

class _JoinWithCodeSheet extends StatefulWidget {
  const _JoinWithCodeSheet();

  @override
  State<_JoinWithCodeSheet> createState() => _JoinWithCodeSheetState();
}

class _JoinWithCodeSheetState extends State<_JoinWithCodeSheet> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            const SizedBox(height: 8),
            Text('Join with Invite Code',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character code your partner shared with you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 6),
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: TextStyle(
                    color: Colors.grey[400], letterSpacing: 6, fontSize: 24),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Join',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a 6-character code')));
      return;
    }
    setState(() => _loading = true);
    context.read<AccountabilityBloc>().add(AcceptInvite(code));
    Navigator.pop(context);
  }
}

// ── Review Sheet ─────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final AccountabilityPartner partner;
  const _ReviewSheet({required this.partner});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _commentCtrl = TextEditingController();
  ReviewDecision _decision = ReviewDecision.approved;
  List<Map<String, dynamic>> _pendingDays = [];
  String? _selectedDateKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    final uid = widget.partner.partnerUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final days =
        await AccountabilityService().fetchPendingReviewsForPartner(uid);
    if (mounted) {
      setState(() {
        _pendingDays = days;
        _selectedDateKey =
            days.isNotEmpty ? days.first['dateKey'] as String : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('Review ${widget.partner.partnerName}\'s Progress',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingDays.isEmpty
                      ? Center(
                          child: Text('No pending days to review.',
                              style: TextStyle(color: Colors.grey[600])))
                      : ListView(
                          controller: ctrl,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildDaySelector(),
                            const SizedBox(height: 20),
                            _buildDecisionSelector(),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _commentCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Comment / Motivation (optional)',
                                alignLabelWithHint: true,
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 40),
                                  child: Icon(Icons.comment_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Submit Review',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Day',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedDateKey,
          items: _pendingDays.map((d) {
            final key = d['dateKey'] as String;
            final completed = d['completedTasks'] as int? ?? 0;
            final total = d['totalTasks'] as int? ?? 0;
            return DropdownMenuItem(
                value: key, child: Text('$key  ($completed/$total tasks)'));
          }).toList(),
          onChanged: (v) => setState(() => _selectedDateKey = v),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.calendar_today_outlined)),
        ),
      ],
    );
  }

  Widget _buildDecisionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Decision',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            _DecisionButton(
              label: 'Approve',
              icon: Icons.check_circle_outline,
              color: Colors.green,
              selected: _decision == ReviewDecision.approved,
              onTap: () => setState(() => _decision = ReviewDecision.approved),
            ),
            const SizedBox(width: 12),
            _DecisionButton(
              label: 'Needs Work',
              icon: Icons.cancel_outlined,
              color: Colors.red,
              selected: _decision == ReviewDecision.rejected,
              onTap: () => setState(() => _decision = ReviewDecision.rejected),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    if (_selectedDateKey == null) return;
    final uid = widget.partner.partnerUid;
    if (uid == null) return;
    context.read<AccountabilityBloc>().add(SubmitReview(
          subjectUid: uid,
          reviewerName: 'Me',
          dateKey: _selectedDateKey!,
          decision: _decision,
          comment: _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
        ));
    Navigator.pop(context);
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RoleAvatar extends StatelessWidget {
  final PartnerRole role;
  final double size;
  const _RoleAvatar({required this.role, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(role.emoji, style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PartnershipStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == PartnershipStatus.accepted
        ? Colors.green
        : status == PartnershipStatus.pending
            ? Colors.orange
            : Colors.red;
    final label = status == PartnershipStatus.accepted
        ? 'Active'
        : status == PartnershipStatus.pending
            ? 'Pending'
            : 'Declined';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color : Colors.grey[300]!, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 26),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
