# Requirements Document

## Introduction

Replace the pill-shaped toggle switch in the DailyTaskCard completion widget with an Apple-style rounded checkbox. The current toggle uses a 300ms sliding animation that feels sluggish. The new checkbox should provide a snappy, responsive interaction with a clean iOS-inspired aesthetic — an empty rounded outline when incomplete, and a filled green circle with a white checkmark when complete.

## Glossary

- **Completion_Checkbox**: The interactive Apple-style rounded checkbox widget that replaces the existing pill-shaped toggle in DailyTaskCard for toggling task completion state.
- **DailyTaskCard**: The card widget (`daily_task_card.dart`) that displays a single challenge task for a given day, including its title, status, and completion control.
- **Status_Indicator**: The non-interactive visual element shown on non-editable DailyTaskCard instances to communicate whether a task was completed or missed.
- **Completion_State**: A boolean value representing whether a task is marked as completed (true) or not completed (false) for a given day.

## Requirements

### Requirement 1: Render Checkbox in Default State

**User Story:** As a user, I want to see a clear empty circular outline when a task is not completed, so that I can immediately identify which tasks still need to be done.

#### Acceptance Criteria

1. WHILE Completion_State is false AND the DailyTaskCard is editable, THE Completion_Checkbox SHALL render as an empty circle with a rounded border outline.
2. THE Completion_Checkbox SHALL use a visible border color that contrasts with the card background.
3. THE Completion_Checkbox SHALL have a minimum tap target size of 44x44 logical pixels to meet accessibility guidelines.

### Requirement 2: Render Checkbox in Completed State

**User Story:** As a user, I want to see a filled green circle with a white checkmark when a task is completed, so that I get clear visual confirmation of my progress.

#### Acceptance Criteria

1. WHILE Completion_State is true AND the DailyTaskCard is editable, THE Completion_Checkbox SHALL render as a filled green circle with a white checkmark icon centered inside.
2. THE Completion_Checkbox SHALL use a green fill color consistent with the existing completion color scheme (Colors.green[600]).
3. THE Completion_Checkbox checkmark icon SHALL be white and clearly visible against the green fill.

### Requirement 3: Toggle Completion on Tap

**User Story:** As a user, I want to tap the checkbox to toggle task completion, so that I can quickly mark tasks as done or undo them.

#### Acceptance Criteria

1. WHEN the user taps the Completion_Checkbox, THE Completion_Checkbox SHALL invoke the onToggle callback with the negated Completion_State value.
2. WHILE the DailyTaskCard is not editable, THE Completion_Checkbox SHALL not be rendered; the Status_Indicator SHALL be shown instead.

### Requirement 4: Animate State Transition

**User Story:** As a user, I want the checkbox transition to feel snappy and responsive, so that the interaction feels immediate and satisfying.

#### Acceptance Criteria

1. WHEN Completion_State changes, THE Completion_Checkbox SHALL animate the transition between default and completed states within 150 milliseconds.
2. THE Completion_Checkbox SHALL use an ease-out curve for the fill and checkmark appearance animation.
3. THE Completion_Checkbox animation duration SHALL be 150 milliseconds or less, replacing the previous 300ms toggle animation.

### Requirement 5: Display Non-Editable Status Indicator

**User Story:** As a user viewing a past day, I want to see whether a task was completed or missed, so that I can review my history.

#### Acceptance Criteria

1. WHILE the DailyTaskCard is not editable AND Completion_State is true, THE Status_Indicator SHALL display a green container with a white check icon.
2. WHILE the DailyTaskCard is not editable AND Completion_State is false, THE Status_Indicator SHALL display a red container with a white close icon.
3. THE Status_Indicator SHALL not respond to tap gestures.

### Requirement 6: Maintain Existing Integration

**User Story:** As a developer, I want the new checkbox to integrate with the existing completion flow, so that no other parts of the app need to change.

#### Acceptance Criteria

1. THE Completion_Checkbox SHALL accept the same onToggle callback signature (Function(bool)) as the existing toggle widget.
2. THE Completion_Checkbox SHALL read Completion_State from the existing isCompleted property of DailyTaskCard.
3. WHEN the Completion_Checkbox triggers onToggle, THE ChallengeBloc SHALL receive an UpdateDailyProgress event with the correct date, challengeId, and isCompleted values, using the existing event dispatch path in HomeScreen.
