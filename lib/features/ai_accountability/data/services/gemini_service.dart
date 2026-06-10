import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:seventy_five_hard_tracker/core/constants/api_constants.dart';

class GeminiResponse {
  final String text;
  final bool isError;
  const GeminiResponse({required this.text, this.isError = false});
}

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const Duration _timeout = Duration(seconds: 15);

  Future<GeminiResponse> generate(String prompt) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final url = Uri.parse(
          '${ApiConstants.geminiBaseUrl}/${ApiConstants.geminiModel}:generateContent'
          '?key=${ApiConstants.geminiApiKey}',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.7,
                  'maxOutputTokens': 300,
                },
              }),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
          if (text != null && text.isNotEmpty) {
            return GeminiResponse(text: text.trim());
          }
          return const GeminiResponse(
              text: 'No response from AI.', isError: true);
        }

        // Retry once on quota/overload
        if ((response.statusCode == 429 || response.statusCode == 503) &&
            attempt == 0) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        if (kDebugMode) {
          debugPrint(
              '[GeminiService] HTTP ${response.statusCode}: ${response.body}');
        }
        return GeminiResponse(
            text: 'AI unavailable (${response.statusCode})', isError: true);
      } catch (e) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        if (kDebugMode) debugPrint('[GeminiService] Error: $e');
        return const GeminiResponse(
            text: 'Could not reach AI. Check your connection.', isError: true);
      }
    }
    return const GeminiResponse(
        text: 'AI unavailable. Try again shortly.', isError: true);
  }

  Future<GeminiResponse> getTaskAccountabilityMessage({
    required String taskName,
    required bool isCompleted,
    required int currentStreak,
    required int currentDay,
    required int completedToday,
    required int totalToday,
  }) async {
    final status = isCompleted ? 'completed' : 'NOT completed';
    final prompt = '''
You are a strict but motivational accountability coach for the 75 Hard Challenge.
Task: "$taskName" — Status: $status
Streak: $currentStreak days. Day $currentDay of 75.
Tasks done today: $completedToday/$totalToday.
${isCompleted ? 'Give a short congratulatory message (1-2 sentences).' : 'Give a firm warning (1-2 sentences). Mention streak penalty.'}
Under 50 words. One relevant emoji at start.
''';
    return generate(prompt);
  }

  Future<GeminiResponse> getPenaltyWarning({
    required String taskName,
    required int minutesLeft,
    required int currentStreak,
  }) async {
    final prompt = '''
You are a strict accountability coach for the 75 Hard Challenge.
Task "$taskName" not done. $minutesLeft minutes left. Streak: $currentStreak days at risk.
Give an urgent 1-2 sentence warning. Under 40 words. Start with ⚠️.
''';
    return generate(prompt);
  }

  Future<GeminiResponse> getMissedTaskFollowUp({
    required String taskName,
    required int missedDays,
    required int currentStreak,
  }) async {
    final prompt = '''
Accountability coach for 75 Hard Challenge.
Task "$taskName" missed. Times missed: $missedDays. Streak: $currentStreak days.
Ask ONE direct follow-up question then give a short suggestion. Under 50 words. Start with ❓.
''';
    return generate(prompt);
  }

  Future<GeminiResponse> getDailyMotivation({
    required int currentDay,
    required int currentStreak,
    required double disciplineScore,
    required String grade,
  }) async {
    final prompt = '''
Motivational coach for 75 Hard Challenge.
Day $currentDay/75. Streak: $currentStreak days. Score: ${disciplineScore.toStringAsFixed(0)}/100 (Grade $grade).
Give a powerful 1-2 sentence motivational message. Under 40 words. One emoji at start.
''';
    return generate(prompt);
  }
}
