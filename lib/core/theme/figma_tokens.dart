import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens extracted from the Figma "Design Daily Metal App" make file
/// (src/index.css). Single source of truth for the Figma-matched visual style.
///
/// Figma reference:
///   --orange #ff7918, --coral #ff5449, --pink #ed356b
///   --ink #282429, --muted #898188, --line #eee9e7, --soft #faf7f5
///   gradient: linear-gradient(125deg, orange, coral 55%, pink)
///   fonts: DM Sans (body), Manrope (headings)
class FigmaTokens {
  FigmaTokens._();

  // ── Core palette ──
  static const orange = Color(0xFFFF7918);
  static const coral = Color(0xFFFF5449);
  static const pink = Color(0xFFED356B);
  static const ink = Color(0xFF282429);
  static const muted = Color(0xFF898188);
  static const line = Color(0xFFEEE9E7);
  static const soft = Color(0xFFFAF7F5);
  static const white = Color(0xFFFFFFFF);

  // Dark mode surfaces (kept neutral-warm to pair with the brand palette)
  static const darkBg = Color(0xFF1A1618);
  static const darkCard = Color(0xFF262123);
  static const darkLine = Color(0xFF3A3335);

  // Dark gradient card (insights highlight, leaderboard, promo)
  static const darkGradStart = Color(0xFF30272C);
  static const darkGradEnd = Color(0xFF51323E);

  // ── Signature gradient (125deg orange → coral 55% → pink) ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange, coral, pink],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkGradStart, darkGradEnd],
  );

  // ── Icon-tile gradients (blue / violet / coral) ──
  static const LinearGradient tileBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF25B4E8), Color(0xFF3478EE)],
  );
  static const LinearGradient tileViolet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9A66EE), Color(0xFF6850D7)],
  );
  static const LinearGradient tileCoral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9D42), Color(0xFFF2514D)],
  );

  /// Pick an icon-tile gradient by index (stable per-habit coloring).
  static LinearGradient tileGradient(int index) {
    switch (index % 3) {
      case 0:
        return tileBlue;
      case 1:
        return tileViolet;
      default:
        return tileCoral;
    }
  }

  // ── Radii ──
  static const double rCard = 18;
  static const double rCardLg = 22;
  static const double rChip = 99;
  static const double rButton = 13;
  static const double rTile = 13;

  // ── Shadows ──
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF322326).withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> gradientShadow = [
    BoxShadow(
      color: const Color(0xFFF34745).withValues(alpha: 0.2),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
  ];

  // ── Typography (Manrope headings, DM Sans body) ──
  static TextStyle heading(double size,
          {FontWeight weight = FontWeight.w800, Color? color}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.4,
        color: color ?? ink,
      );

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
      );
}
