// AI Companion State
import '../../data/models/ai_message_model.dart';

abstract class AICompanionState {}

class AICompanionInitial extends AICompanionState {}

class AICompanionLoading extends AICompanionState {}

class AICompanionLoaded extends AICompanionState {
  final AIMessage message;

  AICompanionLoaded(this.message);
}

class AICompanionError extends AICompanionState {
  final String error;

  AICompanionError(this.error);
}
