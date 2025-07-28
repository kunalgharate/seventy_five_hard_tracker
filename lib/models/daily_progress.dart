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

  const DailyProgress({
    required this.date,
    required this.challengeCompletions,
    this.journalNote,
    required this.isCompleted,
  });

  DailyProgress copyWith({
    DateTime? date,
    Map<String, bool>? challengeCompletions,
    String? journalNote,
    bool? isCompleted,
  }) {
    return DailyProgress(
      date: date ?? this.date,
      challengeCompletions: challengeCompletions ?? this.challengeCompletions,
      journalNote: journalNote ?? this.journalNote,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [date, challengeCompletions, journalNote, isCompleted];
}
