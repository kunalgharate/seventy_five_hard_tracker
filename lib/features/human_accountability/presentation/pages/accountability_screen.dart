import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_state.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/partner_review.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_invitation.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/app_user.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/pages/partner_progress_screen.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/pages/accountability_chat_screen.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/pages/weekly_summary_screen.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/pages/streak_escalation_screen.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/photo_proof_sheet.dart';
import 'package:seventy_five_hard_tracker/widgets/proof_review_dialog.dart';

// ── Main screen ──────────────────────────────────────────────────────────────

class AccountabilityScreen extends StatefulWidget {
  const AccountabilityScreen({super.key, this.onGoToProfile});

  /// Switches the bottom navigation to the Profile tab when the user needs
  /// to sign in before inviting a partner.
  final VoidCallback? onGoToProfile;

  @override
  State<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends State<AccountabilityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StreamSubscription<List<AccountabilityTask>>? _tasksStreamSub;
  StreamSubscription<List<AccountabilityTask>>? _assignedByMeStreamSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    context.read<AccountabilityBloc>().add(LoadAccountabilityData());
    _subscribeToTaskStream();
  }

  void _subscribeToTaskStream() {
    _tasksStreamSub?.cancel();
    _assignedByMeStreamSub?.cancel();
    _tasksStreamSub = AccountabilityService().myTasksStream().listen((_) {
      if (!mounted) return;
      context.read<AccountabilityBloc>().add(LoadAccountabilityData());
    }, onError: (_) {});
    _assignedByMeStreamSub =
        AccountabilityService().assignedByMeStream().listen((_) {
      if (!mounted) return;
      context.read<AccountabilityBloc>().add(LoadAccountabilityData());
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _tasksStreamSub?.cancel();
    _assignedByMeStreamSub?.cancel();
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
                    _PartnersTab(
                      partners: loaded?.partners ?? [],
                      incomingRequests: loaded?.incomingRequests ?? [],
                      emailInvitations: loaded?.emailInvitations ?? [],
                      taskRequests: loaded?.taskRequests ?? [],
                    ),
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
          Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Partners'),
          Tab(
              icon: Icon(Icons.rate_review_outlined, size: 18),
              text: 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'invitePartner',
      onPressed: _showInviteDialog,
      icon: const Icon(Icons.person_add),
      label: const Text('Add a Partner'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _showInviteDialog() {
    final syncService = CloudSyncService();
    if (!syncService.isSignedIn) {
      // Not signed in — prompt to sign in
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sign In Required',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with Google to invite accountability partners and sync your data.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onGoToProfile?.call();
                },
                icon: const Icon(Icons.person),
                label: const Text('Go to Profile to Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    } else {
      // Signed in — show the real invite partner sheet
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
      // Close the join sheet if it's still open, then show success
      Navigator.of(context).popUntil((route) => route.isFirst);
      _showSnack('You are now connected with ${state.partner.partnerName}!',
          isSuccess: true);
    } else if (state is ReviewSubmitted) {
      _showSnack('Review submitted!', isSuccess: true);
    } else if (state is InviteRejected) {
      _showSnack('Request declined.', isSuccess: true);
    } else if (state is EmailInviteSent) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      _showSnack(
        'Invite sent to ${state.invitation.toEmail}! They will see it when they open the app.',
        isSuccess: true,
      );
    } else if (state is EmailInviteAccepted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      _showSnack('You are now connected with ${state.partner.partnerName}!',
          isSuccess: true);
    } else if (state is EmailInviteRejected) {
      _showSnack('Invitation declined.', isSuccess: true);
    } else if (state is TaskRequestAccepted) {
      _showSnack('Task accepted! It will appear in your partner card.',
          isSuccess: true);
      debugPrint('[AccountabilityScreen] TaskRequestAccepted:'
          ' taskId=${state.taskId} challengeId=${state.challengeId}');
      if (state.challengeId != null) {
        try {
          debugPrint(
              '[AccountabilityScreen] Dispatching LoadChallengeData to ChallengeBloc');
          context.read<ChallengeBloc>().add(LoadChallengeData());
        } catch (e) {
          debugPrint(
              '[AccountabilityScreen] Failed to dispatch LoadChallengeData: $e');
        }
      }
    } else if (state is TaskRequestDeclined) {
      _showSnack('Task request declined.', isSuccess: true);
    } else if (state is AccountabilityError) {
      // Close any open bottom sheet so the snackbar is visible
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
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

  // ignore: unused_element
  void _showInviteSheet(BuildContext context) {
    final syncService = CloudSyncService();
    if (!syncService.isSignedIn) {
      Navigator.of(context).pushNamed('/login');
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

  // ignore: unused_element
  void _showJoinSheet(BuildContext context) {
    final syncService = CloudSyncService();
    if (!syncService.isSignedIn) {
      Navigator.of(context).pushNamed('/login');
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

// ignore: unused_element
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
    final myUid = AccountabilityService().currentUid;
    final uid = widget.partner.ownerUid == myUid
        ? widget.partner.partnerUid
        : widget.partner.ownerUid;
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
  final List<AccountabilityPartner> incomingRequests;
  final List<AccountabilityInvitation> emailInvitations;
  final List<AccountabilityTask> taskRequests;

  const _PartnersTab({
    required this.partners,
    required this.incomingRequests,
    this.emailInvitations = const [],
    this.taskRequests = const [],
  });

  @override
  Widget build(BuildContext context) {
    final accepted =
        partners.where((p) => p.status == PartnershipStatus.accepted).toList();

    final hasEmailInvites = emailInvitations.isNotEmpty;
    final hasCodeRequests = incomingRequests.isNotEmpty;
    final hasTaskRequests = taskRequests.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const SizedBox(height: 20),

        // ── Partner cards ─────────────────────────────────────────
        ...accepted.map((p) => _AcceptedPartnerCard(partner: p)),
        if (accepted.isNotEmpty) const SizedBox(height: 20),

        // ── Pending invites I sent ───────────────────────────────
        ...() {
          final myUid = AccountabilityService().currentUid;
          final pending = partners
              .where((p) =>
                  p.status == PartnershipStatus.pending && p.ownerUid == myUid)
              .toList();
          if (pending.isEmpty) return const <Widget>[];
          return [
            _SectionLabel(
              title: 'Pending Invites',
              icon: Icons.hourglass_empty,
              color: Colors.orange,
              count: pending.length,
            ),
            const SizedBox(height: 10),
            ...pending.map((p) => _PendingInviteCard(partner: p)),
            const SizedBox(height: 20),
          ];
        }(),

        // ── Empty state ──────────────────────────────────────────
        if (accepted.isEmpty &&
            !hasCodeRequests &&
            !hasTaskRequests &&
            !hasEmailInvites &&
            partners
                .where((p) =>
                    p.status == PartnershipStatus.pending &&
                    p.ownerUid == AccountabilityService().currentUid)
                .isEmpty)
          const _EmptyState(
            icon: Icons.people_outline,
            title: 'No Partners Yet',
            subtitle:
                'Tap the invite button to add an accountability partner.\n'
                'Once they accept, you\'ll see them here.',
          ),

        // ── Requests for You ──────────────────────────────────────
        if (hasEmailInvites || hasTaskRequests || hasCodeRequests) ...[
          _SectionLabel(
            title: 'Requests for You',
            icon: Icons.mark_email_unread_outlined,
            color: Colors.blue,
            count: incomingRequests.length +
                emailInvitations.length +
                taskRequests.length,
          ),
          const SizedBox(height: 10),
          // Code-based incoming partnership requests
          ...incomingRequests.map((p) => _IncomingRequestCard(partner: p)),
          // Task assignment requests
          ...taskRequests.map((t) => _TaskRequestCard(task: t)),
          // Email-based partner invitations
          ...emailInvitations
              .map((inv) => _EmailInvitationCard(invitation: inv)),
        ],
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;

  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}

// ── Accepted partner card — expandable accordion ──────────────────────────────

class _AcceptedPartnerCard extends StatefulWidget {
  final AccountabilityPartner partner;
  const _AcceptedPartnerCard({required this.partner});

  @override
  State<_AcceptedPartnerCard> createState() => _AcceptedPartnerCardState();
}

class _AcceptedPartnerCardState extends State<_AcceptedPartnerCard> {
  List<Map<String, dynamic>> _recentDays = [];
  List<String> _challengeNames = [];
  List<AccountabilityTask> _accountabilityTasks = [];
  bool _loading = false;
  bool _expanded = false;
  bool _loaded = false;

  Future<void> _loadTasks({bool forceRefresh = false}) async {
    if (_loading) return;
    if (_loaded && !forceRefresh) return;
    final myUid = AccountabilityService().currentUid;
    // Resolve the other person's UID for progress/challenge name fetches
    final otherUid = widget.partner.ownerUid == myUid
        ? widget.partner.partnerUid
        : widget.partner.ownerUid;

    debugPrint(
        '[PartnerCard] loading tasks for partnershipId=${widget.partner.id} otherUid=$otherUid');
    setState(() {
      _loading = true;
      if (forceRefresh) _accountabilityTasks = [];
    });
    try {
      // fetchTasksForPartnership works for both sides — always run it
      final tasksFuture =
          AccountabilityService().fetchTasksForPartnership(widget.partner.id);

      // Progress/challenge name fetches only work if we know the other UID
      final progressFuture = otherUid != null
          ? AccountabilityService().fetchPartnerWeeklyProgress(otherUid)
          : Future.value(<Map<String, dynamic>>[]);
      final namesFuture = otherUid != null
          ? AccountabilityService().fetchPartnerChallengeNames(otherUid)
          : Future.value(<String>[]);

      final results =
          await Future.wait([progressFuture, namesFuture, tasksFuture]);
      if (mounted) {
        setState(() {
          _recentDays = results[0] as List<Map<String, dynamic>>;
          _challengeNames = results[1] as List<String>;
          _accountabilityTasks = results[2] as List<AccountabilityTask>;
          _loading = false;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('[PartnerCard] loadTasks error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccountabilityBloc, AccountabilityState>(
      listener: (ctx, state) {
        if (state is AccountabilityLoaded && _expanded) {
          _loadTasks(forceRefresh: true);
        }
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Theme(
          // Remove default divider from ExpansionTile
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            onExpansionChanged: (v) {
              setState(() => _expanded = v);
              if (v) _loadTasks(forceRefresh: true);
            },
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(widget.partner.role.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            title: Text(
              widget.partner.partnerName,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.partner.role.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    const Text('Active Partner',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      size: 20),
                  tooltip: 'Message',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AccountabilityChatScreen(
                              partner: widget.partner))),
                ),
                PopupMenuButton<String>(
                  icon:
                      Icon(Icons.more_vert, color: Colors.grey[600], size: 22),
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'progress',
                      child: Row(children: [
                        Icon(Icons.bar_chart_outlined,
                            size: 18, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('View Progress'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'weekly',
                      child: Row(children: [
                        Icon(Icons.summarize_outlined,
                            size: 18, color: Colors.purple),
                        SizedBox(width: 10),
                        Text('Weekly Summary'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'review',
                      child: Row(children: [
                        Icon(Icons.rate_review_outlined,
                            size: 18, color: Colors.orange),
                        SizedBox(width: 10),
                        Text('Review Progress'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'escalate',
                      child: Row(children: [
                        Icon(Icons.flag_outlined, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Flag / Escalate'),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        Icon(Icons.person_remove_outlined,
                            size: 18, color: Colors.grey),
                        SizedBox(width: 10),
                        Text('Remove Partner'),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            // ── Expanded section ───────────────────────────────────
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Partner info row
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    widget.partner.acceptedAt != null
                        ? 'Partner since ${DateFormat('MMM d, yyyy').format(widget.partner.acceptedAt!)}'
                        : 'Active partner',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tasks heading
              Text('Accountability Tasks',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                ...() {
                  final myUid = AccountabilityService().currentUid;
                  final visibleTasks = _accountabilityTasks
                      .where((t) =>
                          t.partnershipId == widget.partner.id &&
                          (t.assignedByUid == myUid ||
                              t.accountableUid == myUid))
                      .toList();
                  if (visibleTasks.isEmpty) {
                    return [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text('No tasks yet.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ];
                  }
                  return visibleTasks.map((task) {
                    final isCompleted =
                        task.status == AccountabilityTaskStatus.completed;
                    final proofStatus = task.proofStatus;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withValues(alpha: 0.06)
                            : Colors.orange.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color:
                                    isCompleted ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(task.title,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    if (task.description != null &&
                                        task.description!.isNotEmpty)
                                      Text(task.description!,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              _buildPartnerTaskStatusChip(
                                  isCompleted, proofStatus, task.status),
                            ],
                          ),
                          if (!isCompleted)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildPartnerTaskAction(task),
                            ),
                        ],
                      ),
                    );
                  });
                }(),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerTaskStatusChip(bool isCompleted, ProofStatus? proofStatus,
      AccountabilityTaskStatus status) {
    if (isCompleted || status == AccountabilityTaskStatus.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Completed',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green[700])),
      );
    }
    if (status == AccountabilityTaskStatus.declined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Declined',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.red[700])),
      );
    }
    if (status == AccountabilityTaskStatus.requested) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Pending',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700])),
      );
    }
    // status is pending — show proof status
    if (proofStatus == ProofStatus.submitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Proof Submitted',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700])),
      );
    }
    if (proofStatus == ProofStatus.approved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
            const SizedBox(width: 3),
            Text('Approved',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700])),
          ],
        ),
      );
    }
    if (proofStatus == ProofStatus.rejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 12, color: Colors.red[700]),
            const SizedBox(width: 3),
            Text('Rejected',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700])),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Accepted',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green[700])),
    );
  }

  // ignore: unused_element
  Widget _buildPendingActions(AccountabilityTask task) {
    if (task.challengeId != null) {
      if (task.proofStatus == ProofStatus.rejected) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final ok = await PhotoProofSheet.show(
                context: context,
                taskId: task.id,
                taskName: task.title,
                date: DateTime.now(),
              );
              if (ok == true && context.mounted) {
                context
                    .read<AccountabilityBloc>()
                    .add(LoadAccountabilityData());
              }
            },
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: Text(task.proofStatus == ProofStatus.rejected
                ? 'Resubmit Photo Proof'
                : 'Submit Photo Proof'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }
      if (task.proofStatus == ProofStatus.submitted) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_empty, size: 16),
            label: const Text('Awaiting Review'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[400],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }
      if (task.proofStatus == ProofStatus.approved) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
            label: Text('Approved', style: TextStyle(color: Colors.green[700])),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          setState(() => _loading = true);
          final ok =
              await AccountabilityService().completeAccountabilityTask(task.id);
          if (mounted) setState(() => _loading = false);
          if (ok && context.mounted) {
            context.read<AccountabilityBloc>().add(LoadAccountabilityData());
            if (task.challengeId != null) {
              try {
                context.read<ChallengeBloc>().add(UpdateDailyProgress(
                      date: DateTime.now(),
                      challengeId: task.challengeId!,
                      isCompleted: true,
                    ));
              } catch (_) {
                // safe to ignore
              }
            }
          }
        },
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Mark Complete'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildPartnerTaskAction(AccountabilityTask task) {
    final myUid = AccountabilityService().currentUid;
    final iAmAssignee = task.accountableUid == myUid;

    if (!iAmAssignee && task.proofStatus == ProofStatus.submitted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final ok = await ProofReviewDialog.show(context, task);
            if (ok == true && context.mounted) {
              context.read<AccountabilityBloc>().add(LoadAccountabilityData());
            }
          },
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          label: const Text('Review Proof'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    if (iAmAssignee) {
      if (task.proofStatus == ProofStatus.submitted) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_empty, size: 16),
            label: const Text('Awaiting Review'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[400],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final ok = await PhotoProofSheet.show(
              context: context,
              taskId: task.id,
              taskName: task.title,
              date: DateTime.now(),
            );
            if (ok == true && context.mounted) {
              context.read<AccountabilityBloc>().add(LoadAccountabilityData());
            }
          },
          icon: Icon(
              task.proofStatus == ProofStatus.rejected
                  ? Icons.refresh
                  : Icons.check,
              size: 16),
          label: Text(task.proofStatus == ProofStatus.rejected
              ? 'Resubmit'
              : 'Mark Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ignore: unused_element
  List<Widget> _buildTaskList() {
    final latest = _recentDays.isNotEmpty ? _recentDays.first : null;
    if (latest == null) return [];

    final dateKey = latest['dateKey'] as String? ?? '';
    final taskDetails =
        (latest['taskDetails'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final completed = latest['completedTasks'] as int? ?? 0;
    final total = latest['totalTasks'] as int? ?? 0;

    return [
      // Date + progress ring header
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            _MiniProgressRing(completed: completed, total: total),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest: $dateKey',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  Text('$completed / $total tasks completed',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),

      // Individual task name rows
      if (taskDetails.isNotEmpty)
        ...taskDetails.map((task) {
          final name = task['name'] as String? ?? 'Task';
          final done = task['completed'] as bool? ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: done
                  ? Colors.green.withValues(alpha: 0.06)
                  : Colors.orange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: done
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: done ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Text(
                  done ? 'Done' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: done ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          );
        })
      else
      // Fallback: use stored challenge names from publishChallengeMeta
      if (_challengeNames.isNotEmpty)
        ..._challengeNames.map((name) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.task_alt_outlined,
                      size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Text('No data',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ))
      else
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            '$completed / $total tasks completed on $dateKey',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      // ── Add Task button ──────────────────────────────────────
      Builder(
          builder: (context) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddTaskInline(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Task'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              )),
    ];
  }

  void _showAddTaskInline(BuildContext context) {
    final partner = widget.partner;
    final partnerUid = partner.partnerUid;
    if (partnerUid == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Add Task for ${partner.partnerName}',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Task title *',
                      prefixIcon: const Icon(Icons.task_alt_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) return;
                              setModalState(() => submitting = true);
                              await AccountabilityService()
                                  .createAccountabilityTask(
                                accountableUid: partnerUid,
                                accountableName: partner.partnerName,
                                partnershipId: partner.id,
                                title: title,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              // Refresh the task list in the card
                              setState(() {
                                _recentDays = [];
                                _accountabilityTasks = [];
                              });
                              _loadTasks();
                            },
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add, size: 18),
                      label: Text(submitting ? 'Adding...' : 'Add Task'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _onMenu(BuildContext context, String v) {
    switch (v) {
      case 'progress':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PartnerProgressScreen(partner: widget.partner)));
        break;
      case 'weekly':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => WeeklySummaryScreen(partner: widget.partner)));
        break;
      case 'review':
        if (widget.partner.partnerUid == null) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BlocProvider.value(
            value: context.read<AccountabilityBloc>(),
            child: _ReviewSheet(partner: widget.partner),
          ),
        );
        break;
      case 'escalate':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StreakEscalationScreen(
                    partner: widget.partner, currentStreak: 0)));
        break;
      case 'remove':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove Partner?'),
            content: Text(
                'Remove ${widget.partner.partnerName} as your accountability partner?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  context
                      .read<AccountabilityBloc>()
                      .add(RemovePartner(widget.partner.id));
                },
                child:
                    const Text('Remove', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
    }
  }
}

class _MiniProgressRing extends StatelessWidget {
  final int completed;
  final int total;
  const _MiniProgressRing({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 4,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              pct >= 1.0 ? Colors.green : AppColors.primary,
            ),
          ),
          Text(
            '${(pct * 100).toInt()}%',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── Pending invite card (sent by me, not yet accepted) ────────────────────────

class _PendingInviteCard extends StatelessWidget {
  final AccountabilityPartner partner;
  const _PendingInviteCard({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _RoleAvatar(role: partner.role, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner.partnerName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(partner.role.label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  // Invite code with copy
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: partner.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied!')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.key_outlined,
                              size: 13, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            partner.inviteCode,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy,
                              size: 12, color: Colors.orange),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Pending',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Incoming request card (someone invited me) ────────────────────────────────

class _IncomingRequestCard extends StatefulWidget {
  final AccountabilityPartner partner;
  const _IncomingRequestCard({required this.partner});

  @override
  State<_IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<_IncomingRequestCard> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoleAvatar(role: widget.partner.role, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.partner.partnerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                          '${widget.partner.role.emoji} ${widget.partner.role.label}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 3),
                      Text(
                        'Wants you as their accountability partner',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _acting ? null : _reject,
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('Decline',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acting ? null : _accept,
                    icon: _acting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  void _accept() {
    setState(() => _acting = true);
    // Accept via invite code stored in the partnership
    context
        .read<AccountabilityBloc>()
        .add(AcceptInvite(widget.partner.inviteCode));
  }

  void _reject() {
    setState(() => _acting = true);
    context.read<AccountabilityBloc>().add(RejectInvite(widget.partner.id));
  }
}

// ── Reviews Tab ──────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final List<PartnerReview> reviews;
  const _ReviewsTab({required this.reviews});

  @override
  Widget build(BuildContext context) {
    // Use a real-time stream so reviews appear immediately when partner submits
    return StreamBuilder<List<PartnerReview>>(
      stream: AccountabilityService().reviewsStream(),
      builder: (context, snap) {
        final liveReviews = snap.data ?? reviews;
        if (liveReviews.isEmpty) {
          return const _EmptyState(
            icon: Icons.rate_review_outlined,
            title: 'No reviews yet',
            subtitle:
                'Once partners review your progress, their feedback appears here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: liveReviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ReviewCard(review: liveReviews[i]),
        );
      },
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
    // Dispatch the event — the parent AccountabilityScreen's BlocConsumer
    // listener (_handleStateChange) will close this sheet on success/failure
    // via the navigator, so we do NOT pop here.
    context.read<AccountabilityBloc>().add(AcceptInvite(code));
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
    // The subject is always the owner — the partner reviews the owner's progress.
    final subjectUid = widget.partner.ownerUid;
    final days =
        await AccountabilityService().fetchPendingReviewsForPartner(subjectUid);
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
    // subjectUid = the person whose progress is being reviewed.
    // The owner invited the partner to watch their progress,
    // so the subject is always the ownerUid.
    final subjectUid = widget.partner.ownerUid;
    final reviewerUid = AccountabilityService().currentUid;
    if (reviewerUid == null) return;

    context.read<AccountabilityBloc>().add(SubmitReview(
          subjectUid: subjectUid,
          reviewerName: AccountabilityService().currentUserDisplayName,
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

// ignore: unused_element
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

// ── Email Invitation Card ─────────────────────────────────────────────────────

/// Shows an incoming email-based invitation with Accept / Reject actions.
class _EmailInvitationCard extends StatefulWidget {
  final AccountabilityInvitation invitation;
  const _EmailInvitationCard({required this.invitation});

  @override
  State<_EmailInvitationCard> createState() => _EmailInvitationCardState();
}

class _EmailInvitationCardState extends State<_EmailInvitationCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                      child: Icon(Icons.email_outlined,
                          color: Colors.blue, size: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.fromName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        inv.fromEmail,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(inv.role.emoji,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(inv.role.label,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Invite',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        context
                            .read<AccountabilityBloc>()
                            .add(RejectEmailInvite(inv.id));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        context
                            .read<AccountabilityBloc>()
                            .add(AcceptEmailInvite(inv.id));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Invite By Email Sheet ─────────────────────────────────────────────────────

/// Google Keep-style email collaborator invite sheet.
/// Lets the user type an email address, shows a live lookup result,
/// then sends the invite via [SendEmailInvite].
/// Falls back to the code-based flow via a text button.
class _InviteByEmailSheet extends StatefulWidget {
  const _InviteByEmailSheet();

  @override
  State<_InviteByEmailSheet> createState() => _InviteByEmailSheetState();
}

class _InviteByEmailSheetState extends State<_InviteByEmailSheet> {
  final _emailCtrl = TextEditingController();
  PartnerRole _role = PartnerRole.friend;
  bool _sending = false;
  AppUser? _foundUser;
  bool _lookupDone = false;
  bool _looking = false;
  String _lookupEmail = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _onLookup() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    setState(() {
      _looking = true;
      _lookupDone = false;
      _foundUser = null;
      _lookupEmail = email;
    });
    context.read<AccountabilityBloc>().add(LookupUserByEmail(email));
  }

  void _sendInvite() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid email address')));
      return;
    }
    setState(() => _sending = true);
    context.read<AccountabilityBloc>().add(
          SendEmailInvite(toEmail: email, role: _role),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccountabilityBloc, AccountabilityState>(
      listener: (context, state) {
        if (state is EmailLookupFound) {
          setState(() {
            _foundUser = state.user;
            _lookupDone = true;
            _looking = false;
          });
        } else if (state is EmailLookupNotFound) {
          setState(() {
            _foundUser = null;
            _lookupDone = true;
            _looking = false;
          });
        } else if (state is EmailInviteSent || state is AccountabilityError) {
          setState(() => _sending = false);
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Add Collaborator',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Email field + lookup ───────────────────────
                    Text('Email address',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _onLookup(),
                            decoration: InputDecoration(
                              hintText: 'collaborator@example.com',
                              prefixIcon:
                                  const Icon(Icons.email_outlined, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            onChanged: (v) {
                              // Reset lookup state when user types
                              if (_lookupDone) {
                                setState(() {
                                  _lookupDone = false;
                                  _foundUser = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _looking ? null : _onLookup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: _looking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.search, size: 20),
                          ),
                        ),
                      ],
                    ),

                    // ── Lookup result ─────────────────────────────
                    if (_lookupDone) ...[
                      const SizedBox(height: 12),
                      if (_foundUser != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.06),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_foundUser!.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(_foundUser!.email,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.06),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No account found for $_lookupEmail. '
                                  'They\'ll see the invite when they sign up.',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 20),

                    // ── Role selector ─────────────────────────────
                    Text('Relationship',
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
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _role = r),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // ── Send invite button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _sendInvite,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_outlined, size: 18),
                        label: Text(_sending ? 'Sending...' : 'Send Invite'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Fallback: use code instead ────────────────
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => BlocProvider.value(
                              value: context.read<AccountabilityBloc>(),
                              child: const _InvitePartnerSheet(),
                            ),
                          );
                        },
                        icon:
                            Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                        label: Text('Use invite code instead',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Task Request Card ─────────────────────────────────────────────────────────

/// Shows an incoming task assignment request with Accept / Decline actions.
class _TaskRequestCard extends StatefulWidget {
  final AccountabilityTask task;
  const _TaskRequestCard({required this.task});

  @override
  State<_TaskRequestCard> createState() => _TaskRequestCardState();
}

class _TaskRequestCardState extends State<_TaskRequestCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.task_alt_outlined,
                        color: Colors.teal, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'From: ${task.assignedByName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty)
                        Text(
                          task.description!,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(task),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else if (task.status == AccountabilityTaskStatus.pending)
              _buildPendingActions(task)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        context
                            .read<AccountabilityBloc>()
                            .add(DeclineTaskRequest(task.id));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        context
                            .read<AccountabilityBloc>()
                            .add(AcceptTaskRequest(task.id));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(AccountabilityTask task) {
    if (task.status == AccountabilityTaskStatus.requested) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Task Request',
            style: TextStyle(
                fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600)),
      );
    }
    return _buildProofStatusChip(task);
  }

  Widget _buildProofStatusChip(AccountabilityTask task) {
    if (task.challengeId != null) {
      switch (task.proofStatus) {
        case ProofStatus.submitted:
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Awaiting Review',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600)),
          );
        case ProofStatus.approved:
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                const SizedBox(width: 3),
                Text('Approved',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        case ProofStatus.not_required:
          break;
        case ProofStatus.rejected:
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, size: 12, color: Colors.red[700]),
                const SizedBox(width: 3),
                Text('Rejected',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Active Task',
          style: TextStyle(
              fontSize: 11,
              color: Colors.orange[700],
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPendingActions(AccountabilityTask task) {
    if (task.proofStatus == ProofStatus.submitted) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty, size: 16),
          label: const Text('Awaiting Review'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue[400],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final ok = await PhotoProofSheet.show(
            context: context,
            taskId: task.id,
            taskName: task.title,
            date: DateTime.now(),
          );
          if (ok == true && context.mounted) {
            context.read<AccountabilityBloc>().add(LoadAccountabilityData());
          }
        },
        icon: const Icon(Icons.check, size: 16),
        label: Text(task.proofStatus == ProofStatus.rejected
            ? 'Resubmit'
            : 'Mark Complete'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
