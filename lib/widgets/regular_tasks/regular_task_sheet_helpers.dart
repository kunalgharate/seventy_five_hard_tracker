import 'package:flutter/material.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/widgets/icon_picker_widget.dart';
import 'package:seventy_five_hard_tracker/widgets/reminder_bottom_sheet.dart';

/// Shared helpers for add/edit regular task sheets to avoid code duplication.
mixin RegularTaskSheetHelpers<T extends StatefulWidget> on State<T> {
  /// Override in the using class to get/set the challenge being edited.
  Challenge get sheetChallenge;
  set sheetChallenge(Challenge value);

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
            if (iconName == null && imagePath == null) {
              sheetChallenge =
                  sheetChallenge.copyWith(iconName: '', imagePath: '');
            } else {
              sheetChallenge = sheetChallenge.copyWith(
                  iconName: iconName, imagePath: imagePath);
            }
          });
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
