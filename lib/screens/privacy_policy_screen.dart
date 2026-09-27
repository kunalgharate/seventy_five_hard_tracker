import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Privacy Policy'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DailyMettle: Habit & Challenge',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: September 1, 2026',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Overview',
              'DailyMettle is a habit and challenge tracker. This policy explains what data we process, why, and the choices you have. We designed the app to work offline first — cloud features are optional and only active when you sign in.',
            ),
            _buildSection(
              'Data Stored On Your Device',
              'By default, your challenges, daily progress, journal notes, task notes, and photos are stored locally on your device using an on-device database. If you never sign in, this data stays on your device.',
            ),
            _buildSection(
              'Account & Sign-In',
              'If you enable cloud backup or the accountability partner features, you sign in with Google or email. We process your account identifier, email address, and display name to authenticate you and to enable partner features. Authentication is provided by Firebase Authentication (Google).',
            ),
            _buildSection(
              'Cloud Backup (Optional)',
              'When cloud backup is enabled, your task names, journal notes, and progress are encrypted on your device using AES-256 before being uploaded to Firebase Firestore, where they are stored as encrypted content. The encryption key is tied to your account, and access to your backup is restricted to your account by Firebase security rules. If you do not enable backup, no full backup data leaves your device. Note: if you use the accountability partner feature, limited progress and task data is shared separately with your partners as described below, regardless of the backup setting.',
            ),
            _buildSection(
              'Accountability Partners (Optional)',
              'If you invite or accept a partner, limited information is shared to make the feature work: your display name, aggregate progress counts, the task names you choose to share, and any photo proof you submit for review. Partners can approve or reject the tasks you assign to each other. Do not share sensitive personal information in task names, notes, or photos.',
            ),
            _buildSection(
              'Photos',
              'When you attach a photo as task proof or a custom task icon, the image is taken from your camera or photo library with your permission. Photos attached to accountability tasks are uploaded to our media hosting provider (Cloudinary) so your partner can review them. These photos are not encrypted; please avoid including sensitive information in them.',
            ),
            _buildSection(
              'Analytics & Crash Reporting',
              'We use Firebase Analytics and Firebase Crashlytics to understand usage patterns and to diagnose crashes so we can improve stability. Analytics events may include app opens, feature usage, device model, crash diagnostics, and the names of challenges and tasks you create. This data is associated with your app installation for analysis but is not linked to your sign-in account and is not used to track you across other companies\u2019 apps or websites.',
            ),
            _buildSection(
              'Notifications',
              'With your permission, the app schedules local reminders and may receive push notifications via Firebase Cloud Messaging to remind you about your tasks and partner activity. You can disable notifications at any time in your device settings.',
            ),
            _buildSection(
              'Permissions We Request',
              '\u2022 Notifications \u2014 to send reminders\n\u2022 Camera & Photo Library \u2014 to attach photo proof or custom task icons (optional)\n\u2022 Internet \u2014 for cloud backup, partner features, notifications, and motivational quotes\n\nEach permission is used only for its stated purpose, and the photo/camera permissions are only requested when you use those features.',
            ),
            _buildSection(
              'Third-Party Services',
              'We rely on:\n\u2022 Firebase Authentication, Firestore, Analytics, Crashlytics, and Cloud Messaging (Google)\n\u2022 Cloudinary for hosting photos you attach to tasks\n\u2022 A public quotes API for motivational quotes\n\nGoogle processes data under its own privacy policy. See policies.google.com/privacy.',
            ),
            _buildSection(
              'Data Retention & Deletion',
              'Local data is removed when you uninstall the app. If you used cloud backup, you can request deletion of your account and associated cloud data by contacting us at the address below; we will delete your backup and account records.',
            ),
            _buildSection(
              'Your Rights',
              'You can:\n\u2022 Use the app fully offline without signing in\n\u2022 Export your data as JSON from Settings\n\u2022 Disable notifications and photo permissions in device settings\n\u2022 Request access to or deletion of your cloud data',
            ),
            _buildSection(
              'Children\u2019s Privacy',
              'This app is not directed at children under 13, and we do not knowingly collect personal information from children.',
            ),
            _buildSection(
              'Changes to This Policy',
              'We may update this policy from time to time. Material changes will be posted in the app with an updated date.',
            ),
            _buildSection(
              'Contact',
              'For privacy questions or data deletion requests, contact us at hello@thecodershub.in.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Offline-first by design. Cloud backup and partner features are optional, and your backups are encrypted before upload.',
                      style: GoogleFonts.inter(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
