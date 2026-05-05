# Compact Reminder Bottom Sheet Bugfix Design

## Overview

The reminder bottom sheet in `lib/widgets/reminder_bottom_sheet.dart` occupies 95% of screen height and uses generous padding/margins throughout, pushing the time selector below the visible fold. Users must scroll to find the time configuration after selecting a reminder type, but nothing indicates that scrolling is needed. The fix reduces the sheet height, tightens padding on the header, content area, type options, and toggle, so that all five type options and the time selector are visible without scrolling on standard screen sizes. The fix is purely cosmetic (spacing/sizing) and must not alter any functional behavior.

## Glossary

- **Bug_Condition (C)**: The layout condition where the bottom sheet's internal content (toggle + type options + time selector) exceeds the visible area due to excessive height allocation and padding, forcing the time selector below the fold
- **Property (P)**: The desired layout where all five type options and the time selector fit within the initially visible area of the bottom sheet without scrolling
- **Preservation**: All functional behaviors — type selection, toggle, save, dismiss, disabled state display, and data format — must remain unchanged by the fix
- **ReminderBottomSheet**: The `StatefulWidget` in `lib/widgets/reminder_bottom_sheet.dart` that renders the reminder configuration UI
- **Type Option**: One of the five selectable reminder types (once, multiple, hourly, interval, custom) rendered by `_buildTypeOption`
- **Time Selector**: The time picker widget rendered conditionally based on the selected type, appearing after the type options list

## Bug Details

### Bug Condition

The bug manifests when the reminder bottom sheet opens with reminders enabled. The combination of a 95% screen height container, 20px all-around content padding, 16px all-around padding per type option, 8px bottom margin per option, and a 16px-padded toggle section causes the cumulative vertical space to exceed the visible area, pushing the time selector below the fold.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type { screenHeight: number, enabled: boolean }
  OUTPUT: boolean

  headerHeight := 4 + 24 + 20*2 + 18       // drag handle + vertical margin + header padding + title
  toggleHeight := 16*2 + 16 + 12 + 16       // toggle padding + icon + text lines + switch
  titleHeight := 16 + 12                     // "Reminder Type" text + SizedBox spacing
  typeOptionHeight := 16*2 + 14 + 12 + 8     // padding top/bottom + title + subtitle + margin
  totalTypeOptions := typeOptionHeight * 5
  timeSelectorHeight := 14 + 8 + 16*2 + 14   // label + spacing + padding + text
  contentPadding := 20 * 2                    // top + bottom content padding
  spacers := 20 + 20                          // SizedBox gaps between sections

  totalContentHeight := headerHeight + toggleHeight + titleHeight
                        + totalTypeOptions + timeSelectorHeight
                        + contentPadding + spacers

  visibleHeight := screenHeight * 0.95

  RETURN input.enabled = true
         AND totalContentHeight > visibleHeight
