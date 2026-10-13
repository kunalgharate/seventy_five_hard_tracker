import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:seventy_five_hard_tracker/core/services/notification_dispatch_listener.dart';
import 'package:seventy_five_hard_tracker/core/services/notification_preferences.dart';

/// "Notifications" settings card: per-category toggles for accountability
/// pushes (reviews, assigned tasks, invitations, messages). Honors the
/// same prefs client-side (dispatch listener) and server-side (push
/// sender). Inserted into both Settings builders (active + general).
class NotificationPrefsCard extends StatefulWidget {
  const NotificationPrefsCard({super.key});

  @override
  State<NotificationPrefsCard> createState() => _NotificationPrefsCardState();
}

class _NotificationPrefsCardState extends State<NotificationPrefsCard> {
  static const _defs = [
    (
      key: NotificationPreferences.keyReviews,
      icon: Icons.rate_review_outlined,
      title: 'Task reviews',
      subtitle: 'Review requests, approvals and rejections',
    ),
    (
      key: NotificationPreferences.keyTasks,
      icon: Icons.assignment_outlined,
      title: 'Tasks assigned to me',
      subtitle: 'New accountability tasks from partners',
    ),
    (
      key: NotificationPreferences.keyInvitations,
      icon: Icons.mail_outline,
      title: 'Partner invitations',
      subtitle: 'Invites sent, accepted or declined',
    ),
    (
      key: NotificationPreferences.keyMessages,
      icon: Icons.chat_bubble_outline,
      title: 'Squad messages',
      subtitle: 'New chat messages from partners',
    ),
  ];

  Map<String, bool>? _prefs;
  bool _loading = true;
  bool _signedIn = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    Map<String, bool>? prefs;
    if (signedIn) prefs = await NotificationPreferences.instance.load();
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _prefs = prefs ?? {};
      _loading = false;
    });
  }

  Future<void> _toggle(String key, bool value) async {
    if (_saving) return;
    final previous = _prefs?[key] ?? true;
    setState(() {
      _saving = true;
      _prefs = {...?_prefs, key: value};
    });
    try {
      await NotificationPreferences.instance.setEnabled(key, value);
      // Refresh the listener cache so the next delivery honors the change.
      await NotificationDispatchListener.instance.refreshPrefs();
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = {...?_prefs, key: previous});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save preference. Check your connection.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which accountability updates can notify you',
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_signedIn)
              const ListTile(
                leading: Icon(Icons.notifications_off_outlined),
                title: Text('Sign in to manage preferences'),
                contentPadding: EdgeInsets.zero,
              )
            else
              for (final def in _defs)
                SwitchListTile(
                  value: _prefs?[def.key] ?? true,
                  onChanged: _saving ? null : (v) => _toggle(def.key, v),
                  secondary: Icon(def.icon),
                  title: Text(def.title),
                  subtitle: Text(
                    def.subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
          ],
        ),
      ),
    );
  }
}
