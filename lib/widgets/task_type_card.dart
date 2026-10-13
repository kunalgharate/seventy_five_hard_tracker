import 'package:flutter/material.dart';
import 'package:seventy_five_hard_tracker/core/services/dynamic_color_service.dart';

/// Presentation kit for one task category: label, icon, accent color and a
/// short tagline. Used by [TaskTypeCard] so each task type gets its own look
/// instead of one generic card. Unknown categories fall back to a generic
/// style tinted with the existing [DynamicColorService] category color.
class TaskTypeStyle {
  final String label;
  final IconData icon;
  final String tagline;
  final Color accent;

  const TaskTypeStyle({
    required this.label,
    required this.icon,
    required this.tagline,
    required this.accent,
  });

  static TaskTypeStyle of(String category) {
    final key = category.toLowerCase().trim();
    final accent = key.isEmpty || key == 'general'
        ? const Color(0xFFFF6F00)
        : DynamicColorService.getColorForCategory(key);

    switch (key) {
      case 'fitness':
      case 'workout':
      case 'exercise':
        return TaskTypeStyle(
          label: 'Fitness',
          icon: Icons.fitness_center,
          tagline: 'Move your body',
          accent: accent,
        );
      case 'meditation':
      case 'mindfulness':
        return TaskTypeStyle(
          label: 'Mindfulness',
          icon: Icons.self_improvement,
          tagline: 'Stay present',
          accent: accent,
        );
      case 'nutrition':
      case 'diet':
      case 'food':
        return TaskTypeStyle(
          label: 'Nutrition',
          icon: Icons.restaurant,
          tagline: 'Fuel well',
          accent: accent,
        );
      case 'water':
      case 'hydration':
        return TaskTypeStyle(
          label: 'Hydration',
          icon: Icons.water_drop,
          tagline: 'Stay hydrated',
          accent: accent,
        );
      case 'reading':
      case 'book':
      case 'study':
        return TaskTypeStyle(
          label: 'Learning',
          icon: Icons.menu_book,
          tagline: 'Read & learn',
          accent: accent,
        );
      case 'sleep':
      case 'rest':
        return TaskTypeStyle(
          label: 'Sleep',
          icon: Icons.bedtime,
          tagline: 'Recover well',
          accent: accent,
        );
      case 'productivity':
      case 'work':
        return TaskTypeStyle(
          label: 'Focus',
          icon: Icons.bolt,
          tagline: 'Do the work',
          accent: accent,
        );
      case '':
      case 'general':
        return TaskTypeStyle(
          label: 'General',
          icon: Icons.local_fire_department,
          tagline: 'Daily discipline',
          accent: accent,
        );
      default:
        return TaskTypeStyle(
          label: _capitalized(category.trim()),
          icon: Icons.category,
          tagline: 'Custom task',
          accent: accent,
        );
    }
  }

  static String _capitalized(String value) =>
      value.isEmpty ? 'Task' : value[0].toUpperCase() + value.substring(1);
}

/// Task card shell with per-category presentation: a category-tinted header
/// (icon + label + tagline), the caller-supplied body (checkbox, title,
/// actions) and a slim progress bar that fills once the task is saved as
/// completed. Surface, text and tints come from the theme so light and dark
/// mode both render correctly.
class TaskTypeCard extends StatelessWidget {
  /// Corner radius used across all task cards.
  static const double kRadius = 16;

  /// Challenge category driving the header presentation (e.g. 'fitness').
  final String category;

  /// Whether the task is persisted as completed for the shown day.
  final bool isCompleted;

  /// Status accent for the left edge and progress bar: green when completed,
  /// red when missed, the category color while pending.
  final Color accent;

  /// Card body built by the caller — keeps all checkbox/toggle behaviour.
  final Widget child;

  const TaskTypeCard({
    super.key,
    required this.category,
    required this.isCompleted,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final style = TaskTypeStyle.of(category);
    final onAccent = isDark
        ? DynamicColorService.getLighterShade(style.accent, 0.2)
        : DynamicColorService.getDarkerShade(style.accent, 0.28);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: isDark
              ? scheme.onSurface.withValues(alpha: 0.08)
              : scheme.onSurface.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(width: 4, color: accent)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme, scheme, style, onAccent, isDark),
              child,
              _buildProgressBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme scheme,
    TaskTypeStyle style,
    Color onAccent,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: isDark ? 0.18 : 0.08),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: style.accent.withValues(alpha: isDark ? 0.3 : 0.18),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(style.icon, size: 14, color: onAccent),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              style.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: onAccent,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              style.tagline,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isCompleted ? 1 : 0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: accent.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ),
    );
  }
}
