# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - iOS Native Splash White Background
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists (white background instead of orange)
  - **Scoped PBT Approach**: Scope the property to the concrete failing case — the LaunchScreen.storyboard backgroundColor and LaunchBackground image pixel colors
  - Write a property-based test (Dart test using `flutter_test`) that:
    - Parses `ios/Runner/Base.lproj/LaunchScreen.storyboard` XML
    - Extracts the `<color key="backgroundColor" .../>` element's red, green, blue attributes
    - Asserts red == 1.0, abs(green - 0.655) < 0.01, abs(blue - 0.149) < 0.01 (i.e., matches #FFA726)
    - Reads `ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png` pixel data and asserts RGB(255, 167, 38)
    - Reads `ios/Runner/Assets.xcassets/LaunchBackground.imageset/darkbackground.png` pixel data and asserts RGB(255, 167, 38)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (storyboard has white RGB 1,1,1 and images are white — this proves the bug exists)
  - Document counterexamples: storyboard backgroundColor is RGB(1, 1, 1) instead of RGB(1, 0.655, 0.149); background images are white instead of #FFA726
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Layout, Hierarchy, and Cross-Platform Config Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe on UNFIXED code:
    - Storyboard has 8 constraints with specific IDs: 3T2-ad-Qdv, RPx-PI-7Xg, SdS-ul-q2q, Swv-Gf-Rwn, TQA-XW-tRk, duK-uY-Gun, kV7-tw-vXt, xPn-NY-SIU
    - Storyboard has 2 imageView subviews: tWc-Dq-wcI (LaunchBackground) and YRO-k0-Ey4 (LaunchImage)
    - LaunchImage imageView has contentMode="center" and is opaque="NO"
    - LaunchBackground imageView has contentMode="scaleToFill"
    - `android/` directory files are not modified (check key files like AndroidManifest.xml)
    - `lib/main.dart` InitialScreen widget code is unchanged
  - Write property-based test (Dart test using `flutter_test`) that:
    - Parses storyboard XML and asserts all 8 constraint IDs are present and unchanged
    - Asserts view hierarchy: 2 imageView subviews in correct order with correct IDs
    - Asserts LaunchImage contentMode is "center" and LaunchBackground contentMode is "scaleToFill"
    - Asserts `ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json` structure is unchanged (references background.png and darkbackground.png)
    - Asserts `lib/main.dart` contains the InitialScreen class with AppColors.primary gradient
    - Asserts `pubspec.yaml` flutter_native_splash section still has `android: false` (Android config unchanged)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 3. Fix iOS native splash screen background color

  - [x] 3.1 Update LaunchScreen.storyboard background color to #FFA726
    - Change `<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>` to `<color key="backgroundColor" red="1" green="0.654901960784314" blue="0.149019607843137" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>`
    - This sets the fallback background color to match the Dart splash primary color
    - _Bug_Condition: isBugCondition(input) where input.platform == 'iOS' AND nativeSplashBackgroundColor != '#FFA726'_
    - _Expected_Behavior: backgroundColor matches RGB(1.0, 0.655, 0.149) — hex #FFA726_
    - _Preservation: Storyboard view hierarchy, constraints, and image references remain unchanged_
    - _Requirements: 2.1_

  - [x] 3.2 Replace background.png with solid #FFA726 orange image
    - Generate a 1×1 pixel PNG with color RGB(255, 167, 38) — hex #FFA726
    - Overwrite `ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png`
    - _Bug_Condition: LaunchBackground image is white instead of #FFA726_
    - _Expected_Behavior: background.png pixel color is RGB(255, 167, 38)_
    - _Preservation: Contents.json references remain valid, filename unchanged_
    - _Requirements: 2.2_

  - [x] 3.3 Replace darkbackground.png with solid #FFA726 orange image
    - Generate a 1×1 pixel PNG with color RGB(255, 167, 38) — hex #FFA726
    - Overwrite `ios/Runner/Assets.xcassets/LaunchBackground.imageset/darkbackground.png`
    - Using same orange for dark mode ensures consistency (Dart splash uses same color in dark mode)
    - _Bug_Condition: LaunchBackground dark image is white instead of #FFA726_
    - _Expected_Behavior: darkbackground.png pixel color is RGB(255, 167, 38)_
    - _Preservation: Contents.json references remain valid, filename unchanged_
    - _Requirements: 2.2_

  - [x] 3.4 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - iOS Native Splash Orange Background
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior (orange #FFA726 background)
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed — storyboard and images now have correct orange color)
    - _Requirements: 2.1, 2.2_

  - [x] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Layout, Hierarchy, and Cross-Platform Config Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions — constraints, view hierarchy, Android config, and Dart code unchanged)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Run full test suite to confirm both exploration and preservation tests pass
  - Verify no other tests in the project are broken by the changes
  - Ensure all tests pass, ask the user if questions arise
