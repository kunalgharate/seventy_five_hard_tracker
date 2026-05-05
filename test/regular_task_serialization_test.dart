/// Property Test: RegularTask serialization round-trip
///
/// For any valid RegularTask object, serializing it to JSON via toJson()
/// and deserializing it back via fromJson() SHALL produce an equivalent
/// RegularTask object.
///
/// **Validates: Requirements 1.5**
library regular_task_serialization_test;

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/models/regular_task.dart';

/// Generates a random non-empty string of given max length.
String _randomString(Random rng, {int maxLength = 20}) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-';
  final length = rng.nextInt(maxLength) + 1; // at least 1 char
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random nullable string.
String? _randomNullableString(Random rng, {int maxLength = 20}) {
  if (rng.nextBool()) return null;
  return _randomString(rng, maxLength: maxLength);
}

/// Generates a random nullable int.
int? _randomNullableInt(Random rng, {int max = 0xFFFFFF}) {
  if (rng.nextBool()) return null;
  return rng.nextInt(max);
}

/// Generates a random DateTime within a reasonable range.
DateTime _randomDateTime(Random rng) {
  // Random date between 2020-01-01 and 2030-12-31
  final year = 2020 + rng.nextInt(11);
  final month = 1 + rng.nextInt(12);
  final day = 1 + rng.nextInt(28); // safe for all months
  final hour = rng.nextInt(24);
  final minute = rng.nextInt(60);
  final second = rng.nextInt(60);
  return DateTime(year, month, day, hour, minute, second);
}

