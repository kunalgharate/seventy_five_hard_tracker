import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/utils/text_helpers.dart';

void main() {
  group('Bug #1: Days remaining calculation', () {
    test('Day 1 of 75 should show 74 remaining', () {
      expect(calculateRemainingDays(75, 1), 74);
    });

    test('Day 2 of 75 should show 73 remaining', () {
      expect(calculateRemainingDays(75, 2), 73);
    });

    test('Day 75 of 75 should show 0 remaining', () {
      expect(calculateRemainingDays(75, 75), 0);
    });

    test('Day 37 of 75 should show 38 remaining', () {
      expect(calculateRemainingDays(75, 37), 38);
    });

    test('Day 74 of 75 should show 1 remaining', () {
      expect(calculateRemainingDays(75, 74), 1);
    });
  });

  group('Bug #2: Singular/plural grammar', () {
    test('0 should return "days"', () {
      expect(pluralizeDay(0), 'days');
    });

    test('1 should return "day"', () {
      expect(pluralizeDay(1), 'day');
    });

    test('2 should return "days"', () {
      expect(pluralizeDay(2), 'days');
    });

    test('75 should return "days"', () {
      expect(pluralizeDay(75), 'days');
    });
  });

  group('Bug #3: Task name validation', () {
    test('empty name is rejected', () {
      expect(validateTaskName(''), isNotNull);
      expect(validateTaskName('   '), isNotNull);
    });

    test('too short name is rejected', () {
      expect(validateTaskName('ab'), isNotNull);
    });

    test('too long name is rejected', () {
      final longName = 'a' * 101;
      expect(validateTaskName(longName), isNotNull);
    });

    test('numbers-only name is rejected', () {
      expect(validateTaskName('31532'), isNotNull);
      expect(validateTaskName('000'), isNotNull);
    });

    test('special-chars-only name is rejected', () {
      expect(validateTaskName('!@#\$%'), isNotNull);
      expect(validateTaskName('---'), isNotNull);
    });

    test('random gibberish with no letters is rejected', () {
      expect(validateTaskName('123!@#'), isNotNull);
    });

    test('valid task names are accepted', () {
      expect(validateTaskName('Drink water'), isNull);
      expect(validateTaskName('Read 30 minutes'), isNull);
      expect(validateTaskName('Exercise!'), isNull);
      expect(validateTaskName('Run 5km daily'), isNull);
    });

    test('minimum valid length (3 chars with letter) is accepted', () {
      expect(validateTaskName('Run'), isNull);
    });

    test('100 character name is accepted', () {
      final name = 'a' * 100;
      expect(validateTaskName(name), isNull);
    });
  });

  group('Bug #4: Input sanitization', () {
    test('trims leading and trailing whitespace', () {
      expect(sanitizeTaskName('  hello  '), 'hello');
    });

    test('collapses multiple spaces', () {
      expect(sanitizeTaskName('drink   more   water'), 'drink more water');
    });

    test('handles tabs and newlines', () {
      expect(sanitizeTaskName('drink\t\twater'), 'drink water');
    });

    test('preserves single spaces', () {
      expect(sanitizeTaskName('Read a book'), 'Read a book');
    });

    test('handles empty string', () {
      expect(sanitizeTaskName(''), '');
    });

    test('handles only whitespace', () {
      expect(sanitizeTaskName('   '), '');
    });
  });
}
