import 'package:equatable/equatable.dart';
import '../../domain/models/discipline_score_model.dart';

abstract class DisciplineScoreState extends Equatable {
  const DisciplineScoreState();

  @override
  List<Object?> get props => [];
}

class DisciplineScoreInitial extends DisciplineScoreState {}

class DisciplineScoreLoading extends DisciplineScoreState {}

class DisciplineScoreLoaded extends DisciplineScoreState {
  final DisciplineScoreModel score;

  const DisciplineScoreLoaded(this.score);

  // Convenience getters so widgets don't need to import the model directly.
  double get disciplineScore => score.disciplineScore;
  int get currentStreak => score.currentStreak;
  int get longestStreak => score.longestStreak;
  double get weeklyConsistency => score.weeklyConsistency;
  double get monthlyConsistency => score.monthlyConsistency;
  double get completionRate => score.completionRate;
  String get grade => score.grade;
  String get tier => score.tier;
  int get currentWarnings => score.currentWarnings;
  int get streakBreaks => score.streakBreaks;
  bool get hasActiveWarnings => score.hasActiveWarnings;
  bool get onFinalWarning => score.onFinalWarning;
  String get warningLabel => score.warningLabel;

  @override
  List<Object?> get props => [score];
}

class DisciplineScoreError extends DisciplineScoreState {
  final String message;

  const DisciplineScoreError(this.message);

  @override
  List<Object> get props => [message];
}
