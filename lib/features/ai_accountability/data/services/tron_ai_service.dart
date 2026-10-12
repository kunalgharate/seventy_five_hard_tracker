import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Result of a Tron AI polish call.
class TronAiResponse {
  final String text;
  final bool isError;
  const TronAiResponse({required this.text, this.isError = false});
}

/// "Tron AI" — cleans up dictated journal text. The NVIDIA API key lives
/// server-side in the `polishDictation` Cloud Function (functions/index.js),
/// so this client only invokes the callable — no key ships in the app.
/// Keeps the speaker's language (Marathi, Hindi, English, …): fixes
/// grammar/punctuation only, never translates, never adds content.
class TronAiService {
  static final TronAiService _instance = TronAiService._internal();
  factory TronAiService() => _instance;
  TronAiService._internal();

  static const Duration _timeout = Duration(seconds: 30);

  /// Whether Tron AI is reachable (requires a signed-in user, since the
  /// callable enforces auth).
  bool get isConfigured => FirebaseAuth.instance.currentUser != null;

  /// Polish raw dictation [text]. Returns the cleaned text, or a
  /// [TronAiResponse] with isError=true and a human-readable message.
  Future<TronAiResponse> polishDictation(String text) async {
    if (!isConfigured) {
      return const TronAiResponse(
        text: 'Sign in to use Tron AI.',
        isError: true,
      );
    }
    if (text.trim().isEmpty) {
      return const TronAiResponse(text: '', isError: true);
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final callable =
            FirebaseFunctions.instance.httpsCallable('polishDictation');
        final result =
            await callable.call(<String, dynamic>{'text': text}).timeout(
          _timeout,
        );
        final data = result.data;
        if (data is Map) {
          final polished = data['text'];
          if (polished is String && polished.trim().isNotEmpty) {
            return TronAiResponse(text: polished.trim());
          }
        }
        return const TronAiResponse(
            text: 'Tron AI returned an empty reply.', isError: true);
      } on FirebaseFunctionsException catch (e) {
        if (kDebugMode) debugPrint('[TronAiService] ${e.code}: ${e.message}');
        // Retry once on transient overload.
        if ((e.code == 'unavailable' || e.code == 'internal') && attempt == 0) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return TronAiResponse(
            text: _messageForCode(e.code, e.message), isError: true);
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

  String _messageForCode(String code, String? message) {
    switch (code) {
      case 'unauthenticated':
        return 'Sign in to use Tron AI.';
      case 'invalid-argument':
        return message ?? 'Tron AI could not polish that text.';
      case 'resource-exhausted':
        return message ?? 'Tron AI is busy. Try again shortly.';
      case 'failed-precondition':
        return 'Tron AI is not configured yet.';
      default:
        return 'Tron AI unavailable.';
    }
  }
}
