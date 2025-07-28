import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/challenge_bloc.dart';
import '../bloc/challenge_state.dart';
import '../bloc/challenge_event.dart';
import '../services/quotes_service.dart';
import '../widgets/custom_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final QuotesService _quotesService = QuotesService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
      ),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          if (state is ChallengeLoaded && state.hasActiveSession) {
            return _buildActiveSessionSettings(state);
          }
          return _buildGeneralSettings();
        },
      ),
    );
  }

  Widget _buildActiveSessionSettings(ChallengeLoaded state) {
    final session = state.activeSession!;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Challenge Reminders Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Reminders',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set custom reminder times for each of your challenges',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...session.challenges.map((challenge) => 
                  _buildReminderTile(challenge)
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Motivational Quotes Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Motivation',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get inspired with daily motivational quotes at 8:00 AM',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showRandomQuote,
                  icon: const Icon(Icons.format_quote),
                  label: const Text('Preview Quote'),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Danger Zone
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danger Zone',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'These actions cannot be undone',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showResetConfirmation,
                    icon: const Icon(Icons.refresh, color: Colors.red),
                    label: const Text(
                      'Reset Current Challenge',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About 75 Hard Challenge',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The 75 Hard Challenge is a mental toughness program that requires you to complete specific daily tasks for 75 consecutive days.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rules:\n'
                  '• Complete ALL your daily tasks every day\n'
                  '• Miss any task = Start over from Day 1\n'
                  '• No modifications once started\n'
                  '• Track your progress daily',
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showRandomQuote,
                  icon: const Icon(Icons.format_quote),
                  label: const Text('Get Motivated'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderTile(challenge) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(challenge.title),
        subtitle: challenge.isReminderEnabled && challenge.reminderTime != null
            ? Text('Reminder at ${challenge.reminderTime}')
            : const Text('No reminder set'),
        trailing: Switch(
          value: challenge.isReminderEnabled,
          onChanged: (enabled) {
            if (enabled) {
              _showTimePickerDialog(challenge);
            } else {
              context.read<ChallengeBloc>().add(
                UpdateChallengeReminder(
                  challengeId: challenge.id,
                  isEnabled: false,
                ),
              );
            }
          },
        ),
        onTap: challenge.isReminderEnabled 
            ? () => _showTimePickerDialog(challenge)
            : null,
      ),
    );
  }

  void _showTimePickerDialog(challenge) {
    final currentTime = challenge.reminderTime != null
        ? TimeOfDay(
            hour: int.parse(challenge.reminderTime!.split(':')[0]),
            minute: int.parse(challenge.reminderTime!.split(':')[1]),
          )
        : const TimeOfDay(hour: 9, minute: 0);

    showTimePicker(
      context: context,
      initialTime: currentTime,
    ).then((selectedTime) {
      if (selectedTime != null && mounted) {
        final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
        context.read<ChallengeBloc>().add(
          UpdateChallengeReminder(
            challengeId: challenge.id,
            reminderTime: timeString,
            isEnabled: true,
          ),
        );
      }
    });
  }

  void _showRandomQuote() async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final quote = await _quotesService.getMotivationalQuote();
      if (!mounted) return;
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daily Motivation'),
          content: Text(
            quote,
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Thanks!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load quote. Check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Challenge?'),
        content: const Text(
          'Are you sure you want to reset your current challenge? This will end your current session and you\'ll need to start over from Day 1.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<ChallengeBloc>().add(
                const ResetChallenge(
                  reason: 'Manual reset by user',
                  failedChallenges: [],
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
