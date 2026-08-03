import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/presentation/bloc/discipline_score_bloc.dart';
import 'package:seventy_five_hard_tracker/features/discipline_score/presentation/bloc/discipline_score_state.dart';
import 'package:seventy_five_hard_tracker/features/ai_accountability/data/services/gemini_service.dart';

/// AI Accountability screen — Gemini-powered coach.
class AiCompanionScreen extends StatefulWidget {
  /// Optional task name to focus on. If null, gives a general daily message.
  final String? taskName;
  final bool? taskCompleted;

  const AiCompanionScreen({
    super.key,
    this.taskName,
    this.taskCompleted,
  });

  @override
  State<AiCompanionScreen> createState() => _AiCompanionScreenState();
}

class _AiCompanionScreenState extends State<AiCompanionScreen> {
  final _gemini = GeminiService();
  final _chatCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadInitialMessage();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessage() async {
    final challengeState = context.read<ChallengeBloc>().state;
    final scoreState = context.read<DisciplineScoreBloc>().state;

    int currentDay = 1;
    int currentStreak = 0;
    int completedToday = 0;
    int totalToday = 0;
    double disciplineScore = 0;
    String grade = 'F';

    if (challengeState is ChallengeLoaded && challengeState.hasActiveSession) {
      final session = challengeState.activeSession!;
      currentDay = session.currentDay;
      final today = DateTime.now();
      final todayProgress = challengeState.currentProgress
          .where((p) =>
              p.date.year == today.year &&
              p.date.month == today.month &&
              p.date.day == today.day)
          .firstOrNull;
      totalToday =
          session.challenges.where((c) => c.taskType != 'regular').length;
      completedToday = todayProgress?.challengeCompletions.values
              .where((v) => v == true)
              .length ??
          0;
    }

    if (scoreState is DisciplineScoreLoaded) {
      currentStreak = scoreState.currentStreak;
      disciplineScore = scoreState.disciplineScore;
      grade = scoreState.grade;
    }

    GeminiResponse response;

    if (widget.taskName != null) {
      response = await _gemini.getTaskAccountabilityMessage(
        taskName: widget.taskName!,
        isCompleted: widget.taskCompleted ?? false,
        currentStreak: currentStreak,
        currentDay: currentDay,
        completedToday: completedToday,
        totalToday: totalToday,
      );
    } else {
      response = await _gemini.getDailyMotivation(
        currentDay: currentDay,
        currentStreak: currentStreak,
        disciplineScore: disciplineScore,
        grade: grade,
      );
    }

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(text: response.text, isAi: true));
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;

    _chatCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isAi: false));
      _sending = true;
    });

    final challengeState = context.read<ChallengeBloc>().state;
    int currentDay = 1;
    int currentStreak = 0;
    if (challengeState is ChallengeLoaded && challengeState.hasActiveSession) {
      currentDay = challengeState.activeSession!.currentDay;
    }
    final scoreState = context.read<DisciplineScoreBloc>().state;
    if (scoreState is DisciplineScoreLoaded) {
      currentStreak = scoreState.currentStreak;
    }

    final prompt = '''
You are an AI accountability coach for the 75 Hard Challenge.
The user is on Day $currentDay with a $currentStreak day streak.
${widget.taskName != null ? 'They are working on task: "${widget.taskName}".' : ''}

User message: "$text"

Respond as a supportive but firm coach. Keep it under 60 words.
''';

    final response = await _gemini.generate(prompt);

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(text: response.text, isAi: true));
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.taskName != null
            ? 'AI Coach: ${widget.taskName}'
            : 'AI Accountability Coach',
      ),
      body: Column(
        children: [
          // Header card
          if (widget.taskName != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Accountability',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Monitoring: ${widget.taskName}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (widget.taskCompleted ?? false)
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (widget.taskCompleted ?? false) ? 'Done ✓' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (widget.taskCompleted ?? false)
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text('AI is analyzing your progress...',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),

          // Input
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask your AI coach...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _sending ? Colors.grey[300] : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAi;
  _ChatMessage({required this.text, required this.isAi});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment:
              message.isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (message.isAi)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 3),
                child: Text('🤖 AI Coach',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isAi ? Colors.grey[100] : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isAi ? 4 : 16),
                  bottomRight: Radius.circular(message.isAi ? 16 : 4),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: message.isAi ? Colors.black87 : Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
