import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';

/// Resolves true once the bloc emits a loaded/error state after a journal
/// write event — false on timeout so the UI never spins forever.

Future<bool> awaitJournalWrite(ChallengeBloc bloc) async {
  try {
    final state = await bloc.stream
        .firstWhere((s) => s is ChallengeLoaded || s is ChallengeError)
        .timeout(const Duration(seconds: 4));
    return state is ChallengeLoaded;
  } catch (_) {
    return false;
  }
}
