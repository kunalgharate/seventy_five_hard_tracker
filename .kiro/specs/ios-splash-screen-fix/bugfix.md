# Bugfix Requirements Document

## Introduction

The app displays two separate splash screens on iOS in sequence: first the native iOS LaunchScreen (white background) from `LaunchScreen.storyboard`, then the custom Dart `InitialScreen` (orange gradient with logo). This creates a jarring "double splash" effect where the user sees a white flash before the orange splash appears. The native LaunchScreen background color should match the Dart splash's primary color (#FFA726) so the transition is seamless.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the app launches on iOS THEN the system displays a native LaunchScreen with a white background color (RGB 1,1,1) before transitioning to the custom Dart splash screen with an orange gradient, creating a visible white-to-orange flash

1.2 WHEN the app launches on iOS with the LaunchBackground image visible THEN the system shows a background image that does not match the orange (#FFA726) primary color of the custom Dart splash screen

### Expected Behavior (Correct)

2.1 WHEN the app launches on iOS THEN the system SHALL display a native LaunchScreen with a background color matching the Dart splash primary color (#FFA726, RGB 1.0/0.655/0.149) so the transition to the custom Dart splash is seamless with no visible color flash

2.2 WHEN the app launches on iOS with the LaunchBackground image visible THEN the system SHALL show a background that is consistent with the orange (#FFA726) primary color, eliminating any visual discontinuity during the transition to the Dart splash screen

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the app launches on iOS THEN the system SHALL CONTINUE TO display the LaunchImage (app logo) centered on the native splash screen

3.2 WHEN the app launches on iOS and the native splash completes THEN the system SHALL CONTINUE TO transition to the custom Dart InitialScreen which displays the full orange gradient with the logo for 3 seconds before navigating to the home screen

3.3 WHEN the app launches on Android THEN the system SHALL CONTINUE TO use the existing splash screen configuration without any changes

3.4 WHEN the app launches on iOS THEN the system SHALL CONTINUE TO show the native LaunchScreen storyboard layout structure (LaunchBackground image behind LaunchImage) without altering the view hierarchy
