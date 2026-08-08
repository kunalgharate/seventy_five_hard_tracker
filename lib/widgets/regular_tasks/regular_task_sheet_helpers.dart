import 'package:flutter/material.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/widgets/icon_picker_widget.dart';
import 'package:seventy_five_hard_tracker/widgets/reminder_bottom_sheet.dart';

/// Shared helpers for add/edit regular task sheets to avoid code duplication.
mixin RegularTaskSheetHelpers<T extends StatefulWidget> on State<T> {
  /// Override in the using class to get/set the challenge being edited.
  Challenge get sheetChallenge;
  set sheetChallenge(Challenge value);

  /// Hook invoked after the user manually picks or clears an icon/image.
  /// Sheets that auto-derive an icon from the title should override this to
  /// stop overriding the user's explicit choice.
  void onUserPickedIcon() {}

  void showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IconPickerWidget(
        selectedIconName: sheetChallenge.iconName,
        selectedImagePath: sheetChallenge.imagePath,
        onSelectionChanged: (iconName, imagePath) {
          setState(() {
            // Store '' (not null) for the unselected field so the previous
            // value is always cleared instead of being kept by copyWith.
            sheetChallenge = sheetChallenge.copyWith(
              iconName: iconName ?? '',
              imagePath: imagePath ?? '',
            );
          });
          onUserPickedIcon();
        },
      ),
    );
  }

  void showReminderSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(
        challenge: sheetChallenge,
        onSave: (updated) {
          setState(() => sheetChallenge = updated);
        },
      ),
    );
  }
}
