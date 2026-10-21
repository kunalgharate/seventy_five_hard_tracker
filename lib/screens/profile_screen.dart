import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/discipline_score.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_event.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/core/services/photo_sync_service.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'package:seventy_five_hard_tracker/core/services/notification_service.dart';
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
  bool _isSigningOut = false;
  String? _lastSync;

  // Offline-cached profile (SharedPreferences — same KV store the sync
  // service already uses). Written at sign-in, read when auth/user fetch
  // is unavailable so the header never goes blank.
  static const _kCachedName = 'cachedProfileDisplayName';
  static const _kCachedEmail = 'cachedProfileEmail';
  static const _kCachedPhoto = 'cachedProfilePhotoUrl';
  String? _cachedName;
  String? _cachedEmail;
  String? _cachedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _loadCachedProfile();
  }

  Future<void> _loadLastSync() async {
    final time = await _syncService.getLastSyncTime();
    if (mounted) setState(() => _lastSync = time);
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _cachedName = prefs.getString(_kCachedName);
        _cachedEmail = prefs.getString(_kCachedEmail);
        _cachedPhotoUrl = prefs.getString(_kCachedPhoto);
      });
    } catch (_) {}
  }

  Future<void> _cacheProfile(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user.displayName != null) {
        await prefs.setString(_kCachedName, user.displayName!);
      }
      if (user.email != null) {
        await prefs.setString(_kCachedEmail, user.email!);
      }
      if (user.photoURL != null) {
        await prefs.setString(_kCachedPhoto, user.photoURL!);
      }
      if (!mounted) return;
      setState(() {
        _cachedName = user.displayName ?? _cachedName;
        _cachedEmail = user.email ?? _cachedEmail;
        _cachedPhotoUrl = user.photoURL ?? _cachedPhotoUrl;
      });
    } catch (_) {}
  }

  Future<void> _clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedName);
      await prefs.remove(_kCachedEmail);
      await prefs.remove(_kCachedPhoto);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _cachedName = null;
        _cachedEmail = null;
        _cachedPhotoUrl = null;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading avatar...'), duration: Duration(seconds: 30)),
    );

    final photoService = PhotoSyncService();
    final url = await photoService.uploadAvatar(File(picked.path), user.uid);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload avatar. Please try again.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await user.updatePhotoURL(url);
      // Also update the users doc in Firestore
      await _syncService.updateUserPhotoUrl(user.uid, url);
      // Refresh cached profile
      await _cacheProfile(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
      );
    }
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
        // Never a blank screen: on stream error or while waiting, fall back
        // to the locally cached profile (or the signed-out state).
        final user = snapshot.data;
        final hasCache = _cachedName != null ||
            _cachedEmail != null ||
            _cachedPhotoUrl != null;
        final isSignedIn = user != null;
        final displayName = user?.displayName ??
            (isSignedIn ? 'Signed In' : (_cachedName ?? 'Local Challenger'));
        final email = user?.email ?? _cachedEmail;
        final photoUrl = user?.photoURL ?? _cachedPhotoUrl;
        final photoImage = photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null;
        // Offline hint: auth stream has no live user but we have saved data,
        // or the stream itself errored.
        final showOfflineHint = (user == null && hasCache) || snapshot.hasError;

        return SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                    AppColors.accent,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: isSignedIn ? _pickAndUploadAvatar : null,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white,
                                backgroundImage: photoImage,
                                onBackgroundImageError:
                                    photoImage != null ? (_, __) {} : null,
                                child: photoImage != null
                                    ? null
                                    : const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                            if (isSignedIn)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                      if (email != null)
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
                      if (showOfflineHint)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Offline · showing saved profile',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
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
              onPressed: _isSigningOut ? null : _signOut,
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
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Sign In'),
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
            if (isSignedIn) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _manualSync,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(_isSyncing ? 'Syncing…' : 'Sync now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
      ),
    );

    try {
      final user = await _syncService.signInWithGoogle();
      if (!mounted) return;
      Navigator.pop(context);

      if (user != null) {
        await _cacheProfile(user);
        try {
          await _syncService.recordConsent();
        } catch (e) {
          // Consent flag write failure shouldn't abort the sign-in flow or
          // pop the navigator a second time (the loading dialog is already
          // closed above).
          debugPrint('[Profile] Failed to record consent: $e');
        }
        if (!mounted) return;
        _triggerAutoSync();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cloud backup enabled for ${user.displayName ?? user.email}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data will be backed up before signing out. If backup fails, '
          'you will stay signed in and your local data will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Back up & sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    final db = context.read<ChallengeBloc>().repository;
    final taskRepo = context.read<RegularTaskBloc>().repository;

    // Back up this account's data first. The service returns a safe decision
    // and never clears local data when backup or cleanup fails.
    late final SignOutPreparationStatus preparation;
    try {
      preparation = await _syncService.prepareForSignOut(db, taskRepo);
    } catch (_) {
      // Treat an unexpected backup error exactly like a reported failure:
      // never proceed to local cleanup or auth sign-out.
      preparation = SignOutPreparationStatus.backupFailed;
    }
    if (!preparation.maySignOut) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preparation == SignOutPreparationStatus.backupFailed
                  ? 'Backup failed. You are still signed in and your local data was kept.'
                  : 'Local cleanup failed. You are still signed in and your local data was kept.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Reminders were scheduled from this account's tasks — cancel them.
    try {
      await SmartNotificationService()
          .cancelAllRemindersForDate(DateTime.now());
    } catch (_) {}
    try {
      await NotificationService().cancelAllNotifications();
    } catch (_) {}

    // Drop cached partner read-access lists from the previous account.
    try {
      AccountabilityService().invalidateAllowedReaders();
    } catch (_) {}

    await _syncService.signOut();
    await _clearCachedProfile();

    if (mounted) {
      context.read<ChallengeBloc>().add(LoadChallengeData());
      context.read<RegularTaskBloc>().add(LoadRegularTasks());
      context.read<DisciplineScoreBloc>().add(ResetDisciplineScore());
      context.read<AccountabilityBloc>().add(LoadAccountabilityData());
      setState(() => _lastSync = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Signed out'), backgroundColor: Colors.grey),
      );
    }
    if (mounted) setState(() => _isSigningOut = false);
  }

  /// Manual "Sync now" — calls the existing [CloudSyncService.syncToCloud]
  /// without modifying the service. Progress via [_isSyncing], result via
  /// success/error SnackBars.
  Future<void> _manualSync() async {
    if (_isSyncing) return;
    if (!_syncService.isSignedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to enable cloud backup.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final db = context.read<ChallengeBloc>().repository;
      final taskRepo = context.read<RegularTaskBloc>().repository;
      final ok = await _syncService.syncToCloud(db, taskRepo);
      if (!mounted) return;
      if (ok) {
        await _loadLastSync();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup synced successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync failed. Check connection and try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// After sign-in, reconciles local data with the signed-in account:
  /// restores this account's cloud backup if local data is empty or belongs
  /// to a different account, otherwise uploads local data to cloud.
  void _triggerAutoSync() async {
    final db = context.read<ChallengeBloc>().repository;
    final taskRepo = context.read<RegularTaskBloc>().repository;
    setState(() => _isSyncing = true);

    try {
      final result = await _syncService.reconcileOnSignIn(db, taskRepo);
      if (!mounted) return;
      context.read<ChallengeBloc>().add(LoadChallengeData());
      context.read<RegularTaskBloc>().add(LoadRegularTasks());
      if (result.restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your data has been restored from cloud!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result.uploaded) {
        _loadLastSync();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
