import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../candidate/controllers/candidate_controller.dart';
import '../../../chat/repositories/chat_repository.dart';
import '../../../chat/views/chat_screen.dart';
import '../../../chat/views/chat_list_screen.dart';
import '../../../jobs/repositories/job_repository.dart';
import '../../../jobs/models/job_application_model.dart';
import '../../../jobs/models/job_model.dart';
import '../../views/widgets/job_card.dart'; // Reuse job card or create specific

class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({super.key});

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidateState = ref.watch(candidateControllerProvider);
    final jobRepo = ref.watch(jobRepositoryProvider);

    // Dynamic Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (candidateState.value == null) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    final candidateId = candidateState.value!.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            color: backgroundColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'MY ACTIVITY',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontFamily: 'Futura',
                        ),
                      ),
                      const Spacer(),
                      StreamBuilder<int>(
                        stream: ref
                            .watch(chatRepositoryProvider)
                            .getTotalUnreadCount(candidateId),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ChatListScreen(),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.mail_outline,
                                  color: textColor,
                                  size: 24,
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryBrand,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(
                        width: 2.0,
                        color: AppColors.primaryBrand,
                      ),
                    ),
                    labelColor: AppColors.primaryBrand,
                    unselectedLabelColor: subTextColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'APPLIED'),
                      Tab(text: 'SAVED'),
                      Tab(text: 'ACCEPTED'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppliedJobs(jobRepo, candidateId),
                _buildSavedJobs(jobRepo, candidateState.value!.savedJobIds),
                _buildAcceptedJobs(jobRepo, candidateId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedJobs(JobRepository jobRepo, String candidateId) {
    return StreamBuilder<List<JobApplicationModel>>(
      stream: jobRepo.getCandidateApplications(candidateId),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: textColor));
        }

        final allApplications = snapshot.data ?? [];
        // Filter out accepted/hired applications (they go to Accepted tab)
        final applications = allApplications
            .where(
              (app) => ![
                'hired',
                'accepted',
              ].contains(app.applicationStatus.toLowerCase()),
            )
            .toList();

        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 48,
                  color: isDark ? Colors.grey[700] : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'NO APPLICATIONS YET',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start applying to track them here',
                  style: TextStyle(fontSize: 14, color: subTextColor),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: applications.length,
          padding: const EdgeInsets.all(24),
          itemBuilder: (context, index) {
            final app = applications[index];

            return FutureBuilder<JobModel?>(
              future: jobRepo.getJob(app.jobId),
              builder: (context, jobSnapshot) {
                if (!jobSnapshot.hasData) return const SizedBox.shrink();
                final job = jobSnapshot.data!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.black,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company Logo
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child:
                                  job.companyLogoUrl != null &&
                                      job.companyLogoUrl!.isNotEmpty
                                  ? Image.network(
                                      job.companyLogoUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.business,
                                      color: textColor,
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          job.title.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: textColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    job.companyName?.toUpperCase() ?? 'UNKNOWN',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildStatusChip(app.applicationStatus),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFEEEEEE),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'APPLIED ${_formatDate(app.appliedAt)}',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            // Only show Message if Shortlisted
                            if (app.applicationStatus.toLowerCase() ==
                                'shortlisted')
                              InkWell(
                                onTap: () async {
                                  final currentCandidateId = candidateId;
                                  final recruiterId = job.recruiterId;

                                  if (recruiterId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cannot message: Recruiter info missing',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final chatRepo = ref.read(
                                      chatRepositoryProvider,
                                    );
                                    final chatId = await chatRepo
                                        .getOrCreateChat(
                                          jobId: job.jobId,
                                          candidateId: currentCandidateId,
                                          recruiterId: recruiterId,
                                        );

                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            chatId: chatId,
                                            jobTitle: job.title,
                                            companyName:
                                                job.companyName ?? 'Company',
                                            companyLogoUrl: job.companyLogoUrl,
                                            recipientName: 'Recruiter',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error starting chat: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  'MESSAGE',
                                  style: TextStyle(
                                    color:
                                        textColor, // Or subTextColor depending on pref
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              )
                            else
                              Text(
                                'MESSAGE',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey, // Disabled look
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedJobs(JobRepository jobRepo, String candidateId) {
    return StreamBuilder<List<JobApplicationModel>>(
      stream: jobRepo.getCandidateApplications(candidateId),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: textColor));
        }

        final allApplications = snapshot.data ?? [];
        // Filter only accepted/hired applications
        final applications = allApplications
            .where(
              (app) => [
                'hired',
                'accepted',
              ].contains(app.applicationStatus.toLowerCase()),
            )
            .toList();

        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: isDark ? Colors.grey[700] : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'NO ACCEPTED JOBS YET',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Jobs you are accepted for will appear here',
                  style: TextStyle(fontSize: 14, color: subTextColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: applications.length,
          padding: const EdgeInsets.all(24),
          itemBuilder: (context, index) {
            final app = applications[index];

            return FutureBuilder<JobModel?>(
              future: jobRepo.getJob(app.jobId),
              builder: (context, jobSnapshot) {
                if (!jobSnapshot.hasData) return const SizedBox.shrink();
                final job = jobSnapshot.data!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border.all(
                      color: Colors.green,
                    ), // Green border for accepted
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company Logo
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child:
                                  job.companyLogoUrl != null &&
                                      job.companyLogoUrl!.isNotEmpty
                                  ? Image.network(
                                      job.companyLogoUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.business,
                                      color: textColor,
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          job.title.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: textColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    job.companyName?.toUpperCase() ?? 'UNKNOWN',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      border: Border.all(
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                    child: const Text(
                                      'ACCEPTED',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? Colors.grey[800]
                              : const Color(0xFFEEEEEE),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ACCEPTED ON ${_formatDate(DateTime.now())}',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSavedJobs(JobRepository jobRepo, List<String> savedIds) {
    return StreamBuilder<List<JobModel>>(
      stream: jobRepo.getSavedJobs(savedIds),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: textColor));
        }
        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 48,
                  color: isDark ? Colors.grey[700] : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'NO SAVED JOBS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save jobs to view them here',
                  style: TextStyle(fontSize: 14, color: subTextColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: jobs.length,
          padding: const EdgeInsets.all(24),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: JobCard(job: jobs[index], isSaved: true),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color
    bgColor; // Kept for logic structure, but we might use outlines or just text
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'selected':
      case 'hired':
        color = const Color(0xFF10B981); // Green
        bgColor = const Color(0xFFD1FAE5);
        break;
      case 'rejected':
        color = Colors.red;
        bgColor = const Color(0xFFFEE2E2);
        break;
      case 'interviewing':
      case 'interview':
        color = Colors.orange;
        bgColor = const Color(0xFFFEF3C7);
        break;
      default:
        color = Colors.lightBlue;
        bgColor = Colors.grey[200]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
