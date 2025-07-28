import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';
import 'challenge.dart';

part 'challenge_session.g.dart';

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
  });

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
    );
  }

  @override
  List<Object?> get props => [
    id, challenges, startDate, endDate, isActive, 
    isCompleted, currentDay, failureReason, failedChallenges
  ];
}
