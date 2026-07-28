import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/widgets/challenge_icon_widget.dart';
import 'package:seventy_five_hard_tracker/services/challenge_icon_service.dart';
import 'package:seventy_five_hard_tracker/core/services/dynamic_color_service.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/widgets/regular_tasks/regular_task_sheet_helpers.dart';


class AddRegularTaskSheet extends StatefulWidget {
  final RegularTaskBloc bloc;
  const AddRegularTaskSheet({super.key, required this.bloc});

  @override
  State<AddRegularTaskSheet> createState() => _AddRegularTaskSheetState();
}

class _AddRegularTaskSheetState extends State<AddRegularTaskSheet>
    with RegularTaskSheetHelpers {
  final _controller = TextEditingController();
  late Challenge _challenge;
  String? _taskNameError;
  AccountabilityPartner? _selectedPartner;
  List<AccountabilityPartner> _availablePartners = [];

  @override
  Challenge get sheetChallenge => _challenge;
  @override
  set sheetChallenge(Challenge value) => _challenge = value;

  @override
  void initState() {
    super.initState();
    _challenge = Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      taskType: 'regular',
      category: 'general',
      reminderType: 'once',
      isReminderEnabled: false,
      showInRegularTab: true,
    );
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    try {
      final partners = await AccountabilityService().fetchMyPartnerships();
      if (!mounted) return;
      setState(() {
        _availablePartners = partners
            .where((p) => p.status == PartnershipStatus.accepted)
            .toList();
      });
    } catch (e) {
      // Degrade gracefully — partner picker will show empty list
      debugPrint('[AddRegularTaskSheet] Failed to load partners: $e');
    }
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
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.add_task, color: Colors.orange[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'New Regular Task',
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
                      // Icon + Name row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon picker
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
                          // Task name
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
                                      hintText: 'e.g., "Drink 3L water daily"',
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
                                      // Auto-detect icon
                                      if (value.isNotEmpty && !_hasCustomIcon) {
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
                                              iconColor:
                                                  dynamicColor.toARGB32(),
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
                        // Ready badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[600], size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Regular task — no reset on miss',
                                style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Reminder button
                        GestureDetector(
                          onTap: showReminderSetup,
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
                                        : '⚠ Set Reminder (Required)',
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
                        // ── Accountability Partner picker ──────
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _availablePartners.isEmpty
                              ? null
                              : _showPartnerPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedPartner != null
                                  ? Colors.blue[50]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedPartner != null
                                    ? Colors.blue[300]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 18,
                                  color: _selectedPartner != null
                                      ? Colors.blue[600]
                                      : Colors.grey[500],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedPartner != null
                                        ? '👥 ${_selectedPartner!.partnerName}'
                                        : _availablePartners.isEmpty
                                            ? 'No partners yet'
                                            : 'Assign accountability partner (optional)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedPartner != null
                                          ? Colors.blue[700]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                if (_selectedPartner != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedPartner = null),
                                    child: Icon(Icons.close,
                                        size: 16, color: Colors.grey[400]),
                                  )
                                else
                                  Icon(Icons.chevron_right,
                                      size: 18, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Create button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _challenge.title.trim().isEmpty ||
                            _taskNameError != null
                        ? null
                        : (!_challenge.isReminderEnabled ||
                                _challenge.reminderTime == null)
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Please set a reminder before creating the task'),
                                    backgroundColor: Colors.red[600],
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            : _createTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_challenge.title.trim().isNotEmpty &&
                              _taskNameError == null &&
                              _challenge.isReminderEnabled &&
                              _challenge.reminderTime != null)
                          ? Colors.orange[600]
                          : Colors.grey[400],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Create Task',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (_challenge.title.trim().isNotEmpty &&
                                  _taskNameError == null &&
                                  _challenge.isReminderEnabled &&
                                  _challenge.reminderTime != null)
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

  void _showPartnerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Assign Accountability Partner',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'They will be held accountable for this task',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ..._availablePartners.map((p) => ListTile(
                  leading:
                      Text(p.role.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.partnerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.role.label),
                  trailing: _selectedPartner?.id == p.id
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() => _selectedPartner = p);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _createTask() {
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

    // Convert the Challenge form data to a RegularTask
    final taskId = _challenge.id.isNotEmpty
        ? _challenge.id
        : DateTime.now().millisecondsSinceEpoch.toString();
    final regularTask = RegularTask(
      id: taskId,
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
      createdAt: DateTime.now(),
    );
    widget.bloc.add(AddRegularTask(regularTask));

    // If an accountability partner was selected, create the accountability task
    if (_selectedPartner != null && _selectedPartner!.partnerUid != null) {
      AccountabilityService().createAccountabilityTask(
        accountableUid: _selectedPartner!.partnerUid!,
        accountableName: _selectedPartner!.partnerName,
        partnershipId: _selectedPartner!.id,
        title: sanitizedTitle,
        challengeId: taskId,
      );
    }

    Navigator.pop(context);
  }
}

