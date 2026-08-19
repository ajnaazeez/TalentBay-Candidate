import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'TERMS & CONDITIONS',
          style: GoogleFonts.jost(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withOpacity(0.1)
                    : Colors.amber.shade50,
                border: Border.all(
                  color: isDark
                      ? Colors.amber.withOpacity(0.5)
                      : Colors.amber.shade200,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark
                        ? Colors.amber.shade300
                        : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IMPORTANT NOTE',
                          style: GoogleFonts.jost(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This app is only for finding jobs. Recruiters recruit candidates based on skills and experience. While you can connect with recruiters here, there is no guarantee of getting a job just because you are a member. Your profile, experience, and skills are what matter most.',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildSection(
              title: '1. Acceptance of Terms',
              content:
                  'By accessing and using TalentBay, you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you must not use our services.',
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            _buildSection(
              title: '2. User Eligibility',
              content:
                  'You must be at least 18 years old to use this application. By using TalentBay, you represent and warrant that you have the right, authority, and capacity to enter into this agreement.',
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            _buildSection(
              title: '3. Privacy Policy',
              content:
                  'Your use of TalentBay is also governed by our Privacy Policy, which can be found at https://www.waqtixllp.com/privacy-and-policy. Please review it to understand our practices.',
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            _buildSection(
              title: '4. User Conduct',
              content:
                  'Users are responsible for all activity that occurs under their account. You agree not to use the service for any illegal or unauthorized purpose.',
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            _buildSection(
              title: '5. Limitation of Liability',
              content:
                  'TalentBay and Waqttix LLP shall not be liable for any indirect, incidental, special, consequential or punitive damages resulting from your use of or inability to use the service.',
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Last Updated: February 2026',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color textColor,
    required Color? subTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.jost(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.primaryBrand,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(fontSize: 14, color: subTextColor, height: 1.6),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
