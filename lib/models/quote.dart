import 'package:equatable/equatable.dart';

/// Represents a single motivational quote returned by the API-Ninjas
/// `/v1/quote` endpoint.
///
/// Example JSON:
/// ```json
/// [
///   {
///     "quote": "The only way to do great work is to love what you do.",
///     "author": "Steve Jobs",
///     "category": "inspirational"
///   }
/// ]
/// ```
class Quote extends Equatable {
  final String quote;
  final String author;
  final String category;

  const Quote({
    required this.quote,
    required this.author,
    required this.category,
  });

  /// Parse a single quote object from the JSON map.
  /// Returns a Quote with defaults for missing fields; malformed non-string
  /// values are treated as absent rather than throwing a cast error.
  factory Quote.fromJson(Map<String, dynamic> json) {
    // Support both original format and ZenQuotes format ('q'/'a')
    final rawQ = json['q'] ?? json['quote'];
    final rawA = json['a'] ?? json['author'];
    final rawC = json['category'];

    final q = rawQ is String ? rawQ.trim() : '';
    final a = rawA is String ? rawA.trim() : 'Unknown';
    final c = rawC is String ? rawC.trim() : 'inspirational';

    return Quote(quote: q, author: a, category: c);
  }

  /// Parse the first element of the API response list.
  /// Returns `null` if the list is empty, malformed, or the first entry
  /// yields an empty quote string.
  static Quote? fromApiResponse(dynamic responseBody) {
    if (responseBody is! List || responseBody.isEmpty) return null;
    final first = responseBody.first;
    if (first is! Map<String, dynamic>) return null;
    final quote = Quote.fromJson(first);
    if (quote.quote.isEmpty) return null;
    return quote;
  }

  Map<String, dynamic> toJson() => {
        'quote': quote,
        'author': author,
        'category': category,
      };

  /// Formatted display string: `"<quote>" — <author>`
  String get formatted => '"$quote"\n— $author';

  @override
  List<Object?> get props => [quote, author, category];
}