/// Generates a random reminder time in "HH:mm" format, or null.
String? _randomReminderTime(Random rng) {
  if (rng.nextBool()) return null;
  final h = rng.nextInt(24).toString().padLeft(2, '0');
  final m = rng.nextInt(60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Generates a random RegularTask with arbitrary valid field values.
RegularTask _randomRegularTask(Random rng) {
  const categories = [
    'general',
    'health',
    'fitness',
    'learning',
    'mindfulness'
  ];
  const reminderTypes = ['once', 'hourly', 'custom'];

  return RegularTask(
    id: _randomString(rng, maxLength: 30),
    title: _randomString(rng, maxLength: 100),
    reminderTime: _randomReminderTime(rng),
    isReminderEnabled: rng.nextBool(),
    imagePath: _randomNullableString(rng, maxLength: 50),
    iconName: _randomNullableString(rng, maxLength: 30),
    iconColor: _randomNullableInt(rng),
    category: categories[rng.nextInt(categories.length)],
    reminderType: reminderTypes[rng.nextInt(reminderTypes.length)],
    reminderStartHour: rng.nextInt(24),
    reminderEndHour: rng.nextInt(24),
    allowNightReminders: rng.nextBool(),
    reminderIntervalMinutes: _randomNullableInt(rng, max: 1440),
    createdAt: _randomDateTime(rng),
    isArchived: rng.nextBool(),
  );
}

void main() {
  group('Property 1: RegularTask serialization round-trip', () {
    test(
      'Validates: Requirements 1.5 — '
      'for any valid RegularTask, toJson() then fromJson() produces an equivalent object',
      () {
        final rng = Random(42); // deterministic seed for reproducibility

        for (int i = 0; i < 200; i++) {
          final original = _randomRegularTask(rng);
          final json = original.toJson();
          final restored = RegularTask.fromJson(json);

          expect(
            restored,
            equals(original),
            reason: 'Round-trip failed for iteration $i: '
                'original.id=${original.id}, title=${original.title}, '
                'reminderTime=${original.reminderTime}, '
                'isReminderEnabled=${original.isReminderEnabled}, '
                'imagePath=${original.imagePath}, '
                'iconName=${original.iconName}, '
                'iconColor=${original.iconColor}, '
                'category=${original.category}, '
                'reminderType=${original.reminderType}, '
                'reminderStartHour=${original.reminderStartHour}, '
                'reminderEndHour=${original.reminderEndHour}, '
                'allowNightReminders=${original.allowNightReminders}, '
                'reminderIntervalMinutes=${original.reminderIntervalMinutes}, '
                'createdAt=${original.createdAt}, '
                'isArchived=${original.isArchived}',
          );
        }
      },
    );

    test(
      'Validates: Requirements 1.5 — '
      'all individual fields survive the round-trip exactly',
      () {
        final rng = Random(99);

        for (int i = 0; i < 100; i++) {
          final original = _randomRegularTask(rng);
          final json = original.toJson();
          final restored = RegularTask.fromJson(json);

          expect(restored.id, equals(original.id),
              reason: 'id mismatch at iteration $i');
          expect(restored.title, equals(original.title),
              reason: 'title mismatch at iteration $i');
          expect(restored.reminderTime, equals(original.reminderTime),
              reason: 'reminderTime mismatch at iteration $i');
          expect(restored.isReminderEnabled, equals(original.isReminderEnabled),
              reason: 'isReminderEnabled mismatch at iteration $i');
          expect(restored.imagePath, equals(original.imagePath),
              reason: 'imagePath mismatch at iteration $i');
          expect(restored.iconName, equals(original.iconName),
              reason: 'iconName mismatch at iteration $i');
          expect(restored.iconColor, equals(original.iconColor),
              reason: 'iconColor mismatch at iteration $i');
          expect(restored.category, equals(original.category),
              reason: 'category mismatch at iteration $i');
          expect(restored.reminderType, equals(original.reminderType),
              reason: 'reminderType mismatch at iteration $i');
          expect(restored.reminderStartHour, equals(original.reminderStartHour),
              reason: 'reminderStartHour mismatch at iteration $i');
          expect(restored.reminderEndHour, equals(original.reminderEndHour),
              reason: 'reminderEndHour mismatch at iteration $i');
          expect(restored.allowNightReminders,
              equals(original.allowNightReminders),
              reason: 'allowNightReminders mismatch at iteration $i');
          expect(restored.reminderIntervalMinutes,
              equals(original.reminderIntervalMinutes),
              reason: 'reminderIntervalMinutes mismatch at iteration $i');
          expect(restored.createdAt, equals(original.createdAt),
              reason: 'createdAt mismatch at iteration $i');
          expect(restored.isArchived, equals(original.isArchived),
              reason: 'isArchived mismatch at iteration $i');
        }
      },
    );

    test(
      'Validates: Requirements 1.5 — '
      'round-trip preserves JSON structure (toJson of restored equals original JSON)',
      () {
        final rng = Random(7);

        for (int i = 0; i < 100; i++) {
          final original = _randomRegularTask(rng);
          final json1 = original.toJson();
          final restored = RegularTask.fromJson(json1);
          final json2 = restored.toJson();

          expect(
            json2,
            equals(json1),
            reason: 'Double round-trip JSON mismatch at iteration $i',
          );
        }
      },
    );

    test(
      'Validates: Requirements 1.5 — '
      'edge case: all nullable fields set to null',
      () {
        final task = RegularTask(
          id: 'edge-null',
          title: 'Null fields test',
          reminderTime: null,
          isReminderEnabled: false,
          imagePath: null,
          iconName: null,
          iconColor: null,
          category: 'general',
          reminderType: 'once',
          reminderStartHour: 0,
          reminderEndHour: 23,
          allowNightReminders: false,
          reminderIntervalMinutes: null,
          createdAt: DateTime(2024, 1, 1),
          isArchived: false,
        );

        final json = task.toJson();
        final restored = RegularTask.fromJson(json);
        expect(restored, equals(task));
      },
    );

    test(
      'Validates: Requirements 1.5 — '
      'edge case: all nullable fields set to non-null values',
      () {
        final task = RegularTask(
          id: 'edge-full',
          title: 'All fields populated',
          reminderTime: '08:30',
          isReminderEnabled: true,
          imagePath: '/path/to/image.png',
          iconName: 'star',
          iconColor: 0xFF00FF00,
          category: 'health',
          reminderType: 'hourly',
          reminderStartHour: 6,
          reminderEndHour: 22,
          allowNightReminders: true,
          reminderIntervalMinutes: 60,
          createdAt: DateTime(2025, 6, 15, 10, 30, 45),
          isArchived: true,
        );

        final json = task.toJson();
        final restored = RegularTask.fromJson(json);
        expect(restored, equals(task));
      },
    );
  });
}
