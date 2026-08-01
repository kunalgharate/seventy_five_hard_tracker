import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/core/services/dynamic_color_service.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/services/challenge_icon_service.dart';
import 'challenge_icon_widget.dart';
import 'icon_picker_widget.dart';
import 'reminder_bottom_sheet.dart';

/// Bottom sheet to add an additional task to an already-started 75 Hard
/// challenge. Dispatches [AddChallengeToSession] so the new task becomes part
/// of the active session and today's progress.
class AddChallengeSheet extends StatefulWidget {
  const AddChallengeSheet({super.key});

  @override
  State<AddChallengeSheet> createState() => _AddChallengeSheetState();
}

class _AddChallengeSheetState extends State<AddChallengeSheet> {
  final _controller = TextEditingController();
  late Challenge _challenge;
  String? _taskNameError;

  @override
  void initState() {
    super.initState();
    _challenge = Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      category: 'general',
      taskType: 'hard',
      reminderType: 'once',
      reminderStartHour: 8,
      reminderEndHour: 22,
      allowNightReminders: true,
      isReminderEnabled: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCustomIcon =>
      (_challenge.imagePath != null && _challenge.imagePath!.isNotEmpty) ||
      (_challenge.iconName != null && _challenge.iconName!.isNotEmpty);

  bool get _hasReminder =>
      _challenge.isReminderEnabled && _challenge.reminderTime != null;

  bool get _canSubmit =>
      _challenge.title.trim().isNotEmpty &&
      _taskNameError == null &&
      _hasReminder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.add_task, color: Colors.orange[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add New Task',
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
                                        !_hasCustomIcon) {
                                      final iconData =
                                          ChallengeIconService.findBestIcon(
                                              value);
                                      if (iconData != null) {
                                        final dynamicColor =
                                            DynamicColorService
                                                .getColorForText(value);
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
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _showReminderSetup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: _hasReminder ? Colors.orange[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _hasReminder
                                ? Colors.orange[300]!
                                : Colors.red[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _hasReminder ? Icons.alarm_on : Icons.alarm_add,
                              size: 18,
                              color: _hasReminder
                                  ? Colors.orange[600]
                                  : Colors.red[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _hasReminder
                                    ? 'Reminder Set ✓'
                                    : '⚠ Set Reminder (Required)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _hasReminder
                                      ? Colors.orange[700]
                                      : Colors.red[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 18,
                                color: _hasReminder
                                    ? Colors.orange[400]
                                    : Colors.red[400]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This task will be added to your current 75 Hard challenge and tracked from today.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4,
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
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? Colors.orange[600] : null,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Add Task',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      builder: (context) => ReminderBottomSheet(
        challenge: _challenge,
        onSave: (updated) {
          setState(() => _challenge = updated);
        },
      ),
    );
  }

  void _submit() {
    final challenge = _challenge.copyWith(
      title: sanitizeTaskName(_challenge.title),
    );
    context.read<ChallengeBloc>().add(AddChallengeToSession(challenge));
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Task added to your challenge!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }
}
