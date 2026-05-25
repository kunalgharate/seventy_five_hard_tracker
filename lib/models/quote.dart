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
  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      quote: (json['quote'] as String? ?? '').trim(),
      author: (json['author'] as String? ?? 'Unknown').trim(),
      category: (json['category'] as String? ?? '').trim(),
    );
  }

  /// Parse the first element of the API response list.
  /// Returns `null` if the list is empty or malformed.
  static Quote? fromApiResponse(dynamic responseBody) {
    if (responseBody is! List || responseBody.isEmpty) return null;
    final first = responseBody.first;
    if (first is! Map<String, dynamic>) return null;
    return Quote.fromJson(first);
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
