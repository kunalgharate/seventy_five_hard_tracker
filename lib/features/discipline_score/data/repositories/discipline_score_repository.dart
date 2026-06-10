import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import '../../domain/models/discipline_score_model.dart';
import '../../domain/services/discipline_score_service.dart';

/// Repository that bridges raw Hive data with the calculation service.
/// Keeps the BLoC thin — all logic lives in [DisciplineScoreService].
class DisciplineScoreRepository {
  const DisciplineScoreRepository();

  final _service = const DisciplineScoreService();

  /// Compute and return the discipline score for the given session + progress.
  /// Returns [DisciplineScoreModel.empty] if there is no active session.
  DisciplineScoreModel getScore({
    ChallengeSession? session,
    List<DailyProgress>? progress,
  }) {
    if (session == null || progress == null || progress.isEmpty) {
      return DisciplineScoreModel.empty;
    }
    return _service.calculate(session: session, progress: progress);
  }
}
