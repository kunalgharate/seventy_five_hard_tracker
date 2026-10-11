import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:seventy_five_hard_tracker/core/constants/api_constants.dart';

/// Result of a Tron AI polish call.
class TronAiResponse {
  final String text;
  final bool isError;
  const TronAiResponse({required this.text, this.isError = false});
}

/// "Tron AI" — cleans up dictated journal text via NVIDIA's
/// OpenAI-compatible chat API. Keeps the speaker's language
/// (Marathi, Hindi, English, …): fixes grammar/punctuation only,
/// never translates, never adds content.
class TronAiService {
  static final TronAiService _instance = TronAiService._internal();
  factory TronAiService() => _instance;
  TronAiService._internal();

  static const Duration _timeout = Duration(seconds: 25);

  /// Whether Tron AI is configured (API key supplied via --dart-define).
  bool get isConfigured => ApiConstants.tronApiKey.isNotEmpty;

  /// Polish raw dictation [text]. Returns the cleaned text, or a
  /// [TronAiResponse] with isError=true and a human-readable message.
  Future<TronAiResponse> polishDictation(String text) async {
    if (!isConfigured) {
      return const TronAiResponse(
        text: 'Tron AI is not configured (missing API key).',
        isError: true,
      );
    }
    if (text.trim().isEmpty) {
      return const TronAiResponse(text: '', isError: true);
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final url = Uri.parse('${ApiConstants.tronBaseUrl}/chat/completions');
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${ApiConstants.tronApiKey}',
              },
              body: jsonEncode({
                'model': ApiConstants.tronModel,
                'temperature': 0.2,
                'max_tokens': 1500,
                'messages': [
                  {
                    'role': 'system',
                    'content': 'You clean up dictated journal entries. '
                        'Fix grammar, punctuation and obvious speech-recognition mistakes. '
                        'Keep the EXACT same language the user spoke (Marathi stays Marathi, '
                        'Hindi stays Hindi, English stays English) — never translate. '
                        'Do not add new ideas, advice or commentary. '
                        'Reply with ONLY the cleaned text, nothing else.',
                  },
                  {'role': 'user', 'content': text},
                ],
              }),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'];
          String? content;
          String? finishReason;
          if (choices is List && choices.isNotEmpty) {
            final first = choices[0];
            if (first is Map) {
              final finish = first['finish_reason'];
              if (finish is String) finishReason = finish;
              final message = first['message'];
              if (message is Map) {
                final c = message['content'];
                if (c is String) content = c;
              }
            }
          }
          if (finishReason != null && finishReason.toLowerCase() == 'length') {
            return const TronAiResponse(
              text: 'Text too long for Tron AI to polish — try shortening it.',
              isError: true,
            );
          }
          if (content != null && content.trim().isNotEmpty) {
            return TronAiResponse(text: content.trim());
          }
          return const TronAiResponse(
              text: 'Tron AI returned an empty reply.', isError: true);
        }

        // Retry once on rate-limit/overload
        if ((response.statusCode == 429 || response.statusCode == 503) &&
            attempt == 0) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        if (kDebugMode) {
          debugPrint(
              '[TronAiService] HTTP ${response.statusCode}: ${response.body}');
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          return const TronAiResponse(
              text: 'Tron AI key rejected. Check NVIDIA_API_KEY.',
              isError: true);
        }
        return TronAiResponse(
            text: 'Tron AI unavailable (${response.statusCode}).',
            isError: true);
      } catch (e) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        if (kDebugMode) debugPrint('[TronAiService] Error: $e');
        return const TronAiResponse(
            text: 'Could not reach Tron AI. Check your connection.',
            isError: true);
      }
    }
    return const TronAiResponse(
        text: 'Tron AI unavailable. Try again shortly.', isError: true);
  }
}
