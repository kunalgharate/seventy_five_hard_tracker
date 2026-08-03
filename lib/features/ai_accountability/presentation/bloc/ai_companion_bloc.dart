// AI Companion BLoC — placeholder
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/ai_companion_service.dart';
import 'ai_companion_event.dart';
import 'ai_companion_state.dart';

class AICompanionBloc extends Bloc<AICompanionEvent, AICompanionState> {
  final AICompanionService service;

  AICompanionBloc(this.service) : super(AICompanionInitial()) {
    on<LoadAIMessage>(_onLoadMessage);
  }

  Future<void> _onLoadMessage(
    LoadAIMessage event,
    Emitter<AICompanionState> emit,
  ) async {
    emit(AICompanionLoading());

    try {
      final message = service.generateMessage(
        completedTasks: event.completedTasks,
        totalTasks: event.totalTasks,
        streak: event.streak,
      );

      emit(AICompanionLoaded(message));
    } catch (e) {
      emit(AICompanionError(e.toString()));
    }
  }
}
