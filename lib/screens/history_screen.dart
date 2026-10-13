import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_state.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import '../widgets/custom_app_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isRestarting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Challenge History',
      ),
      body: SafeArea(
        top: false,
        child: BlocListener<ChallengeBloc, ChallengeState>(
          listener: (context, state) {
            if (_isRestarting && state is ChallengeLoaded) {
              _isRestarting = false;
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (_isRestarting && state is ChallengeError) {
              _isRestarting = false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          child: BlocBuilder<ChallengeBloc, ChallengeState>(
            builder: (context, state) {
              if (state is ChallengeLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is ChallengeLoaded) {
                final completedSessions = state.allSessions
                    .where((session) => !session.isActive)
                    .toList();

                if (completedSessions.isEmpty) {
                  return _buildEmptyHistory(context);
                }

                return _buildHistoryList(context, completedSessions, state);
              }

              return _buildEmptyHistory(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 100,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No History Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete or reset a challenge to see history',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context,
      List<ChallengeSession> sessions, ChallengeLoaded state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSessionCard(context, session, state);
      },
    );
  }

  Widget _buildSessionCard(
      BuildContext context, ChallengeSession session, ChallengeLoaded state) {
    final isCompleted = session.isCompleted;
    final duration = session.endDate != null
        ? session.endDate!.difference(session.startDate).inDays + 1
        : 0;
    final resetModeLabel = session.resetMode == 'soft' ? 'Soft' : 'Hard';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          isCompleted ? Icons.emoji_events : Icons.refresh,
          color: isCompleted ? Colors.amber : Colors.red,
          size: 32,
        ),
        title: Text(
          isCompleted ? 'Completed Challenge' : 'Reset Challenge',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCompleted ? Colors.green : Colors.red,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Started: ${DateFormat('MMM d, yyyy').format(session.startDate)}'),
            if (session.endDate != null)
              Text(
                  'Ended: ${DateFormat('MMM d, yyyy').format(session.endDate!)}'),
            Text('Duration: $duration days'),
            Text(
                'Mode: $resetModeLabel • Target: ${session.totalDaysTarget} days'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Challenges:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...session.challenges.map(
                    (challenge) => _buildChallengeDetail(context, challenge)),
                if (!isCompleted) ...[
                  const SizedBox(height: 16),
                  _buildResetInfo(session),
                ] else ...[
                  const SizedBox(height: 16),
                  _buildCompletionInfo(session),
                ],
                const SizedBox(height: 16),
                _buildSessionStats(context, session, duration),
                const SizedBox(height: 16),
                _buildRestartButton(session, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeDetail(BuildContext context, Challenge challenge) {
    final taskTypeLabel = challenge.taskType == 'hard'
        ? 'Hard'
        : challenge.taskType == 'soft'
            ? 'Soft'
            : 'Regular';
    final taskTypeColor = challenge.taskType == 'hard'
        ? Colors.red
        : challenge.taskType == 'soft'
            ? Colors.orange
            : Colors.blue;

    String reminderSummary;
    if (challenge.isReminderEnabled && challenge.reminderTime != null) {
      reminderSummary =
          'Reminder: ${challenge.reminderTime} (${challenge.reminderType})';
    } else {
      reminderSummary = 'No reminder';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: taskTypeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              taskTypeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: taskTypeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${challenge.category} • $reminderSummary',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetInfo(ChallengeSession session) {
    final resetDay = session.currentDay > 0 ? session.currentDay : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reset Reason:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session.failureReason ?? 'Unknown reason',
            style: TextStyle(color: Colors.red[700]),
          ),
          if (resetDay != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reset on Day: $resetDay',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ],
          if (session.failedChallenges != null &&
              session.failedChallenges!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Failed Tasks:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.failedChallenges!.join(', '),
              style: TextStyle(color: Colors.red[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionInfo(ChallengeSession session) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Challenge Completed!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  'Full ${session.totalDaysTarget}-day duration completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[700], size: 28),
        ],
      ),
    );
  }

  Widget _buildRestartButton(ChallengeSession session, ChallengeLoaded state) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: 'Restart Challenge',
        hint: 'Restarts this challenge session with the same configuration',
        child: ElevatedButton.icon(
          onPressed: () => _onRestartTapped(session, state),
          icon: const Icon(Icons.replay, color: Colors.white),
          label: const Text(
            'Restart Challenge',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7918),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  void _onRestartTapped(ChallengeSession session, ChallengeLoaded state) {
    if (state.hasActiveSession) {
      _showConfirmationDialog(session);
    } else {
      _dispatchRestart(session.id);
    }
  }

  void _showConfirmationDialog(ChallengeSession session) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Active Challenge in Progress'),
          content: const Text(
            'You have an active challenge in progress. Ending it will mark it as incomplete. Do you want to end your current challenge and restart this one?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _dispatchRestart(session.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7918),
              ),
              child: const Text(
                'End & Restart',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _dispatchRestart(String sessionId) {
    setState(() {
      _isRestarting = true;
    });
    context.read<ChallengeBloc>().add(RestartFromHistory(sessionId));
  }

  Widget _buildSessionStats(
      BuildContext context, ChallengeSession session, int duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatColumn(
          context,
          'Days Completed',
          duration.toString(),
          Icons.calendar_today,
        ),
        _buildStatColumn(
          context,
          'Tasks',
          session.challenges.length.toString(),
          Icons.task_alt,
        ),
        _buildStatColumn(
          context,
          'Success Rate',
          session.isCompleted
              ? '100%'
              : '${((duration / 75) * 100).toStringAsFixed(1)}%',
          Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildStatColumn(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
