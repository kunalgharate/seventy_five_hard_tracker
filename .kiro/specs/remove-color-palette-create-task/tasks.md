# Implementation Plan: Remove Color Palette from Create Task

## Overview

Remove the manual color selection tab from `IconPickerWidget`, narrow its callback from 3 parameters to 2, and update all consumer call sites. The `DynamicColorService` already auto-assigns colors based on task titles, making the Color tab redundant. The `RegularTask.iconColor` Hive field is preserved for backward compatibility.

## Tasks

- [x] 1. Modify IconPickerWidget to remove Color tab and simplify API
  - [x] 1.1 Remove `selectedColor` constructor parameter and `_selectedColor` state variable
    - Delete the `selectedColor` parameter from the `IconPickerWidget` constructor
    - Delete the `_selectedColor` field from `_IconPickerWidgetState`
    - Remove `_selectedColor = widget.selectedColor` from `initState()`
    - _Requirements: 3.2_
  - [x] 1.2 Narrow `onSelectionChanged` callback from 3 parameters to 2
    - Change `Function(String? iconName, String? imagePath, int? color)` to `Function(String? iconName, String? imagePath)`
    - Update all internal invocations of `onSelectionChanged` to pass only `iconName` and `imagePath`
    - In `_buildIconOption`, remove `_selectedColor` usage and always use `iconData.color` for rendering
    - In `_pickImage`, update callback call to `widget.onSelectionChanged(null, _selectedImagePath)`
    - In `_clearImage`, update callback call to `widget.onSelectionChanged(_selectedIconName, null)`
    - _Requirements: 3.1, 3.3, 3.4_
  - [x] 1.3 Reduce TabController from 3 tabs to 2 and remove Color tab UI
    - Change `TabController(length: 3)` to `TabController(length: 2)` in `initState()`
    - Remove the `Tab(icon: Icon(Icons.palette), text: 'Color')` entry from `_buildTabBar()`
    - Remove `_buildColorPickerTab()` from the `TabBarView` children list
    - Delete the entire `_buildColorPickerTab()` method
    - _Requirements: 1.1, 1.2_

- [x] 2. Update consumer call sites to use new 2-parameter callback
  - [x] 2.1 Update `_AddRegularTaskSheet._showIconPicker()` in `regular_tasks_screen.dart`
    - Remove `selectedColor: _challenge.iconColor` from `IconPickerWidget` constructor call
    - Change callback from `(iconName, imagePath, color)` to `(iconName, imagePath)`
    - Remove `iconColor: color ?? _challenge.iconColor` and preserve existing `_challenge.iconColor` in the rebuilt `Challenge`
    - _Requirements: 1.3, 3.1, 2.2_
  - [x] 2.2 Update `_EditRegularTaskSheet._showIconPicker()` in `regular_tasks_screen.dart`
    - Remove `selectedColor: _challenge.iconColor` from `IconPickerWidget` constructor call
    - Change callback from `(iconName, imagePath, color)` to `(iconName, imagePath)`
    - Preserve existing `_challenge.iconColor` in the rebuilt `Challenge` (no color override from picker)
    - _Requirements: 1.4, 3.1, 4.3_
  - [x] 2.3 Update `OnboardingScreen._showIconPicker()` in `onboarding_screen.dart`
    - Remove `selectedColor: _challenges[index].iconColor` from `IconPickerWidget` constructor call
    - Change callback from `(iconName, imagePath, color)` to `(iconName, imagePath)`
    - Preserve existing `_challenges[index].iconColor` in the rebuilt `Challenge`
    - _Requirements: 1.5, 3.1_

- [x] 3. Checkpoint — Verify compilation and existing behavior
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Add tests for the changes
  - [ ]* 4.1 Write widget test verifying IconPickerWidget renders exactly 2 tabs
    - Test that "Icons" and "Image" tabs are present
    - Test that no "Color" tab or palette text is rendered
    - _Requirements: 1.1, 1.2_
  - [ ]* 4.2 Write property test for DynamicColorService determinism and palette membership
    - **Property 1: DynamicColorService determinism and palette membership**
    - Generate random non-empty strings, verify `getColorForText` returns the same color for the same input and that the color is a member of `_vibrantColors`
    - **Validates: Requirements 2.1**
  - [ ]* 4.3 Write property test for RegularTask iconColor serialization round-trip
    - **Property 2: RegularTask iconColor serialization round-trip**
    - Generate random `RegularTask` instances with random `iconColor` values (including null), verify `toJson()`/`fromJson()` round-trip preserves `iconColor`
    - **Validates: Requirements 4.1**
  - [ ]* 4.4 Write unit test verifying icon selection callback returns 2 parameters
    - Test that tapping an icon invokes callback with `(iconName, null)` — no color parameter
    - Test that selecting an image invokes callback with `(null, imagePath)`
    - _Requirements: 3.3, 3.4_

- [ ] 5. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- The `RegularTask` model and `DynamicColorService` are intentionally unchanged — no code modifications needed there
- Compile-time safety ensures any missed call site will fail to build after the callback signature change
- Property tests validate universal correctness properties from the design document
