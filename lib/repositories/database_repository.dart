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
  Future<void> saveSession(ChallengeSession session) async {
    await _ensureInitialized();
    await _sessionBox!.put(session.id, session);
  }

  Future<ChallengeSession?> getActiveSession() async {
    await _ensureInitialized();
    try {
      return _sessionBox!.values.firstWhere((session) => session.isActive);
    } on StateError {
      // No active session found — expected case
      return null;
    }
  }

  List<ChallengeSession> getAllSessions() {
    if (_sessionBox == null) return [];
    return (_sessionBox!.values.toList())
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
    return _sessionBox!.values
        .any((session) => session.isActive && !session.isCompleted);
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

    final sessions = (data['sessions'] as List?) ?? [];
    for (final s in sessions) {
      final session = ChallengeSession.fromJson(s as Map<String, dynamic>);
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
