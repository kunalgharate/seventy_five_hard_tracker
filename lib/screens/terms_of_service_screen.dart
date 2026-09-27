import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_app_bar.dart';

/// Terms of Service / Terms & Conditions screen.
///
/// Content reflects the app's actual behaviour: an offline-first habit and
/// challenge tracker with optional Firebase-backed cloud backup and
/// accountability-partner features.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Terms & Conditions'),
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
              'Acceptance of Terms',
              'By downloading, installing, or using DailyMettle ("the app"), you agree to these Terms & Conditions. If you do not agree, please do not use the app.',
            ),
            _buildSection(
              'The Service',
              'DailyMettle helps you create daily habits and challenges, track completion, receive reminders, and optionally back up your data and share progress with accountability partners. The app is offline-first: cloud backup and partner features are optional and only active when you sign in.',
            ),
            _buildSection(
              'Your Account',
              'Some features require signing in with Google or email. You are responsible for keeping your account credentials secure and for all activity that occurs under your account. Provide accurate information when signing in.',
            ),
            _buildSection(
              'Acceptable Use',
              'You agree to use the app only for lawful, personal habit and challenge tracking. You must not:\n\u2022 Upload unlawful, harmful, or infringing content\n\u2022 Harass, abuse, or share others\u2019 private information through partner features\n\u2022 Attempt to disrupt, reverse-engineer, or gain unauthorized access to the app or its services',
            ),
            _buildSection(
              'User Content',
              'You retain ownership of the task names, notes, and photos you create ("your content"). You are solely responsible for your content. When you use accountability-partner features, you grant the app permission to share the specific content you choose with the partners you select, so the feature can function.',
            ),
            _buildSection(
              'Accountability Partners',
              'Partner features let you and another user review each other\u2019s tasks. Only share information you are comfortable disclosing to your partner. We are not responsible for how partners use information you choose to share with them.',
            ),
            _buildSection(
              'Health & Safety Disclaimer',
              'DailyMettle is a tracking tool, not medical, fitness, or professional advice. You are solely responsible for your own health, safety, and wellbeing while pursuing any challenge. Consult a qualified professional before starting any new fitness, diet, or wellness routine.',
            ),
            _buildSection(
              'Privacy',
              'Your use of the app is also governed by our Privacy Policy, which explains how your data is processed. Please review it to understand our data practices.',
            ),
            _buildSection(
              'Availability & Changes',
              'We may update, change, or discontinue features at any time. Cloud and partner features depend on third-party services (such as Google Firebase) and internet connectivity, and may be temporarily unavailable.',
            ),
            _buildSection(
              'Disclaimer of Warranties',
              'The app is provided "as is" and "as available" without warranties of any kind, whether express or implied, including fitness for a particular purpose and uninterrupted or error-free operation.',
            ),
            _buildSection(
              'Limitation of Liability',
              'To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages, or for any loss of data, arising from your use of the app.',
            ),
            _buildSection(
              'Termination',
              'You may stop using the app at any time by uninstalling it. We may suspend or terminate access if you violate these terms.',
            ),
            _buildSection(
              'Changes to These Terms',
              'We may update these Terms from time to time. Material changes will be posted in the app with an updated date. Continued use after changes means you accept the updated Terms.',
            ),
            _buildSection(
              'Contact',
              'For questions about these Terms, contact us at hello@thecodershub.in.',
            ),
            const SizedBox(height: 32),
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
