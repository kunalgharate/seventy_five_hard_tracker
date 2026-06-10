/// Centralised API configuration.
///
/// In a production app you would load these from a build-time
/// `--dart-define` flag or a secrets manager so the key is never
/// committed to source control.  For now they live here as named
/// constants so every call site has a single place to update.
class ApiConstants {
  ApiConstants._(); // prevent instantiation

  /// API-Ninjas quotes endpoint (plural — /quote returns 404)
  static const String quotesEndpoint = 'https://api.api-ninjas.com/v1/quotes';

  /// API-Ninjas key
  static const String apiNinjasKey = String.fromEnvironment(
    'API_NINJAS_KEY',
    defaultValue: 'HzzXv9PYL0eEgXwPF9aTC2hZUQKgZpWumHx4rvbZ',
  );

  // NOTE: The `category` query param requires a premium API-Ninjas subscription.

  /// HTTP timeout for quote requests
  static const Duration quoteRequestTimeout = Duration(seconds: 6);

  // ── Gemini AI ──────────────────────────────────────────────────

  /// Gemini API key
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6J3arJ8kmRH3qJr1UnzMmMTRbIMcBBNEC1mMzfAqXfQNg',
  );

  /// Gemini model — use gemini-2.5-flash as primary
  static const String geminiModel = 'gemini-2.5-flash';

  /// Gemini base URL
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1/models';
}
