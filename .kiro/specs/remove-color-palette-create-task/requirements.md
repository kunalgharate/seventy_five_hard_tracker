# Requirements Document

## Introduction

This feature removes the manual color palette (Color tab) from the `IconPickerWidget` used during task creation and editing flows. Currently the icon picker presents three tabs — Icons, Image, and Color — allowing users to manually select a color for their task icon. The Color tab is unnecessary because colors are already auto-assigned via `DynamicColorService` based on the task title. Removing the Color tab simplifies the UI and reduces user decision fatigue while preserving automatic color assignment.

## Glossary

- **Icon_Picker**: The `IconPickerWidget` bottom-sheet modal that allows users to choose an icon or image for a task. Currently contains three tabs: Icons, Image, and Color.
- **Color_Tab**: The third tab in the Icon_Picker that displays a grid of 19 predefined color swatches for manual color selection.
- **Auto_Color_Service**: The `DynamicColorService` that automatically assigns a color to a task based on the task title text using a hash-based algorithm.
- **Create_Task_Flow**: The bottom-sheet UI flow (`_AddRegularTaskSheet`) where users create a new regular task, including naming, icon selection, and reminder setup.
- **Edit_Task_Flow**: The bottom-sheet UI flow (`_EditRegularTaskSheet`) where users modify an existing regular task.
- **Onboarding_Flow**: The onboarding screen flow where users set up initial tasks during first-time app setup.

## Requirements

### Requirement 1: Remove Color Tab from Icon Picker

**User Story:** As a user, I want the icon picker to only show Icons and Image tabs, so that I have a simpler selection experience without an unnecessary color option.

#### Acceptance Criteria

1. THE Icon_Picker SHALL display exactly two tabs: "Icons" and "Image".
2. THE Icon_Picker SHALL NOT display a "Color" tab or any manual color selection grid.
3. WHEN the Icon_Picker is opened from the Create_Task_Flow, THE Icon_Picker SHALL display only the "Icons" and "Image" tabs.
4. WHEN the Icon_Picker is opened from the Edit_Task_Flow, THE Icon_Picker SHALL display only the "Icons" and "Image" tabs.
5. WHEN the Icon_Picker is opened from the Onboarding_Flow, THE Icon_Picker SHALL display only the "Icons" and "Image" tabs.

### Requirement 2: Preserve Automatic Color Assignment

**User Story:** As a user, I want my tasks to still have visually distinct colors, so that I can easily differentiate between tasks without manually picking colors.

#### Acceptance Criteria

1. WHEN a user types a task title in the Create_Task_Flow, THE Auto_Color_Service SHALL assign a color based on the title text.
2. WHEN a user selects an icon from the Icons tab, THE Icon_Picker SHALL retain the existing auto-assigned color or use the icon's default color.
3. THE RegularTask data model SHALL continue to store the `iconColor` field for backward compatibility with existing tasks.

### Requirement 3: Remove Color Parameter from Icon Picker Callback

**User Story:** As a developer, I want the icon picker's selection callback to stop exposing a manual color parameter, so that the interface is clean and reflects the removal of manual color selection.

#### Acceptance Criteria

1. THE Icon_Picker `onSelectionChanged` callback SHALL accept only `iconName` and `imagePath` parameters.
2. THE Icon_Picker SHALL NOT expose a `selectedColor` constructor parameter for manual color input.
3. WHEN an icon is selected, THE Icon_Picker SHALL invoke the callback with the selected icon name and a null image path.
4. WHEN an image is selected, THE Icon_Picker SHALL invoke the callback with a null icon name and the selected image path.

### Requirement 4: Maintain Existing Task Color Data

**User Story:** As a user, I want my previously created tasks to retain their assigned colors, so that my existing task list appearance remains unchanged.

#### Acceptance Criteria

1. THE RegularTask model SHALL preserve the `iconColor` field without modification.
2. WHEN an existing task with a stored `iconColor` value is displayed, THE application SHALL use the stored color value for rendering.
3. WHEN a task is edited and saved without changing the title, THE application SHALL preserve the original `iconColor` value.
