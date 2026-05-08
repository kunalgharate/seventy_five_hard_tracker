# iOS Double Splash Screen Bugfix Design

## Overview

The iOS app shows a jarring white flash during launch because the native `LaunchScreen.storyboard` uses a white background (RGB 1,1,1) and white background images, while the Dart `InitialScreen` renders an orange gradient starting at #FFA726. The fix aligns the native splash background color and images to #FFA726 so the transition from native to Dart splash is seamless. This is a purely cosmetic/asset change with no logic modifications.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — the native iOS LaunchScreen background color (white) does not match the Dart splash primary color (#FFA726), causing a visible flash on app launch
- **Property (P)**: The desired behavior — the native LaunchScreen background matches #FFA726 so no color flash is visible during the native-to-Dart transition
- **Preservation**: Existing behaviors that must remain unchanged — LaunchImage centering, Android splash, storyboard view hierarchy, and Dart InitialScreen behavior
- **LaunchScreen.storyboard**: The Interface Builder file at `ios/Runner/Base.lproj/LaunchScreen.storyboard` that defines the native iOS splash layout
- **LaunchBackground**: The image asset at `ios/Runner/Assets.xcassets/LaunchBackground.imageset/` used as the full-bleed background in the storyboard
- **LaunchImage**: The centered logo image asset at `ios/Runner/Assets.xcassets/LaunchImage.imageset/` displayed on top of the background
- **InitialScreen**: The Dart widget in `lib/main.dart` that shows the custom orange gradient splash for 3 seconds after the native splash completes

## Bug Details

### Bug Condition

The bug manifests when the app launches on iOS. The native `LaunchScreen.storyboard` renders with a white background color and white background images before the Flutter engine initializes and displays the Dart `InitialScreen` with an orange gradient. This creates a visible white-to-orange flash.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type AppLaunchEvent
  OUTPUT: boolean
  
  RETURN input.platform == 'iOS'
         AND nativeSplashBackgroundColor != '#FFA726'
         AND dartSplashPrimaryColor == '#FFA726'
