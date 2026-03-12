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
              '75 Hard Challenge Tracker',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: March 11, 2026',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              'Data Collection',
              'We do NOT collect any personal information. All your data is stored locally on your device.',
            ),
            
            _buildSection(
              'Local Storage',
              'Your challenges, progress, and journal entries are stored only on your device using Hive database. We have no access to this data.',
            ),
            
            _buildSection(
              'Analytics',
              'We use Firebase Analytics to understand app usage patterns. This includes:\n• App opens and session duration\n• Feature usage (anonymous)\n• Crash reports (no personal data)\n\nNo personally identifiable information is collected.',
            ),
            
            _buildSection(
              'Permissions',
              'The app requests the following permissions:\n• Notifications: To send reminders\n• Camera/Storage: To add custom challenge images (optional)\n• Internet: To fetch motivational quotes\n\nAll permissions are used only for their stated purpose.',
            ),
            
            _buildSection(
              'Third-Party Services',
              'We use:\n• Firebase Analytics (Google)\n• Firebase Crashlytics (Google)\n• ZenQuotes API (motivational quotes)\n\nThese services may collect anonymous usage data.',
            ),
            
            _buildSection(
              'Data Security',
              'Your data is stored locally and encrypted by your device\'s operating system. We do not transmit your personal data to any servers.',
            ),
            
            _buildSection(
              'Your Rights',
              'You can:\n• Delete all data by uninstalling the app\n• Disable analytics (contact us)\n• Request information about data collection\n\nSince all data is local, uninstalling removes everything.',
            ),
            
            _buildSection(
              'Children\'s Privacy',
              'This app is not directed at children under 13. We do not knowingly collect data from children.',
            ),
            
            _buildSection(
              'Changes to Policy',
              'We may update this policy. Changes will be posted in the app with the updated date.',
            ),
            
            _buildSection(
              'Contact',
              'For questions about privacy, contact us through the Play Store listing.',
            ),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your privacy is our priority. All data stays on your device.',
                      style: GoogleFonts.inter(
                        color: Colors.green[900],
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
