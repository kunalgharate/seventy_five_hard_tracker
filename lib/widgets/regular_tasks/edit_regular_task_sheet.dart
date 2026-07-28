import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/widgets/challenge_icon_widget.dart';
import 'package:seventy_five_hard_tracker/widgets/icon_picker_widget.dart';
import 'package:seventy_five_hard_tracker/widgets/reminder_bottom_sheet.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';


class EditRegularTaskSheet extends StatefulWidget {
  final RegularTaskBloc bloc;
  final RegularTask task;
  const EditRegularTaskSheet({super.key, required this.bloc, required this.task});

  @override
  State<EditRegularTaskSheet> createState() => _EditRegularTaskSheetState();
}

class _EditRegularTaskSheetState extends State<EditRegularTaskSheet> {
  late TextEditingController _controller;
  late Challenge _challenge;
  String? _taskNameError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.title);
    _challenge = widget.task.toChallenge();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCustomIcon =>
      (_challenge.imagePath != null && _challenge.imagePath!.isNotEmpty) ||
      (_challenge.iconName != null && _challenge.iconName!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit Task',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _showIconPicker,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: _hasCustomIcon
                                    ? null
                                    : LinearGradient(colors: [
                                        Colors.grey[100]!,
                                        Colors.grey[200]!
                                      ]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasCustomIcon
                                      ? Colors.blue[300]!
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: _hasCustomIcon
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ChallengeIconWidget(
                                          challenge: _challenge, size: 60),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            color: Colors.grey[500], size: 20),
                                        const SizedBox(height: 2),
                                        Text('Icon',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 9,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _taskNameError != null
                                          ? Colors.red
                                          : Colors.grey[300]!,
                                      width: _taskNameError != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    decoration: InputDecoration(
                                      hintText: 'Task name',
                                      hintStyle: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 18),
                                    ),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: (value) {
                                      setState(() {
                                        _challenge =
                                            _challenge.copyWith(title: value);
                                        _taskNameError = value.trim().isEmpty
                                            ? null
                                            : validateTaskName(value);
                                      });
                                    },
                                  ),
                                ),
                                if (_taskNameError != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4, left: 4),
                                    child: Text(
                                      _taskNameError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showReminderSetup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: (_challenge.isReminderEnabled &&
                                    _challenge.reminderTime != null)
                                ? Colors.orange[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_challenge.isReminderEnabled &&
                                      _challenge.reminderTime != null)
                                  ? Colors.orange[300]!
                                  : Colors.red[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (_challenge.isReminderEnabled &&
                                        _challenge.reminderTime != null)
                                    ? Icons.alarm_on
                                    : Icons.alarm_add,
                                size: 18,
                                color: (_challenge.isReminderEnabled &&
                                        _challenge.reminderTime != null)
                                    ? Colors.orange[600]
                                    : Colors.red[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (_challenge.isReminderEnabled &&
                                          _challenge.reminderTime != null)
                                      ? 'Reminder Set ✓'
                                      : '⚠ Set Reminder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: (_challenge.isReminderEnabled &&
                                            _challenge.reminderTime != null)
                                        ? Colors.orange[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 18,
                                  color: (_challenge.isReminderEnabled &&
                                          _challenge.reminderTime != null)
                                      ? Colors.orange[400]
                                      : Colors.red[400]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _challenge.title.trim().isEmpty ||
                            _taskNameError != null
                        ? null
                        : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _challenge.title.trim().isNotEmpty &&
                              _taskNameError == null
                          ? Colors.orange[600]
                          : Colors.grey[400],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _challenge.title.trim().isNotEmpty &&
                                  _taskNameError == null
                              ? Colors.white
                              : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IconPickerWidget(
        selectedIconName: _challenge.iconName,
        selectedImagePath: _challenge.imagePath,
        onSelectionChanged: (iconName, imagePath) {
          setState(() {
            _challenge = Challenge(
              id: _challenge.id,
              title: _challenge.title,
              reminderTime: _challenge.reminderTime,
              isReminderEnabled: _challenge.isReminderEnabled,
              imagePath: imagePath,
              iconName: iconName,
              iconColor: _challenge.iconColor,
              category: _challenge.category,
              taskType: _challenge.taskType,
              reminderType: _challenge.reminderType,
              reminderStartHour: _challenge.reminderStartHour,
              reminderEndHour: _challenge.reminderEndHour,
              allowNightReminders: _challenge.allowNightReminders,
              reminderIntervalMinutes: _challenge.reminderIntervalMinutes,
              photoRequired: _challenge.photoRequired,
              showInRegularTab: _challenge.showInRegularTab,
            );
          });
        },
      ),
    );
  }

  void _showReminderSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(
        challenge: _challenge,
        onSave: (updated) {
          setState(() => _challenge = updated);
        },
      ),
    );
  }

  void _saveChanges() {
    // Validate task name
    final validationError = validateTaskName(_challenge.title);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Sanitize the title
    final sanitizedTitle = sanitizeTaskName(_challenge.title);

    final updatedTask = RegularTask(
      id: widget.task.id,
      title: sanitizedTitle,
      reminderTime: _challenge.reminderTime,
      isReminderEnabled: _challenge.isReminderEnabled,
      imagePath: _challenge.imagePath,
      iconName: _challenge.iconName,
      iconColor: _challenge.iconColor,
      category: _challenge.category,
      reminderType: _challenge.reminderType,
      reminderStartHour: _challenge.reminderStartHour,
      reminderEndHour: _challenge.reminderEndHour,
      allowNightReminders: _challenge.allowNightReminders,
      reminderIntervalMinutes: _challenge.reminderIntervalMinutes,
      createdAt: widget.task.createdAt,
    );
    widget.bloc.add(UpdateRegularTask(updatedTask));

    // If reminder settings changed, dispatch reminder update to schedule/cancel
    final reminderChanged = _challenge.isReminderEnabled != widget.task.isReminderEnabled ||
        _challenge.reminderTime != widget.task.reminderTime ||
        _challenge.reminderType != widget.task.reminderType ||
        _challenge.reminderStartHour != widget.task.reminderStartHour ||
        _challenge.reminderEndHour != widget.task.reminderEndHour ||
        _challenge.reminderIntervalMinutes != widget.task.reminderIntervalMinutes;
    if (reminderChanged) {
      widget.bloc.add(UpdateRegularTaskReminder(updatedTask));
    }

    Navigator.pop(context);
  }
}