END FUNCTION
```

### Examples

- **Normal launch on iOS**: User taps app icon → sees white screen for ~0.5s → orange gradient appears → jarring flash visible
- **Cold start on iOS (slow device)**: User taps app icon → white screen persists for ~1-2s → orange gradient appears → very noticeable flash
- **Launch on Android**: User taps app icon → no white flash (Android splash is configured separately and not affected)
- **Subsequent navigation**: After initial launch, navigating within the app shows no flash (bug is launch-only)

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- The LaunchImage (app logo) must remain centered on the native splash screen with its existing constraints
- The Dart `InitialScreen` must continue to display the full orange gradient with the logo for 3 seconds before navigating to the home screen
- The Android splash screen configuration must remain completely unchanged
- The storyboard view hierarchy (LaunchBackground behind LaunchImage, both pinned to edges) must remain intact
- The `flutter_native_splash` package configuration in pubspec.yaml for Android must remain unchanged

**Scope:**
All inputs that do NOT involve the iOS native splash screen background appearance should be completely unaffected by this fix. This includes:
- Android app launches
- Dart-level splash screen behavior and timing
- LaunchImage (logo) positioning and display
- Any runtime app behavior after the splash screen completes

## Hypothesized Root Cause

Based on the bug description, the root cause is straightforward:

1. **Storyboard Background Color**: The `LaunchScreen.storyboard` has `<color key="backgroundColor" red="1" green="1" blue="1" alpha="1">` on the root view, which renders as white. This should be `red="1" green="0.655" blue="0.149"` to match #FFA726.

2. **LaunchBackground Image Assets**: The `background.png` and `darkbackground.png` files in `LaunchBackground.imageset/` are solid white (or near-white) 1×1 pixel images that get stretched to fill the screen. These need to be replaced with solid #FFA726 orange images.

3. **flutter_native_splash Disabled for iOS**: The `pubspec.yaml` has `ios: false` in the `flutter_native_splash` configuration, meaning the package does not generate/manage the iOS splash assets. Enabling it with the correct color would auto-generate matching assets, but manual asset changes achieve the same result without adding build-time dependencies.

## Correctness Properties

Property 1: Bug Condition - Native Splash Background Matches Dart Splash

_For any_ iOS app launch where the native LaunchScreen is displayed, the native splash background SHALL render with color #FFA726 (RGB 1.0/0.655/0.149), matching the Dart `InitialScreen` primary color, so no visible color flash occurs during the transition.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation - Layout and Cross-Platform Behavior Unchanged

_For any_ app launch (iOS or Android), the fixed native splash SHALL preserve the existing LaunchImage centering, storyboard view hierarchy, Android splash configuration, and Dart InitialScreen behavior identically to the original.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `ios/Runner/Base.lproj/LaunchScreen.storyboard`

**Change**: Update the background color attribute on the root view

**Specific Changes**:
1. **Update backgroundColor**: Change `<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>` to `<color key="backgroundColor" red="1" green="0.654901960784314" blue="0.149019607843137" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>` — this sets the fallback background to #FFA726

---

**File**: `ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png`

**Change**: Replace with a 1×1 pixel solid #FFA726 PNG image

**Specific Changes**:
2. **Replace background.png**: Generate a 1×1 pixel PNG with color RGB(255, 167, 38) — hex #FFA726 — and overwrite the existing white image

---

**File**: `ios/Runner/Assets.xcassets/LaunchBackground.imageset/darkbackground.png`

**Change**: Replace with a 1×1 pixel solid #FFA726 PNG image

**Specific Changes**:
3. **Replace darkbackground.png**: Generate a 1×1 pixel PNG with color RGB(255, 167, 38) — hex #FFA726 — and overwrite the existing white image. Using the same orange for dark mode ensures consistency (the Dart splash also uses the same color in dark mode).

---

**File**: `pubspec.yaml` (optional)

**Change**: Enable `flutter_native_splash` for iOS

**Specific Changes**:
4. **Enable iOS splash generation** (optional): Change `ios: false` to `ios: true` in the `flutter_native_splash` section. This allows the package to auto-generate matching splash assets on `dart run flutter_native_splash:create`. However, since we are manually fixing the assets, this is optional and only useful for future maintainability.

---

**File**: `ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json`

**Change**: No changes required — the existing Contents.json already references `background.png` and `darkbackground.png` correctly.

5. **Verify Contents.json**: Confirm the asset catalog references remain valid after image replacement (no filename changes needed).

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, verify the bug exists on unfixed code by inspecting asset values, then verify the fix produces the correct color values and preserves the layout structure.

### Exploratory Bug Condition Checking

**Goal**: Confirm the bug condition exists in the unfixed code by inspecting the storyboard XML and image assets. Verify that the white color values are present.

**Test Plan**: Parse the LaunchScreen.storyboard XML and verify the backgroundColor RGB values. Inspect the LaunchBackground image pixel color. Run these checks on the UNFIXED code to confirm the root cause.

**Test Cases**:
1. **Storyboard Color Check**: Parse XML and assert backgroundColor has red=1, green=1, blue=1 (white) — confirms bug on unfixed code
2. **Background Image Color Check**: Read background.png pixel data and assert it is white/near-white — confirms bug on unfixed code
3. **Dark Background Image Check**: Read darkbackground.png pixel data and assert it is white/near-white — confirms bug on unfixed code
4. **Flutter Native Splash Config Check**: Parse pubspec.yaml and confirm `ios: false` — confirms the package is not managing iOS splash

**Expected Counterexamples**:
- Storyboard backgroundColor is RGB(1, 1, 1) instead of RGB(1, 0.655, 0.149)
- Background images are white instead of #FFA726

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds (iOS launch), the fixed assets produce the expected orange background.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  storyboardColor := parseBackgroundColor("LaunchScreen.storyboard")
  ASSERT storyboardColor.red == 1.0
  ASSERT abs(storyboardColor.green - 0.655) < 0.01
  ASSERT abs(storyboardColor.blue - 0.149) < 0.01
  
  bgImageColor := readPixelColor("background.png", 0, 0)
  ASSERT bgImageColor == RGB(255, 167, 38)
  
  darkBgImageColor := readPixelColor("darkbackground.png", 0, 0)
  ASSERT darkBgImageColor == RGB(255, 167, 38)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed assets produce the same result as the original — specifically that the layout, LaunchImage, and Android config are unchanged.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT storyboardViewHierarchy_fixed == storyboardViewHierarchy_original
  ASSERT launchImageConstraints_fixed == launchImageConstraints_original
  ASSERT androidSplashConfig_fixed == androidSplashConfig_original
  ASSERT dartInitialScreenBehavior_fixed == dartInitialScreenBehavior_original
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It can generate various storyboard parse scenarios to verify structure is unchanged
- It catches unintended modifications to constraints or view hierarchy
- It provides strong guarantees that only the color values changed

**Test Plan**: Observe the storyboard structure on UNFIXED code (constraints, view IDs, image references), then write tests to verify these remain identical after the fix.

**Test Cases**:
1. **LaunchImage Constraints Preservation**: Verify all 8 constraints in the storyboard remain identical after the fix (IDs, attributes, relationships)
2. **View Hierarchy Preservation**: Verify the two imageView subviews (LaunchBackground + LaunchImage) remain in the same order with same IDs
3. **Android Config Preservation**: Verify no files in `android/` directory are modified
4. **Dart InitialScreen Preservation**: Verify `lib/main.dart` InitialScreen widget code is unchanged

### Unit Tests

- Parse LaunchScreen.storyboard XML and assert backgroundColor RGB matches #FFA726
- Validate background.png is a valid PNG with pixel color RGB(255, 167, 38)
- Validate darkbackground.png is a valid PNG with pixel color RGB(255, 167, 38)
- Assert storyboard constraint count and IDs are unchanged

### Property-Based Tests

- Generate random XML attribute modifications and verify only backgroundColor values differ between original and fixed storyboard
- Generate random pixel coordinates on the background images and verify all pixels are #FFA726 (solid color check)
- Verify that for any storyboard element that is NOT the backgroundColor, the fixed version equals the original

### Integration Tests

- Build the iOS app and capture a screenshot of the launch screen to verify orange background
- Verify the app transitions smoothly from native splash to Dart splash without visible flash
- Verify Android build is unaffected by running Android integration tests
