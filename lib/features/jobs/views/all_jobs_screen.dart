import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../candidate/controllers/candidate_controller.dart';
import '../models/job_model.dart';
import '../repositories/job_repository.dart';
import '../../home/views/widgets/job_card.dart';
import 'job_details_screen.dart';

class AllJobsScreen extends ConsumerStatefulWidget {
  const AllJobsScreen({super.key});

  @override
  ConsumerState<AllJobsScreen> createState() => _AllJobsScreenState();
}

class _AllJobsScreenState extends ConsumerState<AllJobsScreen> {
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('search_history');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final validItems = decoded.map((item) => item['query'] as String).toList();
      if (mounted) {
        setState(() {
          _recentSearches = validItems;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidateState = ref.watch(candidateControllerProvider);
    final jobRepo = ref.watch(jobRepositoryProvider);

    final candidate = candidateState.value;
    final uid = candidate?.uid;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'ALL JOBS',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            fontFamily: 'Futura',
          ),
        ),
      ),
      body: StreamBuilder<List<JobModel>>(
        stream: jobRepo.getJobsStream(),
        builder: (context, jobSnapshot) {
          if (jobSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (jobSnapshot.hasError) {
            return const Center(child: Text('Error loading jobs'));
          }

          final jobs = jobSnapshot.data ?? [];

          return StreamBuilder(
            stream: uid != null ? jobRepo.getCandidateApplications(uid) : Stream.value([]),
            builder: (context, appSnapshot) {
              final applications = appSnapshot.data ?? [];

              final excludedJobIds = applications
                  .where((a) =>
                      a.applicationStatus.toLowerCase() == 'hired' ||
                      a.applicationStatus.toLowerCase() == 'accepted' ||
                      a.applicationStatus.toLowerCase() == 'rejected')
                  .map((a) => a.jobId)
                  .toSet();

              final appliedJobIds = applications
                  .where((a) => !excludedJobIds.contains(a.jobId))
                  .map((a) => a.jobId)
                  .toSet();

              final validJobs = jobs.where((j) => !excludedJobIds.contains(j.jobId)).toList();

              // Split into Recommended and Others
              final List<JobModel> recommendedJobs = [];
              final List<JobModel> otherJobs = [];

              for (final job in validJobs) {
                bool matchesProfile = false;

                if (candidate?.designation != null && candidate!.designation!.isNotEmpty) {
                  final designation = candidate.designation!.toLowerCase();
                  if (job.roleName.toLowerCase().contains(designation) ||
                      job.designationName.toLowerCase().contains(designation)) {
                    matchesProfile = true;
                  }
                }

                if (!matchesProfile && candidate != null && candidate.skills.isNotEmpty) {
                  for (var skill in candidate.skills) {
                    final skillName = skill.name.toLowerCase();
                    if (job.skillsRequired.any((s) => s.toLowerCase().contains(skillName)) ||
                        job.mustHaveSkills.any((s) => s.toLowerCase().contains(skillName)) ||
                        job.niceToHaveSkills.any((s) => s.toLowerCase().contains(skillName))) {
                      matchesProfile = true;
                      break;
                    }
                  }
                }

                bool matchesSearch = false;
                if (!matchesProfile && _recentSearches.isNotEmpty) {
                  for (var query in _recentSearches) {
                    final q = query.toLowerCase();
                    if (job.roleName.toLowerCase().contains(q) ||
                        job.designationName.toLowerCase().contains(q) ||
                        (job.companyName != null && job.companyName!.toLowerCase().contains(q)) ||
                        job.skillsRequired.any((s) => s.toLowerCase().contains(q))) {
                      matchesSearch = true;
                      break;
                    }
                  }
                }

                if (matchesProfile || matchesSearch) {
                  recommendedJobs.add(job);
                } else {
                  otherJobs.add(job);
                }
              }

              if (validJobs.isEmpty) {
                return const Center(child: Text('No jobs available'));
              }

              return CustomScrollView(
                slivers: [
                  if (recommendedJobs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text(
                          'RECOMMENDED FOR YOU',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final job = recommendedJobs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: JobCard(
                              job: job,
                              isApplied: appliedJobIds.contains(job.jobId),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailsScreen(job: job, jobId: job.jobId),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: recommendedJobs.length,
                      ),
                    ),
                  ],
                  if (otherJobs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text(
                          'ALL AVAILABLE JOBS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final job = otherJobs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: JobCard(
                              job: job,
                              isApplied: appliedJobIds.contains(job.jobId),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailsScreen(job: job, jobId: job.jobId),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: otherJobs.length,
                      ),
                    ),
                  ],
                  const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
