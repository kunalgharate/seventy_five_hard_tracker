# Bugfix Requirements Document

## Introduction

The reminder bottom sheet in `lib/widgets/reminder_bottom_sheet.dart` takes up too much vertical space, causing the time picker/selector to be hidden below the visible area. Users must scroll down to find and configure the reminder time, but new users are unaware that scrolling is needed. The layout needs to be made more compact so the time configuration is visible without scrolling when the bottom sheet opens.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the reminder bottom sheet opens with reminders enabled THEN the system displays the bottom sheet at 95% of screen height with excessive internal padding (20px all-around content padding, 16px padding per type option, 8px bottom margin per option), causing the time selector to be pushed below the visible fold

1.2 WHEN a user selects a reminder type (once, multiple, hourly, interval, custom) THEN the system does not visually indicate that additional time configuration exists below the fold, so new users do not realize they need to scroll down

1.3 WHEN the reminder type options are displayed THEN the system renders each option with large padding (16px all sides) and a two-line layout (title + subtitle), consuming excessive vertical space and pushing the time selector out of view

### Expected Behavior (Correct)

2.1 WHEN the reminder bottom sheet opens with reminders enabled THEN the system SHALL display the bottom sheet with a reduced height and tighter internal spacing so that both the reminder type options and the time selector are visible without scrolling on standard screen sizes

2.2 WHEN a user selects a reminder type THEN the system SHALL show the corresponding time configuration section within the initially visible area of the bottom sheet, without requiring the user to scroll

2.3 WHEN the reminder type options are displayed THEN the system SHALL render each option with compact padding and reduced spacing so that all five options plus the time selector fit within the visible area of the bottom sheet

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user taps a reminder type option THEN the system SHALL CONTINUE TO select that type and update the UI to show the corresponding configuration section

3.2 WHEN the user toggles the reminder enable/disable switch THEN the system SHALL CONTINUE TO show or hide the reminder configuration options accordingly

3.3 WHEN the user configures a time and taps the save button THEN the system SHALL CONTINUE TO save the reminder settings correctly with the proper data format (once:, multiple:, hourly:, interval:, custom: prefixes)

3.4 WHEN the user taps the close button or saves settings THEN the system SHALL CONTINUE TO dismiss the bottom sheet and return to the previous screen

3.5 WHEN reminders are disabled THEN the system SHALL CONTINUE TO display the informational message about enabling reminders
