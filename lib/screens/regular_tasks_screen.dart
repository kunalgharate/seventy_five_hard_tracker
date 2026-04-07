import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/challenge_bloc.dart';
import '../bloc/challenge_state.dart';
import '../bloc/challenge_event.dart';
import '../models/challenge.dart';
import '../models/daily_progress.dart';
import '../widgets/daily_task_card.dart';
import '../widgets/challenge_icon_widget.dart';
import '../widgets/icon_picker_widget.dart';
import '../widgets/reminder_bottom_sheet.dart';
import '../services/challenge_icon_service.dart';
import '../services/dynamic_color_service.dart';

class RegularTasksScreen extends StatelessWidget {
  const RegularTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChallengeBloc, ChallengeState>(
      builder: (context, state) {
        final regularTasks = (state is ChallengeLoaded)
            ? (state.activeSession?.challenges.where((c) => c.taskType == 'regular').toList() ?? [])
            : <Challenge>[];

        final today = DateTime.now();
        final allProgress = (state is ChallengeLoaded) ? state.currentProgress : <DailyProgress>[];
        final todayProgress = allProgress.where((p) =>
            p.date.year == today.year &&
            p.date.month == today.month &&
            p.date.day == today.day).firstOrNull;

        final showList = regularTasks.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('Regular Tasks', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: state is ChallengeLoading
              ? const Center(child: CircularProgressIndicator())
              : showList
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: regularTasks.length,
                      itemBuilder: (context, index) {
                        final challenge = regularTasks[index];
                        final isCompleted = todayProgress?.challengeCompletions[challenge.id] ?? false;
                        final stats = _calcStats(challenge.id, allProgress);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              DailyTaskCard(
                                challenge: challenge,
                                isCompleted: isCompleted,
                                isEditable: true,
                                onToggle: (completed) {
                                  context.read<ChallengeBloc>().add(
                                    UpdateDailyProgress(date: today, challengeId: challenge.id, isCompleted: completed),
                                  );
                                },
                                onReminderUpdate: (updatedChallenge) {
                                  context.read<ChallengeBloc>().add(UpdateChallenge(updatedChallenge));
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildStatsRow(stats),
                            ],
                          ),
                        );
                      },
                    )
                  : _buildEmptyState(context),
          floatingActionButton: FloatingActionButton(
            heroTag: 'addRegularTask',
            onPressed: () => _showAddTaskSheet(context),
            backgroundColor: Colors.orange[600],
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  _TaskStats _calcStats(String challengeId, List<DailyProgress> allProgress) {
    // Sort progress by date ascending
    final sorted = [...allProgress];
    sorted.sort((a, b) => a.date.compareTo(b.date));

    int completed = 0;
    int missed = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;

    for (final p in sorted) {
      final done = p.challengeCompletions[challengeId] ?? false;
      if (done) {
        completed++;
        tempStreak++;
        if (tempStreak > bestStreak) bestStreak = tempStreak;
      } else {
        missed++;
        tempStreak = 0;
      }
    }
    currentStreak = tempStreak;

    return _TaskStats(
      completed: completed,
      missed: missed,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      total: sorted.length,
    );
  }

  Widget _buildStatsRow(_TaskStats stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('🔥', '${stats.currentStreak}', 'Streak'),
          _divider(),
          _statItem('🏆', '${stats.bestStreak}', 'Best'),
          _divider(),
          _statItem('✅', '${stats.completed}', 'Done'),
          _divider(),
          _statItem('❌', '${stats.missed}', 'Missed'),
        ],
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text('$emoji $value',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: Colors.grey[300]);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text('No Regular Tasks',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            Text(
              'Regular tasks are optional habits you can track without the pressure of resetting.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddTaskSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Regular Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddRegularTaskSheet(bloc: context.read<ChallengeBloc>()),
    );
  }
}

class _AddRegularTaskSheet extends StatefulWidget {
  final ChallengeBloc bloc;
  const _AddRegularTaskSheet({required this.bloc});

  @override
  State<_AddRegularTaskSheet> createState() => _AddRegularTaskSheetState();
}

class _AddRegularTaskSheetState extends State<_AddRegularTaskSheet> {
  final _controller = TextEditingController();
  late Challenge _challenge;

  @override
  void initState() {
    super.initState();
    _challenge = Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      taskType: 'regular',
      category: 'general',
      reminderType: 'once',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.add_task, color: Colors.orange[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('New Regular Task',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                        onTap: _showIconPicker,
                        child: Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            gradient: _hasCustomIcon ? null : LinearGradient(colors: [Colors.grey[100]!, Colors.grey[200]!]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _hasCustomIcon ? Colors.blue[300]! : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: _hasCustomIcon
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ChallengeIconWidget(challenge: _challenge, size: 60),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[500], size: 20),
                                    const SizedBox(height: 2),
                                    Text('Icon', style: TextStyle(color: Colors.grey[600], fontSize: 9, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Task name
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'e.g., "Drink 3L water daily"',
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            ),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: (value) {
                              setState(() {
                                _challenge = _challenge.copyWith(title: value);
                              });
                              // Auto-detect icon
                              if (value.isNotEmpty && !_hasCustomIcon) {
                                final iconData = ChallengeIconService.findBestIcon(value);
                                if (iconData != null) {
                                  final dynamicColor = DynamicColorService.getColorForText(value);
                                  setState(() {
                                    _challenge = _challenge.copyWith(
                                      iconName: iconData.name,
                                      iconColor: dynamicColor.value,
                                    );
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_challenge.title.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Ready badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                          const SizedBox(width: 6),
                          Text('Regular task — no reset on miss',
                            style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Reminder button
                    GestureDetector(
                      onTap: _showReminderSetup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                              ? Colors.orange[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                                ? Colors.orange[300]! : Colors.red[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                                  ? Icons.alarm_on : Icons.alarm_add,
                              size: 18,
                              color: (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                                  ? Colors.orange[600] : Colors.red[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                                    ? 'Reminder Set ✓' : '⚠ Set Reminder (Required)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                                      ? Colors.orange[700] : Colors.red[700],
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 18,
                              color: (_challenge.isReminderEnabled && _challenge.reminderTime != null)
                                  ? Colors.orange[400] : Colors.red[400]),
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
                onPressed: _challenge.title.trim().isEmpty ? null : _createTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Task',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
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
        selectedColor: _challenge.iconColor,
        onSelectionChanged: (iconName, imagePath, color) {
          setState(() {
            _challenge = _challenge.copyWith(
              iconName: iconName,
              imagePath: imagePath,
              iconColor: color,
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

  void _createTask() {
    widget.bloc.add(AddChallengeToSession(_challenge));
    Navigator.pop(context);
  }
}

class _TaskStats {
  final int completed;
  final int missed;
  final int currentStreak;
  final int bestStreak;
  final int total;

  const _TaskStats({
    required this.completed,
    required this.missed,
    required this.currentStreak,
    required this.bestStreak,
    required this.total,
  });
}
