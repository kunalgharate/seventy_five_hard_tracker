import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/quote.dart';

/// Result wrapper so callers can distinguish success from failure
/// without relying on exceptions.
sealed class QuoteResult {
  const QuoteResult();
}

final class QuoteSuccess extends QuoteResult {
  final Quote quote;
  const QuoteSuccess(this.quote);
}

final class QuoteFailure extends QuoteResult {
  final String message;
  const QuoteFailure(this.message);
}

/// Service that fetches a motivational quote from the API-Ninjas
/// `/v1/quote` endpoint.
///
/// Falls back to a curated offline list when the network is
/// unavailable or the API returns an error.
class ApiNinjasQuoteService {
  // Singleton — one HTTP client shared across the app lifetime.
  static final ApiNinjasQuoteService _instance =
      ApiNinjasQuoteService._internal();
  factory ApiNinjasQuoteService() => _instance;
  ApiNinjasQuoteService._internal();

  // ── Offline fallback quotes ──────────────────────────────────────

  static const List<Quote> _fallbackQuotes = [
    Quote(
      quote: 'The only way to do great work is to love what you do.',
      author: 'Steve Jobs',
      category: 'inspirational',
    ),
    Quote(
      quote: 'Believe you can and you\'re halfway there.',
      author: 'Theodore Roosevelt',
      category: 'inspirational',
    ),
    Quote(
      quote: 'It does not matter how slowly you go as long as you do not stop.',
      author: 'Confucius',
      category: 'inspirational',
    ),
    Quote(
      quote: 'Everything you\'ve ever wanted is on the other side of fear.',
      author: 'George Addair',
      category: 'inspirational',
    ),
    Quote(
      quote:
          'Success is not final, failure is not fatal: it is the courage to continue that counts.',
      author: 'Winston Churchill',
      category: 'inspirational',
    ),
    Quote(
      quote:
          'Hardships often prepare ordinary people for an extraordinary destiny.',
      author: 'C.S. Lewis',
      category: 'inspirational',
    ),
    Quote(
      quote:
          'You are never too old to set another goal or to dream a new dream.',
      author: 'C.S. Lewis',
      category: 'inspirational',
    ),
    Quote(
      quote: 'The secret of getting ahead is getting started.',
      author: 'Mark Twain',
      category: 'inspirational',
    ),
    Quote(
      quote: 'Don\'t watch the clock; do what it does. Keep going.',
      author: 'Sam Levenson',
      category: 'inspirational',
    ),
    Quote(
      quote: 'Keep your eyes on the stars, and your feet on the ground.',
      author: 'Theodore Roosevelt',
      category: 'inspirational',
    ),
  ];

  // ── Public API ───────────────────────────────────────────────────

  /// Fetches a fresh quote from API-Ninjas.
  ///
  /// Returns [QuoteSuccess] on success, [QuoteFailure] on any error.
  /// Never throws.
  Future<QuoteResult> fetchQuote() async {
    try {
      final uri = Uri.parse(ApiConstants.quotesEndpoint);

      final response = await http.get(
        uri,
        headers: {'X-Api-Key': ApiConstants.apiNinjasKey},
      ).timeout(ApiConstants.quoteRequestTimeout);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final quote = Quote.fromApiResponse(decoded);
        if (quote != null && quote.quote.isNotEmpty) {
          return QuoteSuccess(quote);
        }
        return const QuoteFailure('Empty response from API');
      }

      if (kDebugMode) {
        debugPrint(
          '[ApiNinjasQuoteService] HTTP ${response.statusCode}: ${response.body}',
        );
      }
      return QuoteFailure('API error ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiNinjasQuoteService] Error: $e');
      return QuoteFailure(e.toString());
    }
  }

  /// Returns a random offline fallback quote.
  Quote get randomFallback {
    final index =
        DateTime.now().millisecondsSinceEpoch % _fallbackQuotes.length;
    return _fallbackQuotes[index];
  }

  /// Convenience: always returns a [Quote], using the fallback on failure.
  Future<Quote> fetchQuoteOrFallback() async {
    final result = await fetchQuote();
    return switch (result) {
      QuoteSuccess(:final quote) => quote,
      QuoteFailure() => randomFallback,
    };
  }
}
