import 'package:flutter/material.dart';
import '../../../auth/models/candidate_model.dart';
import '../../../../core/theme/app_colors.dart';

class ProfileCompletionCard extends StatelessWidget {
  final CandidateModel candidate;

  const ProfileCompletionCard({super.key, required this.candidate});

  double _calculateCompletion() {
    double score = 0.0;

    // Basic Info (20)
    if (candidate.firstName != null &&
        candidate.lastName != null &&
        candidate.email.isNotEmpty &&
        candidate.phoneNumber != null) {
      score += 20;
    }

    // Location (10)
    if (candidate.currentLocation != null) {
      score += 10;
    }

    // Summary (10)
    if (candidate.bio != null || candidate.aboutMe != null) {
      score += 10;
    }

    // Job Preferences (10)
    if (candidate.jobPreference != null) {
      score += 10;
    }

    // Skills (15)
    if (candidate.skills.isNotEmpty) {
      score += 15;
    }

    // Experience (15)
    if (candidate.workExperience.isNotEmpty) {
      score += 15;
    }

    // Education (10)
    if (candidate.education.isNotEmpty) {
      score += 10;
    }

    // Projects (10)
    if (candidate.projects.isNotEmpty) {
      score += 10;
    }

    return score / 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _calculateCompletion();
    final int percentage = (progress * 100).toInt();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile Completion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForPercentage(progress),
              ),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              _getMessageForPercentage(progress),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.7) return Colors.orange;
    return Colors.green;
  }

  String _getMessageForPercentage(double progress) {
    if (progress < 0.3) return 'Complete your profile to get noticed!';
    if (progress < 0.7) return 'You are doing great! Add more details.';
    return 'Your profile is looking great!';
  }
}
