import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/challenge_bloc.dart';
import '../bloc/challenge_state.dart';
import '../bloc/challenge_event.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';
import '../models/challenge.dart';
import '../widgets/daily_task_card.dart';
import '../widgets/progress_stats.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/horizontal_date_picker.dart';
import '../widgets/smooth_scroll_behavior.dart';
import '../widgets/daily_journal_widget.dart';
import '../services/notification_service.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    context.read<ChallengeBloc>().add(LoadChallengeData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '75 Hard Challenge',
        actions: [
          // Test notification button (temporary for debugging)
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.orange),
            onPressed: () async {
              print('🔔 DEBUG: Test notification button pressed');
              final notificationService = NotificationService();
              
              // Show dialog with test options
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Test Notifications'),
                  content: const Text('Choose a test type:'),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await notificationService.sendTestNotification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Immediate test notification sent')),
                        );
                      },
                      child: const Text('Immediate'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await notificationService.scheduleTestNotification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test notification scheduled for 10 seconds')),
                        );
                      },
                      child: const Text('10 Seconds'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Test Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ChallengeBloc, ChallengeState>(
        listener: (context, state) {
          // Use addPostFrameCallback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return; // Safety check
            
            if (state is ChallengeError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.fixed, // Show at bottom
                  margin: null, // Remove margin to ensure bottom positioning
                ),
              );
            } else if (state is ChallengeReset) {
              _showResetDialog(state);
            } else if (state is ChallengeCompleted) {
              _showCompletionDialog(state.completedSession);
            }
          });
        },
        builder: (context, state) {
          if (state is ChallengeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChallengeLoaded) {
            if (!state.hasActiveSession) {
              return _buildNoActiveSession();
            }

            return _buildActiveSession(state);
          }

          return _buildNoActiveSession();
        },
      ),
      floatingActionButton: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          if (state is ChallengeLoaded && !state.hasActiveSession) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/onboarding');
              },
              icon: const Icon(Icons.add),
              label: const Text('Start Challenge'),
              backgroundColor: Colors.green,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNoActiveSession() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Challenge',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your 75 Hard Challenge journey!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession(ChallengeLoaded state) {
    final session = state.activeSession!;
    final daysSinceStart = DateTime.now().difference(session.startDate).inDays + 1;
    final currentDay = daysSinceStart > 75 ? 75 : daysSinceStart;

    return Column(
      children: [
        // Progress Stats
        ProgressStats(
          currentDay: currentDay,
          totalDays: 75,
          session: session,
          progress: state.currentProgress,
        ),
        
        // Calendar
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Date',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFA726),
                          ),
                        ),
                        const SizedBox(height: 12),
                        HorizontalDatePicker(
                          selectedDate: _selectedDay,
                          startDate: session.startDate,
                          endDate: session.startDate.add(const Duration(days: 74)),
                          onDateSelected: (selectedDate) {
                            print('Home screen: Date selected: $selectedDate'); // Debug print
                            setState(() {
                              _selectedDay = selectedDate;
                            });
                          },
                          completedDates: state.currentProgress
                              .where((p) => p.isCompleted)
                              .map((p) => p.date)
                              .toList(),
                          incompleteDates: state.currentProgress
                              .where((p) => !p.isCompleted)
                              .map((p) => p.date)
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        // Progress indicator for selected date
                        _buildDateProgressIndicator(state),
                      ],
                    ),
                  ),
                ),
                
                // Daily Tasks for Selected Day
                _buildDailyTasks(session, state.currentProgress),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTasks(ChallengeSession session, List<DailyProgress> allProgress) {
    final selectedProgress = allProgress
        .where((p) => _isSameDay(p.date, _selectedDay))
        .firstOrNull;

    final isToday = _isSameDay(_selectedDay, DateTime.now());
    final isFutureDate = _selectedDay.isAfter(DateTime.now());
    final isBeforeStart = _selectedDay.isBefore(session.startDate);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDay),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (selectedProgress?.isCompleted == true)
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ],
            ),
            const SizedBox(height: 16),
            
            if (isBeforeStart)
              const Text(
                'Challenge hasn\'t started yet',
                style: TextStyle(color: Colors.grey),
              )
            else if (isFutureDate)
              const Text(
                'Future date - complete today\'s tasks first!',
                style: TextStyle(color: Colors.grey),
              )
            else
              // Use original task cards with simple reminder functionality
              ...session.challenges.asMap().entries.map((entry) {
                final index = entry.key;
                final challenge = entry.value;
                final isCompleted = selectedProgress?.challengeCompletions[challenge.id] ?? false;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == session.challenges.length - 1 ? 0 : 8,
                  ),
                  child: RepaintBoundary(
                    child: DailyTaskCard(
                      challenge: challenge,
                      isCompleted: isCompleted,
                      isEditable: isToday,
                      onToggle: (completed) {
                        context.read<ChallengeBloc>().add(
                          UpdateDailyProgress(
                            date: _selectedDay,
                            challengeId: challenge.id,
                            isCompleted: completed,
                          ),
                        );
                      },
                      onReminderUpdate: (updatedChallenge) {
                        print('🔔 CALLBACK DEBUG: onReminderUpdate called');
                        print('🔔 CALLBACK DEBUG: updatedChallenge.id = ${updatedChallenge.id}');
                        print('🔔 CALLBACK DEBUG: updatedChallenge.title = ${updatedChallenge.title}');
                        print('🔔 CALLBACK DEBUG: updatedChallenge.isReminderEnabled = ${updatedChallenge.isReminderEnabled}');
                        print('🔔 CALLBACK DEBUG: updatedChallenge.reminderTime = ${updatedChallenge.reminderTime}');
                        print('🔔 CALLBACK DEBUG: Dispatching UpdateChallenge event...');
                        
                        // Update the challenge with new reminder settings
                        context.read<ChallengeBloc>().add(
                          UpdateChallenge(updatedChallenge),
                        );
                        
                        print('🔔 CALLBACK DEBUG: UpdateChallenge event dispatched');
                      },
                    ),
                  ),
                );
              }),
            
            const SizedBox(height: 16),
            
            // Daily Journal
            if (!isBeforeStart && !isFutureDate)
              DailyJournalWidget(
                selectedDate: _selectedDay,
                existingNote: selectedProgress?.journalNote,
                onNoteSubmitted: (note) {
                  context.read<ChallengeBloc>().add(
                    AddJournalNote(date: _selectedDay, note: note),
                  );
                },
                isEditable: isToday,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateProgressIndicator(ChallengeLoaded state) {
    final progress = state.currentProgress
        .where((p) => _isSameDay(p.date, _selectedDay))
        .firstOrNull;
    
    if (progress == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'No data for this date',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: progress.isCompleted ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: progress.isCompleted ? Colors.green[300]! : Colors.red[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            progress.isCompleted ? Icons.check_circle : Icons.cancel,
            color: progress.isCompleted ? Colors.green[600] : Colors.red[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            progress.isCompleted 
                ? 'All tasks completed!' 
                : 'Some tasks incomplete',
            style: TextStyle(
              color: progress.isCompleted ? Colors.green[700] : Colors.red[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showResetDialog(ChallengeReset state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Challenge Reset!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your challenge has been reset to Day 1.'),
            const SizedBox(height: 8),
            Text('Reason: ${state.reason}'),
            if (state.failedChallenges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Failed tasks: ${state.failedChallenges.join(', ')}'),
            ],
            const SizedBox(height: 16),
            const Text('Don\'t give up! You can start again anytime.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(ChallengeSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Congratulations! 🎉'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'You completed the 75 Hard Challenge!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You are amazing! This is a huge accomplishment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Thank You!'),
          ),
        ],
      ),
    );
  }
}
