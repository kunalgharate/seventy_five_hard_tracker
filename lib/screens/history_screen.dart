import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/challenge_bloc.dart';
import '../bloc/challenge_state.dart';
import '../models/challenge_session.dart';
import '../widgets/custom_app_bar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Challenge History',
      ),
      body: BlocBuilder<ChallengeBloc, ChallengeState>(
        builder: (context, state) {
          if (state is ChallengeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChallengeLoaded) {
            final completedSessions = state.allSessions
                .where((session) => !session.isActive)
                .toList();

            if (completedSessions.isEmpty) {
              return _buildEmptyHistory();
            }

            return _buildHistoryList(completedSessions);
          }

          return _buildEmptyHistory();
        },
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No History Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete or reset a challenge to see history',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<ChallengeSession> sessions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(ChallengeSession session) {
    final isCompleted = session.isCompleted;
    final duration = session.endDate != null
        ? session.endDate!.difference(session.startDate).inDays + 1
        : 0;

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
            Text('Started: ${DateFormat('MMM d, yyyy').format(session.startDate)}'),
            if (session.endDate != null)
              Text('Ended: ${DateFormat('MMM d, yyyy').format(session.endDate!)}'),
            Text('Duration: $duration days'),
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
                ...session.challenges.map((challenge) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box_outline_blank, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(challenge.title)),
                    ],
                  ),
                )),
                
                if (!isCompleted) ...[
                  const SizedBox(height: 16),
                  Container(
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
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
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
                          child: Text(
                            'Congratulations! You completed all 75 days!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                _buildSessionStats(session, duration),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats(ChallengeSession session, int duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatColumn(
          'Days Completed',
          duration.toString(),
          Icons.calendar_today,
        ),
        _buildStatColumn(
          'Tasks',
          session.challenges.length.toString(),
          Icons.task_alt,
        ),
        _buildStatColumn(
          'Success Rate',
          session.isCompleted ? '100%' : '${((duration / 75) * 100).toStringAsFixed(1)}%',
          Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
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
            color: Colors.grey[600],
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
