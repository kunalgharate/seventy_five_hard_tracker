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

  /// API-Ninjas key — supply via --dart-define=API_NINJAS_KEY=your_key
  static const String apiNinjasKey = String.fromEnvironment(
    'API_NINJAS_KEY',
    defaultValue: '',
  );

  // NOTE: The `category` query param requires a premium API-Ninjas subscription.

  /// HTTP timeout for quote requests
  static const Duration quoteRequestTimeout = Duration(seconds: 6);

  // ── Gemini AI ──────────────────────────────────────────────────

  /// Gemini API key — supply via --dart-define=GEMINI_API_KEY=your_key
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Gemini model — use gemini-2.5-flash as primary
  static const String geminiModel = 'gemini-2.5-flash';

  /// Gemini base URL
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1/models';
}
