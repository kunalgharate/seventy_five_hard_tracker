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

  /// API-Ninjas key — inject via `--dart-define=API_NINJAS_KEY=<value>`
  /// at build time, or replace the fallback string for local development.
  static const String apiNinjasKey = String.fromEnvironment(
    'API_NINJAS_KEY',
    defaultValue: 'HzzXv9PYL0eEgXwPF9aTC2hZUQKgZpWumHx4rvbZ',
  );

  // NOTE: The `category` query param requires a premium API-Ninjas subscription.
  // The free tier returns a random quote from any category, which works fine.

  /// HTTP timeout for quote requests
  static const Duration quoteRequestTimeout = Duration(seconds: 6);
}
