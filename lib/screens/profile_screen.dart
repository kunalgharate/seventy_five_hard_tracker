import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/discipline_score.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/widgets/discipline_heatmap.dart';
import 'package:seventy_five_hard_tracker/widgets/achievements_showcase.dart';
import 'journal_timeline_screen.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _syncService = CloudSyncService();
  bool _isSyncing = false;
  bool _isSigningIn = false;
  bool _consentGiven = true;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _loadConsentState();
  }

  Future<void> _loadConsentState() async {
    final given = await _syncService.hasConsentBeenGiven();
    if (mounted) setState(() => _consentGiven = given);
  }

  Future<void> _loadLastSync() async {
    final time = await _syncService.getLastSyncTime();
    if (mounted) setState(() => _lastSync = time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          final isLoaded = state is ChallengeLoaded;
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Auth status card
                      _buildAuthActionCard()
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.2),
                      const SizedBox(height: 24),

                      if (isLoaded) ...[
                        // Achievements
                        AchievementsShowcase(state: state)
                            .animate(delay: 100.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.2),
                        const SizedBox(height: 24),

                        // Discipline Grade
                        _buildDisciplineGradeCard()
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.2),
                        const SizedBox(height: 24),

                        // Stats Grid
                        _buildPremiumStatsGrid(state)
                            .animate(delay: 700.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 16),

                        _buildJournalTimelineButton()
                            .animate(delay: 800.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 32),

                        // Heatmap
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: DisciplineHeatmap(
                              progressList: state.currentProgress,
                              challengeTaskIds: state.activeSession?.challenges
                                  .where((c) => c.taskType != 'regular')
                                  .map((c) => c.id)
                                  .toSet(),
                            ),
                          ),
                        )
                            .animate(delay: 400.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.2),
                        const SizedBox(height: 24),
                      ],

                      _buildSyncStatusCard()
                          .animate(delay: 500.ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.2),
                      const SizedBox(height: 16),
                      _buildPrivacyCard()
                          .animate(delay: 600.ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.2),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Hero Sliver App Bar ──────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return StreamBuilder<User?>(
      stream: _syncService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isSignedIn = user != null;

        return SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary
                        .withBlue(255), // gradient end (shifted blue channel)
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (isSignedIn && user.photoURL != null)
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                            child: (isSignedIn && user.photoURL != null)
                                ? null
                                : const Icon(Icons.person,
                                    size: 50, color: AppColors.primary),
                          ),
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 12),
                      Text(
                        isSignedIn
                            ? (user.displayName ?? 'Signed In')
                            : 'Local Challenger',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                      if (isSignedIn && user.email != null)
                        Text(
                          user.email!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthActionCard() {
    return StreamBuilder<User?>(
      stream: _syncService.authStateChanges,
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data != null;
        if (isSignedIn) {
          return Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
          );
        }
        return Card(
          elevation: 0,
          color: AppColors.primary.withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Secure Cloud Backup',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Sign in to sync your progress',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSigningIn ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isSigningIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Discipline Grade Card ────────────────────────────────────────────────────────

  Widget _buildDisciplineGradeCard() {
    return BlocBuilder<DisciplineScoreBloc, DisciplineScoreState>(
      builder: (context, state) {
        if (state is! DisciplineScoreLoaded) return const SizedBox.shrink();

        final grade = state.grade;
        Color gradeColor;
        if (grade.startsWith('A')) {
          gradeColor = Colors.green;
        } else if (grade.startsWith('B')) {
          gradeColor = Colors.blue;
        } else if (grade.startsWith('C')) {
          gradeColor = Colors.orange;
        } else {
          gradeColor = Colors.red;
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [gradeColor.withValues(alpha: 0.15), Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
                color: gradeColor.withValues(alpha: 0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discipline Grade',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score: ${state.disciplineScore.toInt()}/100',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradeColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    grade,
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: gradeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Premium Stats Grid ───────────────────────────────────────────────────

  Widget _buildPremiumStatsGrid(ChallengeLoaded state) {
    final totalSessions = state.allSessions.length;
    final completedSessions =
        state.allSessions.where((s) => s.isCompleted).length;
    // Aggregate days across all sessions for lifetime scope
    int totalDaysTracked = 0;
    int completedDays = 0;
    for (final session in state.allSessions) {
      totalDaysTracked += session.currentDay;
    }
    // currentProgress may have more detail for the active session
    final activeCompleted =
        state.currentProgress.where((p) => p.isCompleted).length;
    completedDays = activeCompleted;
    // Add completed days from past completed sessions
    for (final session in state.allSessions) {
      if (session.isCompleted && session != state.activeSession) {
        completedDays += session.currentDay;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Journey Overview',
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGlassTile(
                'Sessions', '$totalSessions', Icons.replay, Colors.blue),
            const SizedBox(width: 12),
            _buildGlassTile('Completed', '$completedSessions',
                Icons.emoji_events, Colors.amber),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGlassTile('Days Tracked', '$totalDaysTracked',
                Icons.calendar_today, Colors.teal),
            const SizedBox(width: 12),
            _buildGlassTile('Perfect Days', '$completedDays',
                Icons.check_circle, Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildJournalTimelineButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const JournalTimelineScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[400]!, Colors.orange[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_stories,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mental Toughness Journal',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Read your past thoughts & reflections',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTile(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sync status card ─────────────────────────────────────────────────────

  Widget _buildSyncStatusCard() {
    final isSignedIn = _syncService.isSignedIn;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cloud Backup',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_isSyncing)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(
                    isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                    color: isSignedIn ? Colors.green : Colors.grey,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isSignedIn
                  ? 'Automatic backup is active. Your data is encrypted with AES-256 before it leaves your device.'
                  : 'Sign in to enable automatic encrypted cloud backup.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (_lastSync != null && isSignedIn) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Last synced: ${_formatSyncTime(_lastSync!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ],
            if (isSignedIn && !_consentGiven) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _enableBackup,
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Enable Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Privacy card ─────────────────────────────────────────────────────────

  Widget _buildPrivacyCard() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy & Security',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _privacyRow(
                Icons.lock, 'AES-256 encryption — task names & all data'),
            _privacyRow(Icons.key, 'Only you can decrypt your data'),
            _privacyRow(Icons.visibility_off, 'We cannot read your content'),
            _privacyRow(Icons.phone_android, 'Works fully offline'),
            _privacyRow(Icons.sync, 'Auto-syncs when online'),
          ],
        ),
      ),
    );
  }

  Widget _privacyRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  String _formatSyncTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return isoTime;
    }
  }

  // ── Auth actions ─────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!mounted || _isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      final user = await _syncService.signInWithGoogle().timeout(
            const Duration(seconds: 60),
          );
      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in cancelled. Please try again.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      var backupEnabled = await _syncService.hasConsentBeenGiven();
      if (!backupEnabled && mounted) {
        backupEnabled = await _showConsentDialog();
      }
      if (backupEnabled) {
        await _syncService.recordConsent();
        _triggerAutoSync();
      }
      if (mounted) {
        setState(() => _consentGiven = backupEnabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              backupEnabled
                  ? 'Cloud backup enabled for ${user.displayName ?? user.email}'
                  : 'Signed in. Enable cloud backup anytime from this screen.',
            ),
            backgroundColor: backupEnabled ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Sign-in timed out. Check your connection and try again.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOut() async {
    await _syncService.signOut();
    if (mounted) {
      setState(() => _lastSync = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Signed out'), backgroundColor: Colors.grey),
      );
    }
  }

  Future<void> _enableBackup() async {
    await _syncService.recordConsent();
    if (!mounted) return;
    setState(() => _consentGiven = true);
    _triggerAutoSync();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cloud backup is now enabled.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// After sign-in, checks if local data is empty. If so, restores from cloud.
  /// Otherwise uploads local data to cloud.
  void _triggerAutoSync() async {
    final db = context.read<ChallengeBloc>().repository;
    final taskRepo = context.read<RegularTaskBloc>().repository;
    setState(() => _isSyncing = true);

    try {
      // Check if local database is empty (reinstall scenario)
      final hasLocalData = await db.hasActiveSession();

      if (!hasLocalData) {
        // Try restoring from cloud first
        final cloudData = await _syncService.syncFromCloud();
        if (cloudData != null &&
            (cloudData['sessions'] as List?)?.isNotEmpty == true) {
          await db.restoreFromJson(cloudData);
          await taskRepo.restoreFromJson(cloudData);
          if (mounted) {
            context.read<ChallengeBloc>().add(LoadChallengeData());
            context.read<RegularTaskBloc>().add(LoadRegularTasks());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your data has been restored from cloud!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // Local data exists — sync it up to cloud
        final success = await _syncService.syncToCloud(db, taskRepo);
        if (mounted && success) {
          _loadLastSync();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<bool> _showConsentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Cloud Backup'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Before enabling backup, here\'s what you need to know:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            _ConsentPoint(
                icon: Icons.lock_outline,
                text: 'Task names and data are encrypted with AES-256.'),
            SizedBox(height: 8),
            _ConsentPoint(
                icon: Icons.key, text: 'Only you can decrypt your data.'),
            SizedBox(height: 8),
            _ConsentPoint(
                icon: Icons.sync,
                text: 'Backup happens automatically when online.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not Now')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Enable Backup'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ConsentPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConsentPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.green[600]),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
      ],
    );
  }
}
