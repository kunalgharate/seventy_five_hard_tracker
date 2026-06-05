import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'regular_task_completion.g.dart';

@HiveType(typeId: 4)
class RegularTaskCompletion extends Equatable {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final Map<String, bool> taskCompletions; // taskId -> completed

  RegularTaskCompletion({
    required DateTime date,
    required this.taskCompletions,
  }) : date = DateTime(date.year, date.month, date.day);

  RegularTaskCompletion copyWith({
    DateTime? date,
    Map<String, bool>? taskCompletions,
  }) {
    return RegularTaskCompletion(
      date: date ?? this.date,
      taskCompletions: taskCompletions ?? this.taskCompletions,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'taskCompletions': taskCompletions,
      };

  factory RegularTaskCompletion.fromJson(Map<String, dynamic> json) {
    return RegularTaskCompletion(
      date: DateTime.parse(json['date'] as String),
      taskCompletions: (json['taskCompletions'] as Map).cast<String, bool>(),
    );
  }

  /// Returns the date key in "YYYY-MM-DD" format for Hive storage.
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
        date,
        taskCompletions,
      ];
}
