import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../candidate/controllers/candidate_controller.dart';
import '../../../candidate/repositories/candidate_repository.dart';
import '../../../jobs/models/job_model.dart';

class JobCard extends ConsumerWidget {
  final JobModel job;
  final VoidCallback? onTap;
  final bool isApplied;
  final bool isSaved;
  final bool isInvited;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.isApplied = false,
    this.isSaved = false,
    this.isInvited = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We check saved status from provider if not explicitly passed,
    // but better to rely on passed parameter for list purity or check here.
    // For simplicity, let's just use the passed parameter or let the parent handle logic.
    // Actually, handling save toggle here is convenient.
    final candidateState = ref.watch(candidateControllerProvider);
    final isActuallySaved =
        candidateState.value?.savedJobIds.contains(job.jobId) ?? false;

    // Use isActuallySaved over isSaved if candidate is logged in
    final showSaved = candidateState.value != null ? isActuallySaved : isSaved;

    // Dynamic Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.zero, // Sharp edges
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Logo - Minimal
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey.shade50,
                        shape: BoxShape
                            .circle, // Circular logo looks often cleaner in minimal designs
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[800]!
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child:
                          job.companyLogoUrl != null &&
                              job.companyLogoUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                job.companyLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.business,
                                    color: textColor,
                                    size: 20,
                                  );
                                },
                              ),
                            )
                          : Icon(Icons.business, color: textColor, size: 20),
                    ),
                    const SizedBox(width: 16),

                    // Job Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Job Title
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  job.roleName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    height: 1.2,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isApplied) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: Text(
                                    'APPLIED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              if (isInvited && !isApplied) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: Text(
                                    'INVITED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Company Name
                          Text(
                            job.companyName ?? 'Unknown Company',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Save Button - Minimal
                    IconButton(
                      icon: Icon(
                        showSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: showSaved ? textColor : Colors.grey.shade400,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        if (candidateState.value == null) return;

                        final repo = ref.read(candidateRepositoryProvider);
                        final uid = candidateState.value!.uid;

                        try {
                          if (showSaved) {
                            await repo.removeSavedJob(uid, job.jobId);
                          } else {
                            await repo.addSavedJob(uid, job.jobId);
                          }
                          // ref.invalidate(candidateControllerProvider); // Stream handles update
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Job Details Row - Text-based, no icons or very minimal
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildMinimalInfo(context, job.experienceLevel),
                    _buildMinimalSeperator(),
                    _buildMinimalInfo(
                      context,
                      '${job.jobLocation.city}, ${job.jobLocation.country}',
                    ),
                    _buildMinimalSeperator(),
                    _buildMinimalInfo(context, job.employmentType),
                  ],
                ),

                const SizedBox(height: 12),

                // Footer: Salary & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Salary
                    if (job.salary.min > 0 || job.salary.max > 0)
                      Text(
                        _formatSalary(job.salary),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Time
                    _buildRecencyText(context, job.postedAt),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalInfo(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMinimalSeperator() {
    return const Padding(
      padding: EdgeInsets.only(top: 2.0),
      child: Text('•', style: TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildRecencyText(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;

    if (diff.inDays <= 7) {
      color = Colors.green; // < 7 days
    } else if (diff.inDays <= 30) {
      color = Colors.blue; // < 30 days
    } else {
      color = isDark ? Colors.white : Colors.black; // > 30 days
    }

    String text;
    if (diff.inDays > 0) {
      text = '${diff.inDays}D AGO';
    } else if (diff.inHours > 0) {
      text = '${diff.inHours}H AGO';
    } else {
      text = 'JUST NOW';
    }

    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    );
  }

  String _formatSalary(JobSalary salary) {
    final currency = salary.currency;
    final min = salary.min;
    final max = salary.max;

    if (min > 0 && max > 0) {
      return '$currency ${_formatNumber(min)} - ${_formatNumber(max)}';
    } else if (min > 0) {
      return '$currency ${_formatNumber(min)}+';
    } else if (max > 0) {
      return 'UP TO $currency ${_formatNumber(max)}';
    }
    return '';
  }

  String _formatNumber(double number) {
    if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }
}
