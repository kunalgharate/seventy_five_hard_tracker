import 'package:flutter/material.dart';
import '../theme/figma_tokens.dart';

/// Reusable Figma-styled building blocks shared across the restyled screens.
/// All visuals trace back to /tmp/figma_make/src/index.css.

/// A card surface matching Figma's white rounded card with soft shadow + hairline border.
class FigmaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? background;
  final Color? borderColor;
  final List<BoxShadow>? shadow;

  const FigmaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = FigmaTokens.rCard,
    this.onTap,
    this.background,
    this.borderColor,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            background ?? (isDark ? FigmaTokens.darkCard : FigmaTokens.white),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              borderColor ?? (isDark ? FigmaTokens.darkLine : FigmaTokens.line),
        ),
        boxShadow: shadow ?? FigmaTokens.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Section header: bold title + muted note, optional trailing widget.
class FigmaSectionHead extends StatelessWidget {
  final String title;
  final String? note;
  final Widget? trailing;
  const FigmaSectionHead(
      {super.key, required this.title, this.note, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : FigmaTokens.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FigmaTokens.heading(17, color: titleColor)),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(note!,
                      style: FigmaTokens.body(11, color: FigmaTokens.muted)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Gradient icon tile (blue/violet/coral) used by habit cards, reviewers, etc.
class FigmaIconTile extends StatelessWidget {
  final IconData icon;
  final int colorIndex;
  final double size;
  final double iconSize;
  final LinearGradient? gradient;
  const FigmaIconTile({
    super.key,
    required this.icon,
    this.colorIndex = 0,
    this.size = 43,
    this.iconSize = 22,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ?? FigmaTokens.tileGradient(colorIndex),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

/// Full-width gradient button matching Figma's primary CTA.
class FigmaGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  const FigmaGradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: FigmaTokens.brandGradient,
          borderRadius: BorderRadius.circular(FigmaTokens.rButton),
          boxShadow: FigmaTokens.gradientShadow,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(label,
                        style: FigmaTokens.body(13,
                            weight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pill chip (status badges, day pills).
class FigmaChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  const FigmaChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FigmaTokens.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
          ],
          Text(label,
              style:
                  FigmaTokens.body(10, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// A horizontal performance bar (label + percent + progress track).
class FigmaPerformanceBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;
  const FigmaPerformanceBar({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : FigmaTokens.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: FigmaTokens.body(12,
                    weight: FontWeight.w600, color: labelColor)),
            Text('$percent%',
                style: FigmaTokens.body(12, color: FigmaTokens.muted)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: (percent.clamp(0, 100)) / 100,
            minHeight: 5,
            backgroundColor:
                isDark ? FigmaTokens.darkLine : const Color(0xFFF1EDEB),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
