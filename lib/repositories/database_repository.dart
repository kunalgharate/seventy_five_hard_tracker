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
    final key = _progressKey(progress.date, progress.sessionId);
    await _progressBox!.put(key, progress);
  }

  /// Adopts date-only progress written by pre-session-scoped versions of the
  /// app into [session]. Legacy records are ambiguous when several historical
  /// sessions exist, so only the active session is eligible for adoption.
  /// Existing session-scoped records always win.
  Future<void> adoptLegacyProgressForSession(ChallengeSession session) async {
    await _ensureInitialized();
    final legacyEntries = <MapEntry<dynamic, DailyProgress>>[];
    for (final entry in _progressBox!.toMap().entries) {
      if (entry.key is String &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.key as String) &&
          entry.value.sessionId == null) {
        legacyEntries.add(MapEntry(entry.key, entry.value));
      }
    }

    for (final entry in legacyEntries) {
      final date = entry.value.date;
      final day = DateTime(date.year, date.month, date.day);
      final start = DateTime(
        session.startDate.year,
        session.startDate.month,
        session.startDate.day,
      );
      final end = start.add(Duration(days: session.totalDaysTarget - 1));
      if (day.isBefore(start) || day.isAfter(end)) continue;

      final scopedKey = _progressKey(date, session.id);
      if (_progressBox!.get(scopedKey) == null) {
        await _progressBox!.put(
          scopedKey,
          entry.value.copyWith(sessionId: session.id),
        );
      }
      await _progressBox!.delete(entry.key);
    }
  }

  /// Reads progress for a specific session. Callers without a session ID may
  /// still read legacy date-only records for migration tooling.
  DailyProgress? getDailyProgress(DateTime date, {String? sessionId}) {
    final box = _progressBox;
    if (box == null) return null;

    if (sessionId != null) {
      final sessionProgress = box.get(_progressKey(date, sessionId));
      if (sessionProgress != null) return sessionProgress;
    }

    if (sessionId != null) return null;
    return box.get(_dateToKey(date));
  }

  List<DailyProgress> getProgressForSession(
    DateTime startDate, {
    String? sessionId,
    int totalDaysTarget = 75,
  }) {
    final List<DailyProgress> sessionProgress = [];
    for (int i = 0; i < totalDaysTarget; i++) {
      final date = startDate.add(Duration(days: i));
      final progress = getDailyProgress(date, sessionId: sessionId);
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

  String _progressKey(DateTime date, String? sessionId) {
    final dateKey = _dateToKey(date);
    return sessionId == null ? dateKey : '$sessionId|$dateKey';
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

    final uid = _currentUid;
    // Replacement semantics are field-scoped. A present collection replaces
    // the local collection, including an intentionally empty array. An
    // omitted collection is left untouched so partial backups are supported.
    List<ChallengeSession>? sessionsToRestore;
    if (data.containsKey('sessions')) {
      final sessions = (data['sessions'] as List?) ?? [];
      sessionsToRestore = [
        for (final s in sessions)
          _sessionFromJson(s as Map<String, dynamic>, uid: uid),
      ];
    }

    List<DailyProgress>? progressToRestore;
    if (data.containsKey('progress')) {
      final progress = (data['progress'] as List?) ?? [];
      progressToRestore = [
        for (final p in progress)
          DailyProgress.fromJson(p as Map<String, dynamic>),
      ];
    }

    if (sessionsToRestore != null) {
      await _sessionBox!.clear();
      for (final session in sessionsToRestore) {
        await _sessionBox!.put(session.id, session);
      }
    }

    if (progressToRestore != null) {
      await _progressBox!.clear();
      for (final dp in progressToRestore) {
        final key = _progressKey(dp.date, dp.sessionId);
        await _progressBox!.put(key, dp);
      }
    }
  }

  ChallengeSession _sessionFromJson(
    Map<String, dynamic> json, {
    required String? uid,
  }) {
    var session = ChallengeSession.fromJson(json);
    if (session.ownerUid == null && uid != null) {
      session = session.copyWith(ownerUid: uid);
    }
    return session;
  }
}
