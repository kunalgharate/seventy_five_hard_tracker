import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class QuotesService {
  static final QuotesService _instance = QuotesService._internal();
  factory QuotesService() => _instance;
  QuotesService._internal();

  static const _offlineQuotes = [
    "The only way to do great work is to love what you do. - Steve Jobs",
    "Life is what happens to you while you're busy making other plans. - John Lennon",
    "The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt",
    "It is during our darkest moments that we must focus to see the light. - Aristotle",
    "The only impossible journey is the one you never begin. - Tony Robbins",
    "Success is not final, failure is not fatal: it is the courage to continue that counts. - Winston Churchill",
    "The way to get started is to quit talking and begin doing. - Walt Disney",
    "Your time is limited, so don't waste it living someone else's life. - Steve Jobs",
    "Believe you can and you're halfway there. - Theodore Roosevelt",
    "The best time to plant a tree was 20 years ago. The second best time is now. - Chinese Proverb",
    "You must be the change you wish to see in the world. - Mahatma Gandhi",
    "Yesterday is history, tomorrow is a mystery, today is a gift. - Eleanor Roosevelt",
    "Don't judge each day by the harvest you reap but by the seeds that you plant. - Robert Louis Stevenson",
    "You are never too old to set another goal or to dream a new dream. - C.S. Lewis",
    "Simplicity is the ultimate sophistication. - Leonardo da Vinci",
  ];

  Future<String> getMotivationalQuote() async {
    try {
      final response = await http
          .get(Uri.parse('https://zenquotes.io/api/random'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return '${data[0]['q']} - ${data[0]['a']}';
        }
      }
    } catch (_) {}

    return getRandomOfflineQuote();
  }

  String getRandomOfflineQuote() {
    return _offlineQuotes[Random().nextInt(_offlineQuotes.length)];
  }

  List<String> getAllOfflineQuotes() => List.from(_offlineQuotes);
}
