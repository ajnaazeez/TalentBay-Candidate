import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../candidate/controllers/candidate_controller.dart';
import '../models/job_model.dart';
import '../models/job_application_model.dart';
import '../repositories/job_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:talentbay_candidate/features/payment/views/subscription_prompt_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../home/views/widgets/job_card.dart';

class JobDetailsScreen extends ConsumerStatefulWidget {
  final String jobId;
  final JobModel? job;

  const JobDetailsScreen({super.key, required this.jobId, this.job});

  @override
  ConsumerState<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends ConsumerState<JobDetailsScreen> {
  bool _isApplying = false;
  Stream<JobApplicationModel?>? _applicationStream;
  String _lastCandidateId = '';

  void _applyToJob(JobModel job, String candidateId) async {
    final candidate = ref.read(candidateControllerProvider).value;
    if (candidate != null && !candidate.isPremium) {
      showDialog(
        context: context,
        builder: (context) => const SubscriptionPromptDialog(),
      );
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final applicationStream = ref.read(jobRepositoryProvider).getApplicationStatus(job.jobId, candidateId);
      final existingApplication = await applicationStream.first;

      if (existingApplication != null && existingApplication.applicationStatus.toLowerCase() == 'invited') {
        // Handle invitation acceptance
        await ref.read(jobRepositoryProvider).acceptInvitation(existingApplication.applicationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation accepted and application submitted!')),
          );
        }
      } else {
        // Standard application
        final application = JobApplicationModel(
          applicationId: '${job.jobId}_$candidateId',
          jobId: job.jobId,
          candidateId: candidateId,
          resumeUrl: '', // TODO: Get from candidate profile
          coverLetter: '', // Optional: Add dialog to enter cover letter
          applicationStatus: 'applied',
          appliedAt: DateTime.now(),
          source: 'app',
        );

        await ref.read(jobRepositoryProvider).applyToJob(application);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully applied to job!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.job != null) {
      return _buildJobContent(context, ref, widget.job!);
    }

    return FutureBuilder<JobModel?>(
      future: ref.read(jobRepositoryProvider).getJob(widget.jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            body: Center(
              child: Text(
                snapshot.hasError
                    ? 'Error: ${snapshot.error}'
                    : 'JOB NOT FOUND',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        return _buildJobContent(context, ref, snapshot.data!);
      },
    );
  }

  Widget _buildJobContent(BuildContext context, WidgetRef ref, JobModel job) {
    final candidateState = ref.watch(candidateControllerProvider);
    final candidateId = candidateState.value?.uid ?? '';

    // Check if applied (Cache the stream to avoid StreamBuilder resets on setState)
    if (_applicationStream == null || _lastCandidateId != candidateId) {
      _lastCandidateId = candidateId;
      _applicationStream = ref
          .read(jobRepositoryProvider)
          .getApplicationStatus(job.jobId, candidateId);
    }

    // H&M Aesthetic - Dynamic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final dividerColor = isDark ? Colors.grey[800] : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          job.roleName.toUpperCase(),
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            fontFamily: 'Futura',
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.share, color: textColor),
            onSelected: (value) async {
              final String link = 'https://talentbay.app/job/${job.jobId}';
              final String text = 'Check out this job on TalentBay: ${job.roleName} at ${job.companyName}.\n\nApply now: $link';
              if (value == 'whatsapp') {
                final Uri whatsappUrl = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(text)}");
                try {
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl);
                  } else {
                    Share.share(text);
                  }
                } catch (e) {
                   Share.share(text);
                }
              } else {
                Share.share(text);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(Icons.chat, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Share on WhatsApp'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'other',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share via...'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Divider
            Divider(height: 1, thickness: 1, color: dividerColor),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          border: Border.all(color: borderColor),
                          shape: BoxShape.circle,
                        ),
                        child:
                            job.companyLogoUrl != null &&
                                job.companyLogoUrl!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  job.companyLogoUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(Icons.business, color: textColor, size: 30),
                      ),
                      const SizedBox(width: 20),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.companyName?.toUpperCase() ??
                                  'UNKNOWN COMPANY',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              job.roleName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                height: 1.1,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Location & Date
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${job.jobLocation.city}, ${job.jobLocation.country}'
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'POSTED ${_formatDate(job.postedAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Meta Info Row (Work Mode, Employment Type, etc.)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetaItem(
                          context,
                          'WORK MODE',
                          job.workMode.toUpperCase(),
                        ),
                        _buildMetaItem(
                          context,
                          'TYPE',
                          job.employmentType.toUpperCase(),
                        ),
                        if (job.experienceLevel.isNotEmpty)
                          _buildMetaItem(
                            context,
                            'LEVEL',
                            job.experienceLevel.toUpperCase(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Key Info Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'OVERVIEW'),
                  const SizedBox(height: 20),
                  _buildMinimalInfoGrid(context, job),
                  const SizedBox(height: 48),

                  // Description
                  _buildSectionTitle(context, 'ABOUT THE ROLE'),
                  const SizedBox(height: 16),
                  Text(
                    job.jobDescription,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Responsibilities
                  if (job.responsibilities.isNotEmpty) ...[
                    _buildSectionTitle(context, 'KEY RESPONSIBILITIES'),
                    const SizedBox(height: 16),
                    ...job.responsibilities.map(
                      (resp) => _buildBulletPoint(context, resp),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Requirements
                  if (job.requirements.isNotEmpty) ...[
                    _buildSectionTitle(context, 'REQUIREMENTS'),
                    const SizedBox(height: 16),
                    ...job.requirements.map(
                      (req) => _buildBulletPoint(context, req),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Skills
                  _buildSectionTitle(context, 'SKILLS REQUIRED'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.skillsRequired
                        .map((skill) => _buildMinimalSkillChip(context, skill))
                        .toList(),
                  ),
                  const SizedBox(height: 48),

                  // Related Jobs
                  _buildSectionTitle(context, 'RELATED JOBS'),
                  const SizedBox(height: 16),
                  _buildRelatedJobs(context, ref, job),

                  const SizedBox(height: 120), // Bottom padding for FAB
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            24,
            20,
            24,
            20,
          ), // Adjusted bottom padding since SafeArea provides the safe padding
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: StreamBuilder<JobApplicationModel?>(
          stream: _applicationStream,
          builder: (context, snapshot) {
            final application = snapshot.data;
            final status = application?.applicationStatus.toLowerCase() ?? '';
            final isWaiting = snapshot.connectionState == ConnectionState.waiting;
            
            final hasActuallyApplied = application != null && status != 'invited';
            final hasActuallyBeenInvited = application != null && status == 'invited';

            final canApply =
                candidateId.isNotEmpty &&
                !hasActuallyApplied &&
                !_isApplying &&
                !isWaiting;

            Color buttonColor = AppColors.primaryBrand;
            Color textColor = Colors.white;
            String buttonText = 'APPLY NOW';

            if (isWaiting || candidateId.isEmpty) {
              buttonColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
              textColor = isDark ? Colors.grey[600]! : Colors.grey[500]!;
              buttonText = 'LOADING...';
            } else if (hasActuallyBeenInvited) {
              buttonColor = Colors.blue;
              buttonText = 'ACCEPT & APPLY';
            } else if (hasActuallyApplied) {
              buttonColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
              textColor = isDark ? Colors.grey[600]! : Colors.grey[500]!;
              buttonText = 'APPLIED';
            }

            return SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: canApply
                    ? () => _applyToJob(job, candidateId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: textColor,
                  disabledBackgroundColor: buttonColor,
                  disabledForegroundColor: textColor,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ), // Sharp
                  padding: EdgeInsets.zero,
                ),
                child: _isApplying || isWaiting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isWaiting ? Colors.grey : Colors.white,
                        ),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : Colors.black,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMetaItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : Colors.grey[400],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalSkillChip(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMinimalInfoGrid(BuildContext context, JobModel job) {
    final currency = job.salary.currency;
    final minSalary = job.salary.min.toStringAsFixed(0);
    final maxSalary = job.salary.max.toStringAsFixed(0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildMinimalInfoItem(
            context,
            'SALARY',
            '$currency ${_formatNumber(job.salary.min)} - ${_formatNumber(job.salary.max)}',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildMinimalInfoItem(
            context,
            'EXPERIENCE',
            '${job.experienceRequired.minYears}-${job.experienceRequired.maxYears} YEARS',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildMinimalInfoItem(
            context,
            'VACANCIES',
            '${job.vacancies} OPEN',
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalInfoItem(
    BuildContext context,
    String title,
    String value,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey[400],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(0)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    // Should realistically use a formatter, but keeping it simple as per original
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedJobs(BuildContext context, WidgetRef ref, JobModel currentJob) {
    final candidateState = ref.watch(candidateControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<JobModel>>(
      stream: ref.watch(jobRepositoryProvider).getJobsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allJobs = snapshot.data!;
        
        var relatedJobs = allJobs.where((j) => j.jobId != currentJob.jobId).toList();
        
        relatedJobs.sort((a, b) {
          int scoreA = 0;
          int scoreB = 0;
          if (a.roleName.toLowerCase() == currentJob.roleName.toLowerCase()) scoreA += 2;
          if (a.companyId == currentJob.companyId) scoreA += 1;
          
          if (b.roleName.toLowerCase() == currentJob.roleName.toLowerCase()) scoreB += 2;
          if (b.companyId == currentJob.companyId) scoreB += 1;
          
          return scoreB.compareTo(scoreA);
        });

        final displayJobs = relatedJobs.take(3).toList();

        if (displayJobs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No related jobs currently available.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          );
        }

        final uid = candidateState.value?.uid;
        return StreamBuilder<List<JobApplicationModel>>(
          stream: uid != null
              ? ref.watch(jobRepositoryProvider).getCandidateApplications(uid)
              : Stream.value([]),
          builder: (context, appSnapshot) {
             final applications = appSnapshot.data ?? [];
             final appliedJobIds = applications.map((a) => a.jobId).toSet();

             return Column(
               children: displayJobs.map((relatedJob) {
                 final isApplied = appliedJobIds.contains(relatedJob.jobId);
                 return JobCard(
                   job: relatedJob,
                   isApplied: isApplied,
                   onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => JobDetailsScreen(
                           job: relatedJob,
                           jobId: relatedJob.jobId,
                         ),
                       ),
                     );
                   },
                 );
               }).toList(),
             );
          },
        );
      },
    );
  }
}
