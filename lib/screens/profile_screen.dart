import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
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
  bool _consentGiven = false;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _loadConsentState();
  }

  Future<void> _loadConsentState() async {
    final consent = await _syncService.hasConsentBeenGiven();
    if (mounted) setState(() => _consentGiven = consent);
  }

  Future<void> _loadLastSync() async {
    final time = await _syncService.getLastSyncTime();
    if (mounted) setState(() => _lastSync = time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Profile'),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildUserCard(),
              const SizedBox(height: 16),
              if (state is ChallengeLoaded) _buildStatsCard(state),
              const SizedBox(height: 16),
              _buildSyncStatusCard(),
              const SizedBox(height: 16),
              _buildPrivacyCard(),
            ],
          );
        },
      ),
    );
  }

  // ── User card ────────────────────────────────────────────────────────────

  Widget _buildUserCard() {
    return StreamBuilder<User?>(
      stream: _syncService.authStateChanges,
      builder: (context, snapshot) {
        final user = _syncService.currentUser;
        final isSignedIn = user != null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary,
                  backgroundImage: (isSignedIn && user.photoURL != null)
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: (isSignedIn && user.photoURL != null)
                      ? null
                      : Icon(
                          isSignedIn ? Icons.person : Icons.person_outline,
                          size: 40,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  isSignedIn ? (user.displayName ?? 'Signed In') : 'Local Only',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSignedIn && user.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  isSignedIn
                      ? (_consentGiven
                          ? 'Your data is automatically backed up to the cloud.'
                          : 'Signed in. Enable Cloud Backup to back up your data automatically.')
                      : 'Your data is stored only on this device. Sign in to enable automatic backup.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (!isSignedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSigningIn ? null : _signIn,
                      icon: _isSigningIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                          _isSigningIn ? 'Signing in...' : 'Enable Cloud Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSigningIn
                          ? null
                          : () => _signIn(enableBackup: false),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In'),
                    ),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Stats card ───────────────────────────────────────────────────────────

  Widget _buildStatsCard(ChallengeLoaded state) {
    final totalSessions = state.allSessions.length;
    final completedSessions =
        state.allSessions.where((s) => s.isCompleted).length;
    final totalDaysTracked = state.currentProgress.length;
    final completedDays =
        state.currentProgress.where((p) => p.isCompleted).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Journey',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                _statTile(
                    'Sessions', '$totalSessions', Icons.replay, Colors.blue),
                _statTile('Completed', '$completedSessions', Icons.emoji_events,
                    Colors.amber),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statTile('Days Tracked', '$totalDaysTracked',
                    Icons.calendar_today, Colors.green),
                _statTile('Days Done', '$completedDays', Icons.check_circle,
                    Colors.teal),
              ],
            ),
            if (totalDaysTracked > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completedDays / totalDaysTracked,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(completedDays / totalDaysTracked * 100).toStringAsFixed(0)}% completion rate',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ── Sync status card (replaces manual backup/restore) ────────────────────

  Widget _buildSyncStatusCard() {
    final isSignedIn = _syncService.isSignedIn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cloud Backup',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_isSyncing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isSignedIn && _consentGiven
                        ? Icons.cloud_done
                        : isSignedIn
                            ? Icons.cloud
                            : Icons.cloud_off,
                    color: isSignedIn && _consentGiven
                        ? Colors.green
                        : Colors.grey,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isSignedIn && _consentGiven
                  ? 'Automatic backup is active. Your data is encrypted with AES-256 before it leaves your device.'
                  : isSignedIn
                      ? 'Cloud backup is not enabled yet. Tap "Back Up Now" below to save your data, or re-run "Enable Cloud Backup".'
                      : 'Sign in to enable automatic encrypted cloud backup.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (_lastSync != null && isSignedIn) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Last synced: ${_formatSyncTime(_lastSync!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
            if (isSignedIn) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _backUpNow,
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Back Up Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _restoreFromCloud,
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('Restore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal[700],
                    side: BorderSide(color: Colors.teal[400]!),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Back Up Now saves this device\'s latest data to the cloud. '
                'Restore downloads the cloud backup and replaces the data on '
                'this device.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.4),
              ),
            ],
            if (!isSignedIn) ...[
              const SizedBox(height: 4),
              Text(
                'Data stays on your device until you sign in.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy & Security',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
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

  /// Signs in with Google.
  ///
  /// When [enableBackup] is true (the "Enable Cloud Backup" button) the user
  /// is first asked for encryption consent and a backup is triggered after
  /// sign-in. When false (the "Sign In" button) it is a plain sign-in that
  /// skips the consent dialog.
  Future<void> _signIn({bool enableBackup = true}) async {
    if (_isSigningIn) return;

    // Show consent dialog first if not yet given (backup flow only)
    if (enableBackup) {
      final consentGiven = await _syncService.hasConsentBeenGiven();
      if (!consentGiven && mounted) {
        final accepted = await _showConsentDialog();
        if (!accepted) return;
        await _syncService.recordConsent();
        if (mounted) setState(() => _consentGiven = true);
      } else if (consentGiven && mounted) {
        setState(() => _consentGiven = true);
      }
    }

    if (!mounted) return;
    setState(() => _isSigningIn = true);

    try {
      final user = await _syncService
          .signInWithGoogle()
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (user != null) {
        // If the user previously consented, back up even via plain sign-in.
        final consentGiven = await _syncService.hasConsentBeenGiven();
        if (!mounted) return;
        if (enableBackup || consentGiven) {
          // Auto-sync immediately after sign-in
          _triggerAutoSync();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cloud backup enabled for ${user.displayName ?? user.email}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in as ${user.displayName ?? user.email}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Sign-in was cancelled or could not be completed. Please try again.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 100),
          ),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in timed out. Please check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 100),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
          content: Text('Signed out — data remains on this device'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  /// Triggers a background auto-sync after sign-in.
  void _triggerAutoSync() {
    final db = context.read<ChallengeBloc>().repository;
    final taskRepo = context.read<RegularTaskBloc>().repository;
    setState(() => _isSyncing = true);
    _syncService.syncToCloud(db, taskRepo).then((success) {
      if (!mounted) return;
      _loadLastSync();
      setState(() => _isSyncing = false);
    });
  }

  /// Manual "Back Up Now" action.
  Future<void> _backUpNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final db = context.read<ChallengeBloc>().repository;
      final taskRepo = context.read<RegularTaskBloc>().repository;
      final success = await _syncService.syncToCloud(db, taskRepo);
      await _loadLastSync();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Backup completed successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Backup failed. Check your connection and try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Manual "Restore" action — downloads cloud data and replaces local data.
  Future<void> _restoreFromCloud() async {
    if (_isSyncing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Cloud?'),
        content: const Text(
            'This will overwrite your current local data with the cloud backup. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSyncing = true);
    try {
      final data = await _syncService
          .syncFromCloud()
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;

      if (data == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('No cloud backup found to restore.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        return;
      }

      final db = context.read<ChallengeBloc>().repository;
      final taskRepo = context.read<RegularTaskBloc>().repository;
      await db.restoreFromJson(data);
      await taskRepo.restoreFromJson(data);

      if (!mounted) return;

      // Reload blocs so the UI reflects the restored data
      context.read<ChallengeBloc>().add(LoadChallengeData());
      context.read<RegularTaskBloc>().add(LoadRegularTasks());

      await _loadLastSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Data restored successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Restore timed out. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Consent dialog ───────────────────────────────────────────────────────

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
            Text(
              'Before enabling backup, here\'s what you need to know:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            _ConsentPoint(
              icon: Icons.lock_outline,
              text:
                  'Task names, journal notes, and all your progress data are encrypted with AES-256 before leaving your device.',
            ),
            SizedBox(height: 8),
            _ConsentPoint(
              icon: Icons.key,
              text:
                  'Your encryption key is derived from your account ID. Only you can decrypt your data.',
            ),
            SizedBox(height: 8),
            _ConsentPoint(
              icon: Icons.visibility_off,
              text:
                  'We cannot read your data. The server stores only ciphertext.',
            ),
            SizedBox(height: 8),
            _ConsentPoint(
              icon: Icons.sync,
              text:
                  'Backup happens automatically in the background whenever you\'re online.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable Backup'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Helper widget for consent dialog points ──────────────────────────────────

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
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}
