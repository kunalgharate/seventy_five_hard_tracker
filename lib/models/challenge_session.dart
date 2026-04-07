import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';
import 'challenge.dart';

part 'challenge_session.g.dart';

enum ResetMode {
  hard,  // Any missed task resets to day 1
  soft   // Missed tasks tracked but no reset
}

@HiveType(typeId: 2)
class ChallengeSession extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final List<Challenge> challenges;
  
  @HiveField(2)
  final DateTime startDate;
  
  @HiveField(3)
  final DateTime? endDate;
  
  @HiveField(4)
  final bool isActive;
  
  @HiveField(5)
  final bool isCompleted;
  
  @HiveField(6)
  final int currentDay;
  
  @HiveField(7)
  final String? failureReason;
  
  @HiveField(8)
  final List<String>? failedChallenges;

  @HiveField(9)
  final String resetMode; // 'hard' or 'soft'

  @HiveField(10)
  final int totalDaysTarget; // 75 for hard, flexible for soft

  const ChallengeSession({
    required this.id,
    required this.challenges,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.isCompleted,
    required this.currentDay,
    this.failureReason,
    this.failedChallenges,
    this.resetMode = 'hard',
    this.totalDaysTarget = 75,
  });

  ResetMode get mode => resetMode == 'soft' ? ResetMode.soft : ResetMode.hard;

  ChallengeSession copyWith({
    String? id,
    List<Challenge>? challenges,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? isCompleted,
    int? currentDay,
    String? failureReason,
    List<String>? failedChallenges,
    String? resetMode,
    int? totalDaysTarget,
  }) {
    return ChallengeSession(
      id: id ?? this.id,
      challenges: challenges ?? this.challenges,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      currentDay: currentDay ?? this.currentDay,
      failureReason: failureReason ?? this.failureReason,
      failedChallenges: failedChallenges ?? this.failedChallenges,
      resetMode: resetMode ?? this.resetMode,
      totalDaysTarget: totalDaysTarget ?? this.totalDaysTarget,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenges': challenges.map((c) => c.toJson()).toList(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isActive': isActive,
    'isCompleted': isCompleted,
    'currentDay': currentDay,
    'failureReason': failureReason,
    'failedChallenges': failedChallenges,
    'resetMode': resetMode,
    'totalDaysTarget': totalDaysTarget,
  };

  factory ChallengeSession.fromJson(Map<String, dynamic> json) {
    return ChallengeSession(
      id: json['id'] as String,
      challenges: (json['challenges'] as List).map((c) => Challenge.fromJson(c as Map<String, dynamic>)).toList(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isActive: json['isActive'] as bool,
      isCompleted: json['isCompleted'] as bool,
      currentDay: json['currentDay'] as int,
      failureReason: json['failureReason'] as String?,
      failedChallenges: (json['failedChallenges'] as List?)?.cast<String>(),
      resetMode: json['resetMode'] as String? ?? 'hard',
      totalDaysTarget: json['totalDaysTarget'] as int? ?? 75,
    );
  }

  @override
  List<Object?> get props => [
    id, challenges, startDate, endDate, isActive, 
    isCompleted, currentDay, failureReason, failedChallenges,
    resetMode, totalDaysTarget
  ];
}
