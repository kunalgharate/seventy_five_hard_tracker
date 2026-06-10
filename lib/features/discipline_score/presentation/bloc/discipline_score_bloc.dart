import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/discipline_score_repository.dart';
import 'discipline_score_event.dart';
import 'discipline_score_state.dart';

class DisciplineScoreBloc
    extends Bloc<DisciplineScoreEvent, DisciplineScoreState> {
  final DisciplineScoreRepository _repository;

  DisciplineScoreBloc({DisciplineScoreRepository? repository})
      : _repository = repository ?? const DisciplineScoreRepository(),
        super(DisciplineScoreInitial()) {
    on<CalculateDisciplineScore>(_onCalculate);
    on<ResetDisciplineScore>(_onReset);
  }

  void _onCalculate(
    CalculateDisciplineScore event,
    Emitter<DisciplineScoreState> emit,
  ) {
    try {
      final score = _repository.getScore(
        session: event.session,
        progress: event.progress,
      );
      emit(DisciplineScoreLoaded(score));
      if (kDebugMode) {
        debugPrint(
          '[DisciplineScoreBloc] score=${score.disciplineScore.toStringAsFixed(1)} '
          'streak=${score.currentStreak} '
          'weekly=${score.weeklyConsistency.toStringAsFixed(0)}% '
          'grade=${score.grade}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DisciplineScoreBloc] error: $e');
      emit(DisciplineScoreError('Failed to calculate discipline score: $e'));
    }
  }

  void _onReset(
    ResetDisciplineScore event,
    Emitter<DisciplineScoreState> emit,
  ) {
    emit(DisciplineScoreInitial());
  }
}
