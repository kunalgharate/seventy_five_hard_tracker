import 'package:hive_flutter/hive_flutter.dart';
import '../models/challenge.dart';
import '../models/daily_progress.dart';
import '../models/challenge_session.dart';

class DatabaseRepository {
  static const String _challengeSessionBoxName = 'challenge_sessions';
  static const String _dailyProgressBoxName = 'daily_progress';
  static const String _settingsBoxName = 'settings';

  late Box<ChallengeSession> _sessionBox;
  late Box<DailyProgress> _progressBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChallengeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DailyProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ChallengeSessionAdapter());
    }

    // Open boxes
    _sessionBox = await Hive.openBox<ChallengeSession>(_challengeSessionBoxName);
    _progressBox = await Hive.openBox<DailyProgress>(_dailyProgressBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  // Challenge Session methods
  Future<void> saveSession(ChallengeSession session) async {
    await _sessionBox.put(session.id, session);
  }

  ChallengeSession? getActiveSession() {
    try {
      return _sessionBox.values.firstWhere(
        (session) => session.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  List<ChallengeSession> getAllSessions() {
    return _sessionBox.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  Future<void> updateSession(ChallengeSession session) async {
    await _sessionBox.put(session.id, session);
  }

  // Daily Progress methods
  Future<void> saveDailyProgress(DailyProgress progress) async {
    final key = _dateToKey(progress.date);
    await _progressBox.put(key, progress);
  }

  DailyProgress? getDailyProgress(DateTime date) {
    final key = _dateToKey(date);
    return _progressBox.get(key);
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
    await _settingsBox.put(key, value);
  }

  T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  // Utility methods
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> hasActiveSession() async {
    await _ensureInitialized();
    final sessions = _sessionBox.values.toList();
    return sessions.any((session) => session.isActive && !session.isCompleted);
  }

  Future<void> _ensureInitialized() async {
    if (!Hive.isBoxOpen(_challengeSessionBoxName)) {
      await init();
    }
  }

  Future<void> clearAllData() async {
    await _sessionBox.clear();
    await _progressBox.clear();
    await _settingsBox.clear();
  }

  Future<void> clearAllDailyProgress() async {
    await _ensureInitialized();
    await _progressBox.clear();
  }
}
