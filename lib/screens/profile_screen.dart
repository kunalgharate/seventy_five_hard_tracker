import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/challenge_bloc.dart';
import '../bloc/challenge_state.dart';
import '../bloc/challenge_event.dart';
import '../services/cloud_sync_service.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _syncService = CloudSyncService();
  bool _isSyncing = false;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final time = await _syncService.getLastSyncTime();
    if (mounted) setState(() => _lastSync = time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildUserCard(),
              const SizedBox(height: 16),
              if (state is ChallengeLoaded) _buildStatsCard(state),
              const SizedBox(height: 16),
              _buildSyncCard(),
              const SizedBox(height: 16),
              _buildPrivacyCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCard() {
    return StreamBuilder(
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
                  child: Icon(
                    isSignedIn ? Icons.person : Icons.person_outline,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isSignedIn ? 'Synced Account' : 'Local Only',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSignedIn
                      ? 'Your data is backed up securely'
                      : 'Sign in to backup your progress',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (!isSignedIn)
                  ElevatedButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Enable Cloud Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
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

  Widget _buildSyncCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud Sync',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'All data is AES-encrypted before upload. We cannot read your data.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (_lastSync != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last sync: ${_formatSyncTime(_lastSync!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncToCloud,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isSyncing ? 'Syncing...' : 'Backup Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _syncFromCloud,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Restore'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
            _privacyRow(Icons.lock, 'AES-256 encryption for all cloud data'),
            _privacyRow(Icons.visibility_off, 'We cannot read your data'),
            _privacyRow(Icons.phone_android, 'Works fully offline'),
            _privacyRow(Icons.delete_forever, 'Sign out deletes cloud link'),
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

  Future<void> _signIn() async {
    final user = await _syncService.signInAnonymously();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user != null
              ? 'Cloud backup enabled!'
              : 'Sign-in failed. Try again.'),
          backgroundColor: user != null ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await _syncService.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Signed out'), backgroundColor: Colors.grey),
      );
    }
  }

  Future<void> _syncToCloud() async {
    final repo = context.read<ChallengeBloc>().repository;
    if (!_syncService.isSignedIn) {
      await _signIn();
      if (!_syncService.isSignedIn) return;
    }

    setState(() => _isSyncing = true);
    final success = await _syncService.syncToCloud(repo);
    await _loadLastSync();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Backup complete!'
              : 'Backup failed. Check connection.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _syncFromCloud() async {
    if (!_syncService.isSignedIn) {
      await _signIn();
      if (!_syncService.isSignedIn) return;
    }

    setState(() => _isSyncing = true);
    final data = await _syncService.syncFromCloud();
    setState(() => _isSyncing = false);

    if (mounted) {
      if (data != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Data?'),
            content: Text(
              'Found backup from ${data['syncedAt'] ?? 'unknown date'}.\n\n'
              'This will replace your local data. Continue?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final repo = context.read<ChallengeBloc>().repository;
                  final bloc = context.read<ChallengeBloc>();
                  await repo.restoreFromJson(data);
                  if (!mounted) return;
                  bloc.add(LoadChallengeData());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Restore complete!'),
                        backgroundColor: Colors.green),
                  );
                },
                child: const Text('Restore'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No backup found'), backgroundColor: Colors.orange),
        );
      }
    }
  }
}
