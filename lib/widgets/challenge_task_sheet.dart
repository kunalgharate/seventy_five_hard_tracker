import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/services/challenge_icon_service.dart';
import 'package:seventy_five_hard_tracker/core/services/dynamic_color_service.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';
import 'package:seventy_five_hard_tracker/widgets/challenge_icon_widget.dart';
import 'package:seventy_five_hard_tracker/widgets/regular_tasks/regular_task_sheet_helpers.dart';

class ChallengeTaskSheet extends StatefulWidget {
  final ChallengeBloc bloc;
  final Challenge? challenge;

  const ChallengeTaskSheet({super.key, required this.bloc, this.challenge});

  @override
  State<ChallengeTaskSheet> createState() => _ChallengeTaskSheetState();
}

class _ChallengeTaskSheetState extends State<ChallengeTaskSheet>
    with RegularTaskSheetHelpers {
  late final bool _isEdit;
  late Challenge _challenge;
  late final TextEditingController _controller;
  String? _taskNameError;
  bool _userPickedIcon = false;

  @override
  Challenge get sheetChallenge => _challenge;
  @override
  set sheetChallenge(Challenge value) => _challenge = value;

  @override
  void onUserPickedIcon() {
    _userPickedIcon = true;
  }

  @override
  void initState() {
    super.initState();
    _isEdit = widget.challenge != null;
    _challenge = _isEdit
        ? widget.challenge!
        : Challenge(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '',
            taskType: 'hard',
            category: 'general',
            reminderType: 'once',
            isReminderEnabled: false,
          );
    _controller = TextEditingController(text: _challenge.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCustomIcon =>
      (_challenge.imagePath != null && _challenge.imagePath!.isNotEmpty) ||
      (_challenge.iconName != null && _challenge.iconName!.isNotEmpty);

  /// A custom image is always a manual choice — never auto-derive over it.
  bool get _hasManualImage =>
      _challenge.imagePath != null && _challenge.imagePath!.isNotEmpty;

  bool get _isValid {
    if (_challenge.title.trim().isEmpty || _taskNameError != null) {
      return false;
    }
    // New tasks require a reminder. When editing, keep the task's existing
    // reminder state so tasks saved without a reminder can still be edited.
    if (_isEdit && !_challenge.isReminderEnabled) return true;
    return _challenge.isReminderEnabled && _challenge.reminderTime != null;
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.75;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool hasReminder =
        _challenge.isReminderEnabled && _challenge.reminderTime != null;

    return SafeArea(
      top: false,
      child: Container(
        height: maxHeight,
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
                  Icon(
                    _isEdit ? Icons.edit_outlined : Icons.add_task,
                    color: Colors.orange[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Task' : 'New Challenge Task',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
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
                          onTap: showIconPicker,
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., "Read 10 pages daily"',
                                    hintStyle: TextStyle(
                                        color: Colors.grey[500], fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
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
                                    if (value.isNotEmpty &&
                                        !_userPickedIcon &&
                                        !_hasManualImage) {
                                      final iconData =
                                          ChallengeIconService.findBestIcon(
                                              value);
                                      if (iconData != null) {
                                        final dynamicColor =
                                            DynamicColorService.getColorForText(
                                                value);
                                        setState(() {
                                          _challenge = _challenge.copyWith(
                                            iconName: iconData.name,
                                            iconColor: dynamicColor.toARGB32(),
                                          );
                                        });
                                      }
                                    }
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
                    if (_challenge.title.isNotEmpty &&
                        _taskNameError == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department,
                                color: Colors.orange[600], size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '75 Hard task — missing it resets your day',
                              style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: showReminderSetup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: hasReminder
                                ? Colors.orange[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasReminder
                                  ? Colors.orange[300]!
                                  : Colors.red[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasReminder ? Icons.alarm_on : Icons.alarm_add,
                                size: 18,
                                color: hasReminder
                                    ? Colors.orange[600]
                                    : Colors.red[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasReminder
                                      ? 'Reminder Set'
                                      : 'Set Reminder (Required)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: hasReminder
                                        ? Colors.orange[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 18,
                                  color: hasReminder
                                      ? Colors.orange[400]
                                      : Colors.red[400]),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                  onPressed: _isValid ? _save : _onInvalidTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isValid ? Colors.orange[600] : Colors.grey[400],
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isEdit ? 'Save Changes' : 'Add Task',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isValid ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: keyboardHeight.clamp(0.0, maxHeight * 0.75).toDouble(),
            ),
          ],
        ),
      ),
    );
  }

  void _onInvalidTap() {
    final String message;
    if (_challenge.title.trim().isEmpty) {
      message = 'Please enter a task name';
    } else if (_taskNameError != null) {
      message = _taskNameError!;
    } else {
      message = 'Please set a reminder before saving this task';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _save() {
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

    final challenge = _challenge.copyWith(
      title: sanitizeTaskName(_challenge.title),
    );
    widget.bloc.add(
      _isEdit ? UpdateChallenge(challenge) : AddChallengeToSession(challenge),
    );
    Navigator.pop(context);
  }
}
