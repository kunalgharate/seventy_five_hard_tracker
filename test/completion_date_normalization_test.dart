/// Property Test: Completion date normalization
///
/// For any DateTime with arbitrary time components, saving a
/// RegularTaskCompletion SHALL normalize the date to midnight
/// (year, month, day only) and key the record by "YYYY-MM-DD" format,
/// such that retrieving the completion by any DateTime on the same
/// calendar day returns the same record.
///
/// **Validates: Requirements 1.4**
library completion_date_normalization_test;

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/models/regular_task_completion.dart';

/// Generates a random DateTime with arbitrary time components.
DateTime _randomDateTime(Random rng) {
  final year = 2020 + rng.nextInt(11);
  final month = 1 + rng.nextInt(12);
  final day = 1 + rng.nextInt(28); // safe for all months
  final hour = rng.nextInt(24);
  final minute = rng.nextInt(60);
  final second = rng.nextInt(60);
  final millisecond = rng.nextInt(1000);
  return DateTime(year, month, day, hour, minute, second, millisecond);
}

/// Generates a random task completions map.
Map<String, bool> _randomTaskCompletions(Random rng) {
  final count = rng.nextInt(5) + 1;
  return {
    for (int i = 0; i < count; i++) 'task_${rng.nextInt(1000)}': rng.nextBool(),
  };
}

void main() {
  group('Property 2: Completion date normalization', () {
    test(
      'Validates: Requirements 1.4 — '
      'date is always normalized to midnight (hour=0, minute=0, second=0, millisecond=0)',
      () {
        final rng = Random(42);

        for (int i = 0; i < 200; i++) {
          final arbitraryDate = _randomDateTime(rng);
          final completions = _randomTaskCompletions(rng);

          final completion = RegularTaskCompletion(
            date: arbitraryDate,
            taskCompletions: completions,
          );

          expect(completion.date.hour, equals(0),
              reason: 'hour not normalized to 0 at iteration $i, '
                  'input=$arbitraryDate');
          expect(completion.date.minute, equals(0),
              reason: 'minute not normalized to 0 at iteration $i, '
                  'input=$arbitraryDate');
          expect(completion.date.second, equals(0),
              reason: 'second not normalized to 0 at iteration $i, '
                  'input=$arbitraryDate');
          expect(completion.date.millisecond, equals(0),
              reason: 'millisecond not normalized to 0 at iteration $i, '
                  'input=$arbitraryDate');
          // Year, month, day must be preserved
          expect(completion.date.year, equals(arbitraryDate.year),
              reason: 'year changed at iteration $i');
          expect(completion.date.month, equals(arbitraryDate.month),
              reason: 'month changed at iteration $i');
          expect(completion.date.day, equals(arbitraryDate.day),
              reason: 'day changed at iteration $i');
        }
      },
    );

    test(
      'Validates: Requirements 1.4 — '
      'dateKey is always in "YYYY-MM-DD" format',
      () {
        final rng = Random(99);
        final dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

        for (int i = 0; i < 200; i++) {
          final arbitraryDate = _randomDateTime(rng);
          final completion = RegularTaskCompletion(
            date: arbitraryDate,
            taskCompletions: _randomTaskCompletions(rng),
          );

          expect(completion.dateKey, matches(dateKeyPattern),
              reason: 'dateKey "${completion.dateKey}" does not match '
                  'YYYY-MM-DD format at iteration $i, input=$arbitraryDate');

          // Verify the dateKey components match the input date
          final parts = completion.dateKey.split('-');
          expect(int.parse(parts[0]), equals(arbitraryDate.year),
              reason: 'dateKey year mismatch at iteration $i');
          expect(int.parse(parts[1]), equals(arbitraryDate.month),
              reason: 'dateKey month mismatch at iteration $i');
          expect(int.parse(parts[2]), equals(arbitraryDate.day),
              reason: 'dateKey day mismatch at iteration $i');
        }
      },
    );

    test(
      'Validates: Requirements 1.4 — '
      'two completions with different times on the same day produce the same dateKey',
      () {
        final rng = Random(7);

        for (int i = 0; i < 200; i++) {
          final year = 2020 + rng.nextInt(11);
          final month = 1 + rng.nextInt(12);
          final day = 1 + rng.nextInt(28);

          // Two different times on the same calendar day
          final time1 = DateTime(
            year,
            month,
            day,
            rng.nextInt(24),
            rng.nextInt(60),
            rng.nextInt(60),
            rng.nextInt(1000),
          );
          final time2 = DateTime(
            year,
            month,
            day,
            rng.nextInt(24),
            rng.nextInt(60),
            rng.nextInt(60),
            rng.nextInt(1000),
          );

          final completions = _randomTaskCompletions(rng);

          final c1 = RegularTaskCompletion(
            date: time1,
            taskCompletions: completions,
          );
          final c2 = RegularTaskCompletion(
            date: time2,
            taskCompletions: completions,
          );

          expect(c1.dateKey, equals(c2.dateKey),
              reason: 'Same-day completions produced different dateKeys '
                  'at iteration $i: time1=$time1, time2=$time2');
          expect(c1.date, equals(c2.date),
              reason:
                  'Same-day completions produced different normalized dates '
                  'at iteration $i: time1=$time1, time2=$time2');
        }
      },
    );

    test(
      'Validates: Requirements 1.4 — '
      'date normalization is idempotent',
      () {
        final rng = Random(13);

        for (int i = 0; i < 200; i++) {
          final arbitraryDate = _randomDateTime(rng);
          final completions = _randomTaskCompletions(rng);

          // First normalization
          final c1 = RegularTaskCompletion(
            date: arbitraryDate,
            taskCompletions: completions,
          );

          // Second normalization: feed the already-normalized date back in
          final c2 = RegularTaskCompletion(
            date: c1.date,
            taskCompletions: completions,
          );

          expect(c2.date, equals(c1.date),
              reason: 'Idempotency failed for date at iteration $i: '
                  'input=$arbitraryDate');
          expect(c2.dateKey, equals(c1.dateKey),
              reason: 'Idempotency failed for dateKey at iteration $i: '
                  'input=$arbitraryDate');
        }
      },
    );
  });
}
