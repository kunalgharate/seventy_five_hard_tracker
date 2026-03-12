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

  const DailyProgress({
    required this.date,
    required this.challengeCompletions,
    this.journalNote,
    required this.isCompleted,
    this.taskNotes,
  });

  DailyProgress copyWith({
    DateTime? date,
    Map<String, bool>? challengeCompletions,
    String? journalNote,
    bool? isCompleted,
    Map<String, String>? taskNotes,
  }) {
    return DailyProgress(
      date: date ?? this.date,
      challengeCompletions: challengeCompletions ?? this.challengeCompletions,
      journalNote: journalNote ?? this.journalNote,
      isCompleted: isCompleted ?? this.isCompleted,
      taskNotes: taskNotes ?? this.taskNotes,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'challengeCompletions': challengeCompletions,
    'journalNote': journalNote,
    'isCompleted': isCompleted,
    'taskNotes': taskNotes,
  };

  @override
  List<Object?> get props => [
        date,
        challengeCompletions,
        journalNote,
        isCompleted,
        taskNotes,
      ];
}
