import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class QuotesService {
  static final QuotesService _instance = QuotesService._internal();
  factory QuotesService() => _instance;
  QuotesService._internal();

  final List<String> _offlineQuotes = [
    "The only way to do great work is to love what you do. - Steve Jobs",
    "Life is what happens to you while you're busy making other plans. - John Lennon",
    "The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt",
    "It is during our darkest moments that we must focus to see the light. - Aristotle",
    "The only impossible journey is the one you never begin. - Tony Robbins",
    "Success is not final, failure is not fatal: it is the courage to continue that counts. - Winston Churchill",
    "The way to get started is to quit talking and begin doing. - Walt Disney",
    "Your time is limited, so don't waste it living someone else's life. - Steve Jobs",
    "If life were predictable it would cease to be life, and be without flavor. - Eleanor Roosevelt",
    "If you look at what you have in life, you'll always have more. - Oprah Winfrey",
    "Believe you can and you're halfway there. - Theodore Roosevelt",
    "The only person you are destined to become is the person you decide to be. - Ralph Waldo Emerson",
    "Go confidently in the direction of your dreams. Live the life you have imagined. - Henry David Thoreau",
    "When you reach the end of your rope, tie a knot in it and hang on. - Franklin D. Roosevelt",
    "Don't judge each day by the harvest you reap but by the seeds that you plant. - Robert Louis Stevenson",
    "The best time to plant a tree was 20 years ago. The second best time is now. - Chinese Proverb",
    "An unexamined life is not worth living. - Socrates",
    "Eighty percent of success is showing up. - Woody Allen",
    "Your life does not get better by chance, it gets better by change. - Jim Rohn",
    "People who are unable to motivate themselves must be content with mediocrity. - Andrew Carnegie",
    "Design your life to include more of what you want to be doing. - Unknown",
    "You are never too old to set another goal or to dream a new dream. - C.S. Lewis",
    "Try to be a rainbow in someone's cloud. - Maya Angelou",
    "You do not find the happy life. You make it. - Camilla Eyring Kimball",
    "Inspiration comes from within yourself. One has to be positive. - Pearl Bailey",
    "Sometimes you will never know the value of a moment until it becomes a memory. - Dr. Seuss",
    "The most wasted of days is one without laughter. - E.E. Cummings",
    "You must be the change you wish to see in the world. - Mahatma Gandhi",
    "Simplicity is the ultimate sophistication. - Leonardo da Vinci",
    "Yesterday is history, tomorrow is a mystery, today is a gift. - Eleanor Roosevelt",
  ];

  Future<String> getMotivationalQuote() async {
    try {
      // Try to fetch from API first
      final response = await http.get(
        Uri.parse('https://type.fit/api/quotes'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> quotes = json.decode(response.body);
        if (quotes.isNotEmpty) {
          final randomQuote = quotes[Random().nextInt(quotes.length)];
          final text = randomQuote['text'] ?? '';
          final author = randomQuote['author'] ?? 'Unknown';
          return '$text - $author';
        }
      }
    } catch (e) {
      // If API fails, fall back to offline quotes
      // print('Failed to fetch online quote: $e');
    }

    // Return random offline quote
    return _offlineQuotes[Random().nextInt(_offlineQuotes.length)];
  }

  String getRandomOfflineQuote() {
    return _offlineQuotes[Random().nextInt(_offlineQuotes.length)];
  }

  List<String> getAllOfflineQuotes() {
    return List.from(_offlineQuotes);
  }
}
