import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_sync_service.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';

/// In-app notifications screen.
///
/// Shows the recipient's notifications from the `fcm_notifications`
/// collection (newest first). Tapping an unread notification marks it
/// as delivered.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _limit = 100;

  @override
  Widget build(BuildContext context) {
    final syncService = CloudSyncService();
    if (!syncService.isSignedIn) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Notifications'),
        body: _SignInPrompt(),
      );
    }

    final uid = syncService.currentUser!.uid;
    return Scaffold(
      appBar: const CustomAppBar(title: 'Notifications'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('fcm_notifications')
            .where('recipientUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(_limit)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load notifications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              subtitle:
                  'Updates about partner invitations, reviews, and reminders will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _NotificationTile(doc: docs[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _NotificationTile({required this.doc});

  Future<void> _markDelivered() async {
    final data = doc.data();
    if (data['delivered'] == true) return;
    try {
      await doc.reference.update({'delivered': true});
    } catch (e) {
      debugPrint('[NotificationsScreen] Failed to mark delivered: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final type = (data['type'] as String?) ?? '';
    final title = (data['title'] as String?) ?? 'Notification';
    final body = (data['body'] as String?) ?? '';
    final delivered = data['delivered'] == true;
    final timestamp = data['createdAt'];
    final visual = _notificationStyle(type);

    return InkWell(
      onTap: _markDelivered,
      child: Container(
        color: delivered ? null : visual.color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight:
                                delivered ? FontWeight.w500 : FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (!delivered) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: visual.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _relativeTime(timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({IconData icon, Color color}) _notificationStyle(String type) {
  switch (type) {
    case 'invitationReceived':
      return (icon: Icons.mail, color: const Color(0xFF2196F3));
    case 'invitationAccepted':
      return (icon: Icons.check_circle, color: const Color(0xFF4CAF50));
    case 'invitationDeclined':
      return (icon: Icons.cancel, color: const Color(0xFFF44336));
    case 'taskNeedsReview':
      return (icon: Icons.rate_review, color: const Color(0xFFFF9800));
    case 'reviewApproved':
      return (icon: Icons.verified, color: const Color(0xFF4CAF50));
    case 'reviewRejected':
      return (icon: Icons.report, color: const Color(0xFFF44336));
    case 'reviewReminder20h':
      return (icon: Icons.alarm, color: const Color(0xFF9C27B0));
    case 'reviewExpired':
      return (icon: Icons.timer_off, color: Colors.grey);
    default:
      return (icon: Icons.notifications, color: const Color(0xFF2196F3));
  }
}

String _relativeTime(Object? timestamp) {
  DateTime? time;
  if (timestamp is Timestamp) {
    time = timestamp.toDate();
  } else if (timestamp is DateTime) {
    time = timestamp;
  }
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Sign in to see notifications',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              icon: const Icon(Icons.person),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
