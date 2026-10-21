import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'daily_progress.g.dart';

@HiveType(typeId: 1)
class DailyProgress extends Equatable {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final Map<String, bool> challengeCompletions; // challengeId -> completed

  @HiveField(2)
  final String? journalNote;

  @HiveField(3)
  final bool isCompleted;

  @HiveField(4)
  final Map<String, String>? taskNotes; // challengeId -> note

  @HiveField(5)
  final Map<String, String>? taskPhotos; // challengeId -> photo path

  /// The challenge session this day's progress belongs to.
  ///
  /// This is nullable so records written before session-scoped progress was
  /// introduced remain readable and can be adopted by the active session.
  @HiveField(6)
  final String? sessionId;

  const DailyProgress({
    required this.date,
    required this.challengeCompletions,
    this.journalNote,
    required this.isCompleted,
    this.taskNotes,
    this.taskPhotos,
    this.sessionId,
  });

  DailyProgress copyWith({
    DateTime? date,
    Map<String, bool>? challengeCompletions,
    String? journalNote,
    bool? isCompleted,
    Map<String, String>? taskNotes,
    Map<String, String>? taskPhotos,
    String? sessionId,
  }) {
    return DailyProgress(
      date: date ?? this.date,
      challengeCompletions: challengeCompletions ?? this.challengeCompletions,
      journalNote: journalNote ?? this.journalNote,
      isCompleted: isCompleted ?? this.isCompleted,
      taskNotes: taskNotes ?? this.taskNotes,
      taskPhotos: taskPhotos ?? this.taskPhotos,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'challengeCompletions': challengeCompletions,
        'journalNote': journalNote,
        'isCompleted': isCompleted,
        'taskNotes': taskNotes,
        'taskPhotos': taskPhotos,
        'sessionId': sessionId,
      };

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      date: DateTime.parse(json['date'] as String),
      challengeCompletions:
          (json['challengeCompletions'] as Map).cast<String, bool>(),
      journalNote: json['journalNote'] as String?,
      isCompleted: json['isCompleted'] as bool,
      taskNotes: (json['taskNotes'] as Map?)?.cast<String, String>(),
      taskPhotos: (json['taskPhotos'] as Map?)?.cast<String, String>(),
      sessionId: json['sessionId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        date,
        challengeCompletions,
        journalNote,
        isCompleted,
        taskNotes,
        taskPhotos,
        sessionId,
      ];
}
