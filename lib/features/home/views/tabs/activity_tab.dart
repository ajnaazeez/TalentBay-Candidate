import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

    // Dynamic Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return candidateState.when(
      loading: () => Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'FAILED TO LOAD ACTIVITY',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: TextStyle(fontSize: 14, color: subTextColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(candidateControllerProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  foregroundColor: Colors.white,
                ),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
      data: (candidate) {
        final candidateId = (candidate?.uid.isNotEmpty == true)
            ? candidate!.uid
            : (FirebaseAuth.instance.currentUser?.uid ?? '');
        final savedJobIds = candidate?.savedJobIds ?? <String>[];

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
                          if (candidateId.isNotEmpty)
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
                    _AppliedJobsView(candidateId: candidateId),
                    _SavedJobsView(savedJobIds: savedJobIds),
                    _AcceptedJobsView(candidateId: candidateId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppliedJobsView extends ConsumerStatefulWidget {
  final String candidateId;
  const _AppliedJobsView({required this.candidateId});

  @override
  ConsumerState<_AppliedJobsView> createState() => _AppliedJobsViewState();
}

class _AppliedJobsViewState extends ConsumerState<_AppliedJobsView>
    with AutomaticKeepAliveClientMixin {
  late Stream<List<JobApplicationModel>> _stream;
  Timer? _timeoutTimer;
  bool _isSlowConnection = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _stream = ref
        .read(jobRepositoryProvider)
        .getCandidateApplications(widget.candidateId);
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _isSlowConnection = false;
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() {
          _isSlowConnection = true;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _initStream();
    });
  }

  @override
  void didUpdateWidget(covariant _AppliedJobsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidateId != widget.candidateId) {
      setState(() {
        _initStream();
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final jobRepo = ref.read(jobRepositoryProvider);

    return StreamBuilder<List<JobApplicationModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

        if (snapshot.hasData && _timeoutTimer?.isActive == true) {
          _timeoutTimer?.cancel();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_isSlowConnection) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: textColor),
                    const SizedBox(height: 16),
                    Text(
                      'Taking longer than expected...',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your internet connection or tap retry.',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('RETRY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: CircularProgressIndicator(color: textColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
                const SizedBox(height: 12),
                Text(
                  'Error loading applications',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${snapshot.error}',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
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
                                  final currentCandidateId = widget.candidateId;
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
}

class _AcceptedJobsView extends ConsumerStatefulWidget {
  final String candidateId;
  const _AcceptedJobsView({required this.candidateId});

  @override
  ConsumerState<_AcceptedJobsView> createState() => _AcceptedJobsViewState();
}

class _AcceptedJobsViewState extends ConsumerState<_AcceptedJobsView>
    with AutomaticKeepAliveClientMixin {
  late Stream<List<JobApplicationModel>> _stream;
  Timer? _timeoutTimer;
  bool _isSlowConnection = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _stream = ref
        .read(jobRepositoryProvider)
        .getCandidateApplications(widget.candidateId);
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _isSlowConnection = false;
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() {
          _isSlowConnection = true;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _initStream();
    });
  }

  @override
  void didUpdateWidget(covariant _AcceptedJobsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidateId != widget.candidateId) {
      setState(() {
        _initStream();
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final jobRepo = ref.read(jobRepositoryProvider);

    return StreamBuilder<List<JobApplicationModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

        if (snapshot.hasData && _timeoutTimer?.isActive == true) {
          _timeoutTimer?.cancel();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_isSlowConnection) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: textColor),
                    const SizedBox(height: 16),
                    Text(
                      'Taking longer than expected...',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your internet connection or tap retry.',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('RETRY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: CircularProgressIndicator(color: textColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
                const SizedBox(height: 12),
                Text(
                  'Error loading accepted jobs',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${snapshot.error}',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
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
}

class _SavedJobsView extends ConsumerStatefulWidget {
  final List<String> savedJobIds;
  const _SavedJobsView({required this.savedJobIds});

  @override
  ConsumerState<_SavedJobsView> createState() => _SavedJobsViewState();
}

class _SavedJobsViewState extends ConsumerState<_SavedJobsView>
    with AutomaticKeepAliveClientMixin {
  late Stream<List<JobModel>> _stream;
  Timer? _timeoutTimer;
  bool _isSlowConnection = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _stream = ref.read(jobRepositoryProvider).getSavedJobs(widget.savedJobIds);
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _isSlowConnection = false;
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() {
          _isSlowConnection = true;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _initStream();
    });
  }

  @override
  void didUpdateWidget(covariant _SavedJobsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.savedJobIds, widget.savedJobIds)) {
      setState(() {
        _initStream();
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Widget _buildEmptyState({
    required Color textColor,
    required Color? subTextColor,
    required bool isDark,
  }) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Watch candidate state for live saved-job updates
    final candidateState = ref.watch(candidateControllerProvider);
    final activeSavedIds = (candidateState.value?.savedJobIds ?? widget.savedJobIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    // If candidate has no saved jobs, immediately show appropriate empty state
    if (activeSavedIds.isEmpty) {
      return _buildEmptyState(
        textColor: textColor,
        subTextColor: subTextColor,
        isDark: isDark,
      );
    }

    return StreamBuilder<List<JobModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasData && _timeoutTimer?.isActive == true) {
          _timeoutTimer?.cancel();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_isSlowConnection) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: textColor),
                    const SizedBox(height: 16),
                    Text(
                      'Taking longer than expected...',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your internet connection or tap retry.',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('RETRY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: CircularProgressIndicator(color: textColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
                const SizedBox(height: 12),
                Text(
                  'Error loading saved jobs',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${snapshot.error}',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RETRY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
        }

        final allJobs = snapshot.data ?? [];
        // Strictly filter to ensure only jobs whose ID belongs to current candidate's saved list appear
        final jobs = allJobs
            .where((job) => activeSavedIds.contains(job.jobId))
            .toList();

        if (jobs.isEmpty) {
          return _buildEmptyState(
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
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
}

Widget _buildStatusChip(String status) {
  Color color;
  String label = status.toUpperCase();

  switch (status.toLowerCase()) {
    case 'selected':
    case 'hired':
      color = const Color(0xFF10B981); // Green
      break;
    case 'rejected':
      color = Colors.red;
      break;
    case 'interviewing':
    case 'interview':
      color = Colors.orange;
      break;
    default:
      color = Colors.lightBlue;
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
