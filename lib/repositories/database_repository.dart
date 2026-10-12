import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';

class DatabaseRepository {
  static const String _challengeSessionBoxName = 'challenge_sessions';
  static const String _dailyProgressBoxName = 'daily_progress';
  static const String _settingsBoxName = 'settings';

  Box<ChallengeSession>? _sessionBox;
  Box<DailyProgress>? _progressBox;
  Box? _settingsBox;

  bool get _isInitialized =>
      _sessionBox != null && _progressBox != null && _settingsBox != null;

  Future<void> init() async {
    if (_isInitialized) return;

    // Open boxes (adapters are registered once in main.dart)
    _sessionBox =
        await Hive.openBox<ChallengeSession>(_challengeSessionBoxName);
    _progressBox = await Hive.openBox<DailyProgress>(_dailyProgressBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // Challenge Session methods

  /// UID of the signed-in account, or null when signed out.
  String? get _currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// A session is visible when it has no owner (legacy/local-only data) or
  /// belongs to the signed-in account. Foreign-account sessions are never
  /// read, shown, or synced.
  bool _isVisible(ChallengeSession session) =>
      session.ownerUid == null || session.ownerUid == _currentUid;

  Future<void> saveSession(ChallengeSession session) async {
    await _ensureInitialized();
    if (session.ownerUid == null) {
      final uid = _currentUid;
      if (uid != null) session = session.copyWith(ownerUid: uid);
    }
    await _sessionBox!.put(session.id, session);
  }

  /// Stamps all legacy (unowned) sessions with [uid] — used when the
  /// signed-in account adopts pre-existing local data at app start.
  Future<void> adoptSessionsFor(String uid) async {
    await _ensureInitialized();
    final legacy =
        _sessionBox!.values.where((s) => s.ownerUid == null).toList();
    for (final session in legacy) {
      await _sessionBox!.put(session.id, session.copyWith(ownerUid: uid));
    }
  }

  Future<ChallengeSession?> getActiveSession() async {
    await _ensureInitialized();
    try {
      return _sessionBox!.values.firstWhere((session) =>
          _isVisible(session) && session.isActive && !session.isCompleted);
    } on StateError {
      // No active session found — expected case
      return null;
    }
  }

  List<ChallengeSession> getAllSessions() {
    if (_sessionBox == null) return [];
    return (_sessionBox!.values.where(_isVisible).toList())
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  Future<void> updateSession(ChallengeSession session) async {
    await _ensureInitialized();
    await _sessionBox!.put(session.id, session);
  }

  // Daily Progress methods
  Future<void> saveDailyProgress(DailyProgress progress) async {
    await _ensureInitialized();
    final key = _dateToKey(progress.date);
    await _progressBox!.put(key, progress);
  }

  DailyProgress? getDailyProgress(DateTime date) {
    final key = _dateToKey(date);
    return _progressBox?.get(key);
  }

  List<DailyProgress> getProgressForSession(DateTime startDate) {
    final List<DailyProgress> sessionProgress = [];
    for (int i = 0; i < 75; i++) {
      final date = startDate.add(Duration(days: i));
      final progress = getDailyProgress(date);
      if (progress != null) {
        sessionProgress.add(progress);
      }
    }
    return sessionProgress;
  }

  // Settings methods
  Future<void> saveSetting(String key, dynamic value) async {
    await _ensureInitialized();
    await _settingsBox!.put(key, value);
  }

  T? getSetting<T>(String key) {
    return _settingsBox?.get(key) as T?;
  }

  // Utility methods
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> hasActiveSession() async {
    await _ensureInitialized();
    return _sessionBox!.values.any((session) =>
        _isVisible(session) && session.isActive && !session.isCompleted);
  }

  Future<void> clearAllData() async {
    await _ensureInitialized();
    await _sessionBox!.clear();
    await _progressBox!.clear();
    await _settingsBox!.clear();
  }

  Future<void> clearAllDailyProgress() async {
    await _ensureInitialized();
    await _progressBox!.clear();
  }

  Future<void> restoreFromJson(Map<String, dynamic> data) async {
    await _ensureInitialized();
    await clearAllData();

    final uid = _currentUid;
    final sessions = (data['sessions'] as List?) ?? [];
    for (final s in sessions) {
      var session = ChallengeSession.fromJson(s as Map<String, dynamic>);
      if (session.ownerUid == null && uid != null) {
        session = session.copyWith(ownerUid: uid);
      }
      await _sessionBox!.put(session.id, session);
    }

    final progress = (data['progress'] as List?) ?? [];
    for (final p in progress) {
      final dp = DailyProgress.fromJson(p as Map<String, dynamic>);
      final key = _dateToKey(dp.date);
      await _progressBox!.put(key, dp);
    }
  }
}
