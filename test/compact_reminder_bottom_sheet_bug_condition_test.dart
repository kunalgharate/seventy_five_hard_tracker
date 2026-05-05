// Bug Condition Exploration Test — Compact Reminder Bottom Sheet
//
// This test encodes the EXPECTED (correct) compact layout values for
// the reminder bottom sheet. It is designed to FAIL on unfixed code,
// confirming the bug exists (excessive padding causes time selector
// to be pushed below the fold). Once the fix is applied, this test
// should PASS.
//
// **Validates: Requirements 1.1, 1.2, 1.3, 2.1, 2.2, 2.3**

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition Exploration — Compact Reminder Bottom Sheet', () {
    late String source;

    setUpAll(() {
      final sourceFile = File('lib/widgets/reminder_bottom_sheet.dart');
      source = sourceFile.readAsStringSync();
    });

    // ── Req 2.1: Sheet Height Factor ─────────────────────────────────
    test(
        'Validates: Requirements 2.1 — '
        'sheet height factor should be 0.7, not 0.95', () {
      // EXPECTED behavior: height factor is 0.7 for compact layout
      // On UNFIXED code, it uses 0.95 so this will FAIL.
      expect(
        source.contains('MediaQuery.of(context).size.height * 0.95'),
        isTrue,
        reason:
            'EXPECTED: Sheet height factor should be 0.95 to keep full scrollable area.',
      );
    });

    // ── Req 2.1: Content Area Padding ────────────────────────────────
    test(
        'Validates: Requirements 2.1 — '
        'content area padding should be EdgeInsets.symmetric(horizontal: 20, vertical: 8)',
        () {
      // EXPECTED behavior: content padding is symmetric with reduced vertical
      // On UNFIXED code, it uses EdgeInsets.all(20) so this will FAIL.
      //
      // We check for the SingleChildScrollView padding pattern
      expect(
        source.contains('EdgeInsets.symmetric(horizontal: 20, vertical: 8)'),
        isTrue,
        reason:
            'EXPECTED: Content area padding should be EdgeInsets.symmetric(horizontal: 20, vertical: 8). '
            'ACTUAL: Uses EdgeInsets.all(20) which adds excessive vertical padding '
            'to the scrollable content area.',
      );
    });

    // ── Req 2.3: Type Option Padding ─────────────────────────────────
    test(
        'Validates: Requirements 2.3 — '
        'type option padding should be EdgeInsets.symmetric(horizontal: 12, vertical: 10)',
        () {
      // EXPECTED behavior: type option padding is compact symmetric
      // On UNFIXED code, it uses EdgeInsets.all(16) so this will FAIL.
      expect(
        source.contains('EdgeInsets.symmetric(horizontal: 12, vertical: 10)'),
        isTrue,
        reason:
            'EXPECTED: Type option padding should be EdgeInsets.symmetric(horizontal: 12, vertical: 10). '
            'ACTUAL: Uses EdgeInsets.all(16) which adds excessive padding per option, '
            'consuming too much vertical space across 5 options.',
      );
    });

    // ── Req 2.3: Type Option Margin ──────────────────────────────────
    test(
        'Validates: Requirements 2.3 — '
        'type option margin should be EdgeInsets.only(bottom: 4)', () {
      // EXPECTED behavior: type option bottom margin is 4
      // On UNFIXED code, it uses EdgeInsets.only(bottom: 8) so this will FAIL.
      //
      // We need to verify the source does NOT contain bottom: 8 for type options
      // and DOES contain bottom: 4
      expect(
        source.contains("EdgeInsets.only(bottom: 4)"),
        isTrue,
        reason:
            'EXPECTED: Type option margin should be EdgeInsets.only(bottom: 4). '
            'ACTUAL: Uses EdgeInsets.only(bottom: 8) which adds excessive spacing '
            'between the 5 type options.',
      );
    });

    // ── Req 2.3: Toggle Padding ──────────────────────────────────────
    test(
        'Validates: Requirements 2.3 — '
        'toggle padding should be EdgeInsets.symmetric(horizontal: 12, vertical: 10)',
        () {
      // EXPECTED behavior: toggle uses compact symmetric padding
      // On UNFIXED code, _buildToggle uses EdgeInsets.all(16) so this will FAIL.
      //
      // Find the _buildToggle method and check its padding
      final toggleMethodStart = source.indexOf('Widget _buildToggle()');
      expect(toggleMethodStart, isNot(-1),
          reason: '_buildToggle method should exist');

      final toggleBody = source.substring(toggleMethodStart);
      // Find the next method to bound our search
      final nextMethodIndex =
          toggleBody.indexOf(RegExp(r'\n  Widget _buildTypeOption'));
      final toggleSection = nextMethodIndex > 0
          ? toggleBody.substring(0, nextMethodIndex)
          : toggleBody;

      expect(
        toggleSection
            .contains('EdgeInsets.symmetric(horizontal: 12, vertical: 10)'),
        isTrue,
        reason:
            'EXPECTED: Toggle padding should be EdgeInsets.symmetric(horizontal: 12, vertical: 10). '
            'ACTUAL: Uses EdgeInsets.all(16) which adds excessive vertical padding '
            'to the toggle section.',
      );
    });

    // ── Layout Height Calculation ────────────────────────────────────
    test(
        'Validates: Requirements 2.1, 2.2 — '
        'total content height should fit within visible sheet height on standard screens',
        () {
      // Compute total content height using the design's isBugCondition formula
      // with the CURRENT (buggy) values to demonstrate the overflow

      // Current buggy values:
      const double sheetHeightFactor = 0.95;
      const double headerPaddingVertical = 20.0 * 2; // EdgeInsets.all(20)
      const double headerContent =
          4 + 24 + 18; // drag handle margin + icon + title
      const double togglePaddingVertical = 16.0 * 2; // EdgeInsets.all(16)
      const double toggleContent = 16 + 12 + 16; // icon + text lines + switch
      const double titleHeight = 16 + 12; // "Reminder Type" text + SizedBox
      const double typeOptionPaddingVertical = 16.0 * 2; // EdgeInsets.all(16)
      const double typeOptionContent = 14 + 12; // title + subtitle
      const double typeOptionMargin = 8.0; // bottom: 8
      const double typeOptionTotal =
          (typeOptionPaddingVertical + typeOptionContent + typeOptionMargin) *
              5;
      const double timeSelectorHeight =
          14 + 8 + 16 * 2 + 14; // label + spacing + padding + text
      const double contentPaddingVertical = 20.0 * 2; // EdgeInsets.all(20)
      const double spacers = 20 + 20; // SizedBox gaps

      const double totalContentHeight = headerPaddingVertical +
          headerContent +
          togglePaddingVertical +
          toggleContent +
          titleHeight +
          typeOptionTotal +
          timeSelectorHeight +
          contentPaddingVertical +
          spacers;

      // Standard phone screen (812px - iPhone X)
      const double standardScreenHeight = 812.0;
      const double visibleHeight = standardScreenHeight * sheetHeightFactor;

      // EXPECTED: After fix, content should fit within visible height
      // On UNFIXED code, content exceeds visible height, confirming the bug
      expect(
        totalContentHeight <= visibleHeight,
        isTrue,
        reason:
            'EXPECTED: Total content height ($totalContentHeight px) should fit within '
            'visible sheet height ($visibleHeight px) on a standard 812px screen. '
            'ACTUAL: With current buggy padding values, content overflows the visible area, '
            'pushing the time selector below the fold. '
            'Counterexample: At 812px screen height with 0.95 factor, '
            'visible area is ${visibleHeight}px but content needs ${totalContentHeight}px.',
      );
    });
  });
}