END FUNCTION
```

### Examples

- **Standard phone (812px height)**: Sheet is 771px. Content with current padding totals ~750-800px. Time selector is at the bottom edge or just below the fold — user must scroll to see it.
- **Smaller phone (667px height)**: Sheet is 633px. Content easily exceeds visible area. Time selector is completely hidden below the fold.
- **Tablet (1024px height)**: Sheet is 972px. Content fits, but the sheet is unnecessarily tall with wasted space at the bottom.
- **Disabled state**: When `_enabled` is false, only the toggle and info message are shown — no overflow issue. This is NOT a bug condition.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Tapping a reminder type option must continue to select that type and show the corresponding configuration section
- Toggling the enable/disable switch must continue to show or hide reminder configuration options
- Saving must continue to produce correctly formatted reminder data strings (`once:`, `multiple:`, `hourly:`, `interval:`, `custom:` prefixes)
- The close button and save action must continue to dismiss the bottom sheet
- When reminders are disabled, the informational message must continue to display

**Scope:**
All functional interactions — type selection, toggle, save, dismiss, data serialization, and disabled state — should be completely unaffected by this fix. The changes are limited to:
- Container height factor
- Padding values (header, content area, type options, toggle)
- Margin values (type option spacing)
- Font sizes and SizedBox heights for spacing elements

No widget tree structure, state management, callbacks, or data flow is modified.

## Hypothesized Root Cause

Based on the bug description and code analysis, the root causes are:

1. **Excessive Sheet Height**: `MediaQuery.of(context).size.height * 0.95` allocates 95% of screen height. The content doesn't need this much space, and a smaller factor (e.g., 0.7 or less) would better fit the actual content while keeping the time selector visible.

2. **Oversized Content Padding**: `EdgeInsets.all(20)` on the `SingleChildScrollView` adds 40px of vertical padding (top + bottom) to the scrollable content area. Reducing to ~12px vertical padding saves ~16px.

3. **Oversized Type Option Padding and Margins**: Each type option uses `EdgeInsets.all(16)` padding and `EdgeInsets.only(bottom: 8)` margin. With 5 options, this contributes `(16*2 + 8) * 5 = 200px` of padding/margin alone. Reducing padding to ~10-12px symmetric and margin to ~4-6px saves significant vertical space.

4. **Oversized Header Padding**: The header row uses `EdgeInsets.all(20)`, adding 40px vertically. Reducing to ~12-16px saves space.

5. **Oversized Toggle Padding**: The toggle container uses `EdgeInsets.all(16)`, adding 32px vertically. Reducing to ~10-12px saves space.

6. **Generous Inter-Section Spacing**: `SizedBox(height: 20)` gaps between sections and `SizedBox(height: 12)` after the "Reminder Type" title add up. Reducing these to ~12px and ~8px respectively saves additional space.

## Correctness Properties

Property 1: Bug Condition - Time Selector Visible Without Scrolling

_For any_ screen size where the bottom sheet opens with reminders enabled and a type selected, the fixed layout SHALL render the time selector within the initially visible area of the bottom sheet, so that the total content height (toggle + type options + time selector) fits within the sheet's visible height without requiring scrolling.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Functional Behavior Unchanged

_For any_ user interaction (type selection, toggle, save, dismiss, disabled state), the fixed code SHALL produce exactly the same functional result as the original code, preserving type selection state changes, toggle visibility behavior, save data format, dismiss navigation, and disabled state display.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `lib/widgets/reminder_bottom_sheet.dart`

**Function**: `build` method and `_buildTypeOption`, `_buildToggle` methods

**Specific Changes**:

1. **Reduce Sheet Height Factor**: Change `MediaQuery.of(context).size.height * 0.95` to `MediaQuery.of(context).size.height * 0.7` (or use a constraint like `min()` to cap at a reasonable height). This right-sizes the sheet to its content.

2. **Reduce Header Padding**: Change the header `Padding` from `EdgeInsets.all(20)` to approximately `EdgeInsets.symmetric(horizontal: 20, vertical: 12)` to reduce vertical space while keeping horizontal alignment.

3. **Reduce Content Area Padding**: Change the `SingleChildScrollView` padding from `EdgeInsets.all(20)` to approximately `EdgeInsets.symmetric(horizontal: 20, vertical: 8)` to reduce vertical padding in the scrollable area.

4. **Compact Type Option Padding and Margins**: In `_buildTypeOption`, reduce the container padding from `EdgeInsets.all(16)` to approximately `EdgeInsets.symmetric(horizontal: 12, vertical: 10)` and reduce the margin from `EdgeInsets.only(bottom: 8)` to `EdgeInsets.only(bottom: 4)`.

5. **Compact Toggle Padding**: In `_buildToggle`, reduce the container padding from `EdgeInsets.all(16)` to approximately `EdgeInsets.symmetric(horizontal: 12, vertical: 10)`.

6. **Reduce Inter-Section Spacing**: Reduce `SizedBox(height: 20)` gaps to `SizedBox(height: 12)` and `SizedBox(height: 12)` after "Reminder Type" title to `SizedBox(height: 8)`.

7. **Reduce Bottom Button Padding**: Reduce the save button area padding from `EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + ...)` to approximately `EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 12 + ...)`.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the layout overflow on unfixed code, then verify the fix makes the time selector visible and preserves all functional behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the layout issue BEFORE implementing the fix. Confirm or refute the root cause analysis by measuring actual widget heights. If we refute, we will need to re-hypothesize.

**Test Plan**: Write widget tests that render the `ReminderBottomSheet` with reminders enabled and measure the vertical space consumed by each section. Run these tests on the UNFIXED code to confirm the time selector is below the fold.

**Test Cases**:
1. **Standard Screen Layout Test**: Render the bottom sheet at 812px screen height with "once" type selected and verify the time selector's position relative to the visible area (will show overflow on unfixed code)
2. **Small Screen Layout Test**: Render at 667px screen height and verify the time selector is not visible (will fail on unfixed code)
3. **All Types Visible Test**: Verify all 5 type options are rendered and the time selector follows immediately after (will show it's below fold on unfixed code)
4. **Content Height Measurement**: Measure total content height vs available sheet height (will show content exceeds visible area on unfixed code)

**Expected Counterexamples**:
- Time selector widget is positioned below the visible area of the sheet
- Possible causes: cumulative padding/margin on 5 type options + header + toggle exceeds visible height

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds (reminders enabled, any type selected), the fixed layout renders the time selector within the visible area.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := renderFixedBottomSheet(input)
  ASSERT timeSelectorIsVisible(result)
  ASSERT allTypeOptionsVisible(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (functional interactions), the fixed code produces the same result as the original code.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalBehavior(input) = fixedBehavior(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many combinations of type selections, toggle states, and time values automatically
- It catches edge cases in data serialization that manual unit tests might miss
- It provides strong guarantees that save behavior is unchanged for all type/time combinations

**Test Plan**: Observe behavior on UNFIXED code first for type selection, toggle, save, and dismiss interactions, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Type Selection Preservation**: Verify tapping each of the 5 type options updates `_type` state and shows the correct configuration widget on both unfixed and fixed code
2. **Toggle Preservation**: Verify toggling the switch shows/hides the configuration section identically on both unfixed and fixed code
3. **Save Data Format Preservation**: Verify saving with each type produces the correct data string format (`once:HH:mm`, `multiple:HH:mm,HH:mm`, etc.) identically on both versions
4. **Dismiss Preservation**: Verify close button and save both call `Navigator.pop` on both versions

### Unit Tests

- Test that the sheet height factor is reduced from 0.95 to the new value
- Test that type option padding and margin values match the new compact values
- Test that the toggle padding matches the new compact value
- Test that content area padding matches the new compact value
- Test edge cases: disabled state still shows info message, empty time defaults

### Property-Based Tests

- Generate random screen heights (400-1200px) and verify the time selector fits within the visible area for all enabled states
- Generate random type selections and time values, verify save produces correctly formatted data strings identical to original behavior
- Generate random toggle sequences and verify the configuration section visibility matches expected state

### Integration Tests

- Test full flow: open sheet → enable reminders → select type → verify time selector visible → pick time → save → verify data
- Test switching between all 5 types and verifying the time selector remains visible after each switch
- Test that the bottom sheet opens and closes correctly with the new compact layout
