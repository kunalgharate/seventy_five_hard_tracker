import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ChallengeIconService {
  static final Map<String, List<ChallengeIconData>> categoryIcons = {
    'fitness': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.dumbbell,
        name: 'dumbbell',
        color: Colors.orange,
        keywords: ['workout', 'gym', 'exercise', 'strength', 'weights'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.personRunning,
        name: 'running',
        color: Colors.blue,
        keywords: ['run', 'jog', 'cardio', 'marathon'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.personWalking,
        name: 'walking',
        color: Colors.green,
        keywords: ['walk', 'steps', 'hiking'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.personSwimming,
        name: 'swimming',
        color: Colors.cyan,
        keywords: ['swim', 'pool', 'water'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.personBiking,
        name: 'cycling',
        color: Colors.teal,
        keywords: ['bike', 'cycle', 'bicycle'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.heart,
        name: 'cardio',
        color: Colors.red,
        keywords: ['cardio', 'heart', 'fitness'],
      ),
    ],
    'health': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.droplet,
        name: 'water',
        color: Colors.blue,
        keywords: ['water', 'drink', 'hydrate', 'liquid'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.pills,
        name: 'medicine',
        color: Colors.green,
        keywords: ['medicine', 'pills', 'vitamins', 'supplements'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.bed,
        name: 'sleep',
        color: Colors.indigo,
        keywords: ['sleep', 'rest', 'bed', 'nap'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.spa,
        name: 'meditation',
        color: Colors.purple,
        keywords: ['meditate', 'mindfulness', 'zen', 'calm'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.appleWhole,
        name: 'healthy_food',
        color: Colors.green,
        keywords: ['eat', 'food', 'healthy', 'nutrition', 'apple'],
      ),
    ],
    'learning': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.book,
        name: 'reading',
        color: Colors.brown,
        keywords: ['read', 'book', 'study', 'learn'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.graduationCap,
        name: 'study',
        color: Colors.blue,
        keywords: ['study', 'learn', 'education', 'course'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.language,
        name: 'language',
        color: Colors.orange,
        keywords: ['language', 'speak', 'translate', 'foreign'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.code,
        name: 'coding',
        color: Colors.green,
        keywords: ['code', 'programming', 'develop', 'software'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.pen,
        name: 'writing',
        color: Colors.purple,
        keywords: ['write', 'journal', 'diary', 'blog'],
      ),
    ],
    'productivity': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.listCheck,
        name: 'tasks',
        color: Colors.blue,
        keywords: ['task', 'todo', 'checklist', 'organize'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.clock,
        name: 'time',
        color: Colors.orange,
        keywords: ['time', 'schedule', 'punctual', 'early'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.briefcase,
        name: 'work',
        color: Colors.grey,
        keywords: ['work', 'job', 'career', 'business'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.bullseye,
        name: 'goal',
        color: Colors.red,
        keywords: ['goal', 'target', 'achieve', 'focus'],
      ),
    ],
    'lifestyle': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.broom,
        name: 'cleaning',
        color: Colors.teal,
        keywords: ['clean', 'tidy', 'organize', 'house'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.utensils,
        name: 'cooking',
        color: Colors.orange,
        keywords: ['cook', 'meal', 'kitchen', 'recipe'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.seedling,
        name: 'gardening',
        color: Colors.green,
        keywords: ['garden', 'plant', 'grow', 'nature'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.handHoldingHeart,
        name: 'kindness',
        color: Colors.pink,
        keywords: ['kind', 'help', 'charity', 'volunteer'],
      ),
    ],
    'social': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.userGroup,
        name: 'friends',
        color: Colors.blue,
        keywords: ['friends', 'social', 'people', 'connect'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.phone,
        name: 'call',
        color: Colors.green,
        keywords: ['call', 'phone', 'contact', 'family'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.envelope,
        name: 'message',
        color: Colors.orange,
        keywords: ['message', 'text', 'email', 'communicate'],
      ),
    ],
    'general': [
      const ChallengeIconData(
        icon: FontAwesomeIcons.star,
        name: 'star',
        color: Colors.amber,
        keywords: ['star', 'favorite', 'important', 'special'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.fire,
        name: 'fire',
        color: Colors.red,
        keywords: ['fire', 'hot', 'energy', 'passion'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.bolt,
        name: 'lightning',
        color: Colors.yellow,
        keywords: ['lightning', 'energy', 'power', 'fast'],
      ),
      const ChallengeIconData(
        icon: FontAwesomeIcons.gem,
        name: 'gem',
        color: Colors.purple,
        keywords: ['gem', 'diamond', 'precious', 'valuable'],
      ),
    ],
  };

  static ChallengeIconData? findBestIcon(String challengeTitle) {
    final title = challengeTitle.toLowerCase();

    // Search through all categories for matching keywords
    for (final category in categoryIcons.values) {
      for (final iconData in category) {
        for (final keyword in iconData.keywords) {
          if (title.contains(keyword)) {
            return iconData;
          }
        }
      }
    }

    // Return default icon if no match found
    return categoryIcons['general']?.first;
  }

  static List<ChallengeIconData> getAllIcons() {
    final List<ChallengeIconData> allIcons = [];
    for (final category in categoryIcons.values) {
      allIcons.addAll(category);
    }
    return allIcons;
  }

  static List<ChallengeIconData> getIconsByCategory(String category) {
    return categoryIcons[category] ?? [];
  }

  static List<String> getCategories() {
    return categoryIcons.keys.toList();
  }
}

class ChallengeIconData {
  final FaIconData icon;
  final String name;
  final Color color;
  final List<String> keywords;

  const ChallengeIconData({
    required this.icon,
    required this.name,
    required this.color,
    required this.keywords,
  });
}
