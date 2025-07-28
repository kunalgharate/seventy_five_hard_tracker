import 'dart:math';
import 'package:flutter/material.dart';

class DynamicColorService {
  static final List<Color> _vibrantColors = [
    // Blues
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    
    // Greens
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFF66BB6A),
    Color(0xFF26A69A),
    
    // Oranges & Reds
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    
    // Purples & Indigos
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF5C6BC0),
    Color(0xFF7986CB),
    
    // Warm colors
    Color(0xFFFF6F00),
    Color(0xFFFF8F00),
    Color(0xFFFFA000),
    Color(0xFFFFB300),
    
    // Cool colors
    Color(0xFF00ACC1),
    Color(0xFF0097A7),
    Color(0xFF00838F),
    Color(0xFF006064),
  ];

  static final List<LinearGradient> _gradients = [
    // Blue gradients
    LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF21CBF3)]),
    LinearGradient(colors: [Color(0xFF03A9F4), Color(0xFF0288D1)]),
    LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)]),
    
    // Green gradients
    LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
    LinearGradient(colors: [Color(0xFF8BC34A), Color(0xFF9CCC65)]),
    LinearGradient(colors: [Color(0xFF009688), Color(0xFF26A69A)]),
    
    // Orange/Red gradients
    LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
    LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF7043)]),
    LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFEC407A)]),
    
    // Purple gradients
    LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
    LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF9575CD)]),
    LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF7986CB)]),
    
    // Warm gradients
    LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)]),
    LinearGradient(colors: [Color(0xFFFFA000), Color(0xFFFFB300)]),
    
    // Cool gradients
    LinearGradient(colors: [Color(0xFF00ACC1), Color(0xFF26C6DA)]),
    LinearGradient(colors: [Color(0xFF0097A7), Color(0xFF00BCD4)]),
  ];

  /// Generate a vibrant color based on text hash
  static Color getColorForText(String text) {
    if (text.isEmpty) return _vibrantColors[0];
    
    final hash = text.toLowerCase().hashCode;
    final index = hash.abs() % _vibrantColors.length;
    return _vibrantColors[index];
  }

  /// Generate a gradient based on text hash
  static LinearGradient getGradientForText(String text) {
    if (text.isEmpty) return _gradients[0];
    
    final hash = text.toLowerCase().hashCode;
    final index = hash.abs() % _gradients.length;
    return _gradients[index];
  }

  /// Generate a color based on category
  static Color getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
      case 'workout':
      case 'exercise':
        return Color(0xFF4CAF50); // Green
      case 'nutrition':
      case 'diet':
      case 'food':
        return Color(0xFFFF9800); // Orange
      case 'water':
      case 'hydration':
        return Color(0xFF2196F3); // Blue
      case 'reading':
      case 'book':
      case 'study':
        return Color(0xFF673AB7); // Purple
      case 'meditation':
      case 'mindfulness':
        return Color(0xFF9C27B0); // Pink
      case 'sleep':
      case 'rest':
        return Color(0xFF3F51B5); // Indigo
      case 'work':
      case 'productivity':
        return Color(0xFF795548); // Brown
      default:
        return getColorForText(category);
    }
  }

  /// Generate a random vibrant color
  static Color getRandomColor() {
    final random = Random();
    return _vibrantColors[random.nextInt(_vibrantColors.length)];
  }

  /// Generate a random gradient
  static LinearGradient getRandomGradient() {
    final random = Random();
    return _gradients[random.nextInt(_gradients.length)];
  }

  /// Get complementary color for better contrast
  static Color getComplementaryColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    final complementaryHue = (hsl.hue + 180) % 360;
    return hsl.withHue(complementaryHue).toColor();
  }

  /// Generate a lighter shade of a color
  static Color getLighterShade(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  /// Generate a darker shade of a color
  static Color getDarkerShade(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
