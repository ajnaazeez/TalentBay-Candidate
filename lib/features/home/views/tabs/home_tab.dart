import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../jobs/repositories/job_repository.dart';
import 'package:go_router/go_router.dart';
import '../../views/widgets/job_card.dart';
import '../../../../features/jobs/views/job_details_screen.dart';
import '../../../candidate/controllers/candidate_controller.dart';
import '../../../companies/repositories/company_repository.dart';
import '../../../companies/views/company_details_screen.dart';
import '../../../companies/models/company_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../search_screen.dart';
import '../../../../features/jobs/views/all_jobs_screen.dart';
import '../../../../features/companies/views/all_companies_screen.dart';
import '../../../../notification/providers/notification_provider.dart';

import '../invitations_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/payment/views/subscription_trial_bottom_sheet.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _selectedCategory = 'All';
  static bool _hasShownTrialPrompt = false;

  final List<String> _categories = [
    'All',
    'Remote',
    'Full-time',
    'Part-time',
    'Contract',
  ];

  List<String> _recentSearches = [];

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('search_history');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final validItems = decoded
          .map((item) => item['query'] as String)
          .toList();

      if (mounted) {
        setState(() {
          _recentSearches = validItems;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidateState = ref.watch(candidateControllerProvider);
    final jobRepo = ref.watch(jobRepositoryProvider);
    final companyRepo = ref.watch(companyRepositoryProvider);
    final notificationsAsync = ref.watch(userNotificationsProvider);
    
    final unreadCount = notificationsAsync.value?.where((n) => n.status == 'Unread').length ?? 0;

    final candidate = candidateState.value;
    final uid = candidate?.uid;
    final fullName =
        '${candidate?.firstName ?? 'User'} ${candidate?.lastName ?? ''}'.trim();
        
    if (candidate != null && !candidate.hasUsedTrial && !_hasShownTrialPrompt) {
      _hasShownTrialPrompt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.shortestSide >= 600 ? 550 : double.infinity,
            ),
            builder: (context) => const SubscriptionTrialBottomSheet(),
          );
        }
      });
    }

    // H&M Aesthetic Constants - Dynamic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Minimalist Header
          SliverAppBar(
            backgroundColor: backgroundColor,
            pinned: true,
            floating: true,
            elevation: 0,
            expandedHeight:
                220, // Increased height to prevent RenderFlex overflow
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row - Greeting & Avatar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HELLO, ${fullName.toUpperCase()}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 24,
                                    fontFamily: 'Futura',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'FIND YOUR NEXT ROLE',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Minimal Avatar & Notification Bell
                          Row(
                            children: [
                              Stack(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.notifications_none,
                                      color: textColor,
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      context.push('/notifications');
                                    },
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isDark
                                      ? Colors.grey[900]
                                      : Colors.white,
                                  backgroundImage:
                                      (candidate?.photoUrl != null &&
                                          candidate!.photoUrl!.isNotEmpty)
                                      ? NetworkImage(candidate.photoUrl!)
                                      : null,
                                  child:
                                      (candidate?.photoUrl == null ||
                                          candidate!.photoUrl!.isEmpty)
                                      ? Icon(
                                          Icons.person_outline,
                                          color: textColor,
                                          size: 24,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Minimal Search Bar
                      TextField(
                        readOnly: true,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                          _loadSearchHistory();
                        },
                        style: TextStyle(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'SEARCH FOR JOBS, COMPANIES...',
                          hintStyle: TextStyle(
                            color: subTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: textColor,
                            size: 20,
                          ),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 12,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: textColor),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Minimal Stats Grid
          if (uid != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: _buildMinimalStatsGrid(context, ref, uid),
              ),
            ),

          // Category Chips
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 24),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return _buildMinimalCategoryChip(category, isSelected);
                },
              ),
            ),
          ),

          // Section Header - Recent Jobs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECOMMENDED FOR YOU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllJobsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'VIEW ALL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBrand,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Job List with Minimal Cards
          StreamBuilder(
            stream: jobRepo.getJobsStream(),
            builder: (context, jobSnapshot) {
              if (jobSnapshot.connectionState == ConnectionState.waiting) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildShimmerLoading(),
                  ),
                );
              }
              if (jobSnapshot.hasError) {
                return SliverToBoxAdapter(
                  child: _buildErrorState('Error loading jobs'),
                );
              }

              final jobs = jobSnapshot.data ?? [];

              // Nested StreamBuilder to get applications for filtering
              return StreamBuilder(
                stream: uid != null
                    ? jobRepo.getCandidateApplications(uid)
                    : Stream.value([]),
                builder: (context, appSnapshot) {
                  // We don't show loading here, just use empty list if loading/error to not block UI
                  final applications = appSnapshot.data ?? [];

                  // Set of Job IDs to EXCLUDE (hired/accepted or rejected)
                  final excludedJobIds = applications
                      .where(
                        (a) =>
                            a.applicationStatus.toLowerCase() == 'hired' ||
                            a.applicationStatus.toLowerCase() == 'accepted' ||
                            a.applicationStatus.toLowerCase() == 'rejected',
                      )
                      .map((a) => a.jobId)
                      .toSet();

                  // Set of Job IDs that are INVITED (not yet accepted)
                  final invitedJobIds = applications
                      .where((a) => a.applicationStatus.toLowerCase() == 'invited')
                      .map((a) => a.jobId)
                      .toSet();

                  // Set of Job IDs that are APPLIED (but not excluded or invited)
                  final appliedJobIds = applications
                      .where((a) => !excludedJobIds.contains(a.jobId) && 
                                   a.applicationStatus.toLowerCase() != 'invited')
                      .map((a) => a.jobId)
                      .toSet();

                  // Filter jobs
                  final filteredJobs = jobs.where((job) {
                    // 1. Exclude if in excluded list
                    if (excludedJobIds.contains(job.jobId)) return false;

                    // 2. Category filter
                    if (_selectedCategory != 'All') {
                      if (_selectedCategory == 'Remote') {
                        if (!(job.workMode.toLowerCase().contains('remote') ||
                            job.jobLocation.city.toLowerCase().contains(
                              'remote',
                            ))) {
                          return false;
                        }
                      } else {
                        if (job.employmentType.toLowerCase() !=
                            _selectedCategory.toLowerCase()) {
                          return false;
                        }
                      }
                    }

                    // 3. Profile Match
                    bool matchesProfile = false;
                    
                    bool hasProfileData = (candidate?.designation != null && candidate!.designation!.isNotEmpty) || 
                                          (candidate != null && candidate.skills.isNotEmpty);
                    bool hasSearchData = _recentSearches.isNotEmpty;

                    if (candidate?.designation != null &&
                        candidate!.designation!.isNotEmpty) {
                      final designation = candidate.designation!.toLowerCase();
                      if (job.roleName.toLowerCase().contains(designation) ||
                          job.designationName.toLowerCase().contains(
                            designation,
                          )) {
                        matchesProfile = true;
                      }
                    }

                    if (!matchesProfile &&
                        candidate != null &&
                        candidate.skills.isNotEmpty) {
                      for (var skill in candidate.skills) {
                        final skillName = skill.name.toLowerCase();
                        if (job.skillsRequired.any(
                              (s) => s.toLowerCase().contains(skillName),
                            ) ||
                            job.mustHaveSkills.any(
                              (s) => s.toLowerCase().contains(skillName),
                            ) ||
                            job.niceToHaveSkills.any(
                              (s) => s.toLowerCase().contains(skillName),
                            )) {
                          matchesProfile = true;
                          break;
                        }
                      }
                    }

                    // 4. Search History Match
                    bool matchesSearch = false;
                    if (!matchesProfile && _recentSearches.isNotEmpty) {
                      for (var query in _recentSearches) {
                        final q = query.toLowerCase();
                        if (job.roleName.toLowerCase().contains(q) ||
                            job.designationName.toLowerCase().contains(q) ||
                            (job.companyName != null &&
                                job.companyName!.toLowerCase().contains(q)) ||
                            job.skillsRequired.any(
                              (s) => s.toLowerCase().contains(q),
                            )) {
                          matchesSearch = true;
                          break;
                        }
                      }
                    }

                    // If user has no profile data to match against and no search history, show all jobs
                    if (!hasProfileData && !hasSearchData) {
                      return true;
                    }

                    return matchesProfile || matchesSearch;
                  }).toList();

                  if (filteredJobs.isEmpty) {
                    return SliverToBoxAdapter(child: _buildEmptyState());
                  }

                  final displayJobs = filteredJobs.take(5).toList();

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final job = displayJobs[index];
                      final isApplied = appliedJobIds.contains(job.jobId);

                      return FadeTransition(
                        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              index * 0.1,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: JobCard(
                            job: job,
                            isApplied: isApplied,
                            isInvited: invitedJobIds.contains(job.jobId),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JobDetailsScreen(
                                    job: job,
                                    jobId: job.jobId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }, childCount: displayJobs.length),
                  );
                },
              );
            },
          ),

          // Our Companies Section - Minimal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOP COMPANIES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AllCompaniesScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'VIEW ALL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBrand,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<List<CompanyModel>>(
                    stream: companyRepo.getCompanies(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          ),
                        );
                      }
                      final companies = snapshot.data!;
                      
                      final sortedCompanies = List<CompanyModel>.from(companies);
                      sortedCompanies.sort((a, b) => b.stats.totalApplicants.compareTo(a.stats.totalApplicants));
                      
                      final topCompanies = sortedCompanies.take(5).toList();

                      if (topCompanies.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No companies available',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 120, // Reduced height
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topCompanies.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final company = topCompanies[index];
                            return _buildMinimalCompanyCard(context, company);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildMinimalStatsGrid(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) {
    final jobRepo = ref.watch(jobRepositoryProvider);
    final candidateState = ref.watch(candidateControllerProvider);
    // Dynamic styles passed or handled inside child widgets

    return Row(
      children: [
        // Applied
        Expanded(
          child: StreamBuilder(
            stream: jobRepo.getCandidateApplications(uid),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _buildMinimalStatCard(
                title: 'APPLIED',
                count: count.toString(),
                index: 0,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Saved
        Expanded(
          child: _buildMinimalStatCard(
            title: 'SAVED',
            count: (candidateState.value?.savedJobIds.length ?? 0).toString(),
            index: 1,
          ),
        ),
        const SizedBox(width: 12),
        // Invites
        Expanded(
          child: StreamBuilder(
            stream: jobRepo.getInvites(uid),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _buildMinimalStatCard(
                title: 'INVITES',
                count: count.toString(),
                index: 2,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvitationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalStatCard({
    required String title,
    required String count,
    required int index,
    VoidCallback? onTap,
  }) {
    // Dynamic styles
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final boxColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[500];

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(index * 0.15, 0.6, curve: Curves.easeOut),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: boxColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.zero, // Sharp edges
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  fontFamily: 'Futura',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalCategoryChip(String category, bool isSelected) {
    // Dynamic styles
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primaryBrand;
    final inactiveColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[400]!;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.zero, // Sharp
          border: Border.all(
            color: isSelected ? activeColor : borderColor,
            width: 1,
          ),
        ),
        child: Text(
          category.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : inactiveColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalCompanyCard(BuildContext context, CompanyModel company) {
    // Dynamic styles
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompanyDetailsScreen(company: company),
          ),
        );
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                image: company.profile.logoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(company.profile.logoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: company.profile.logoUrl.isEmpty
                  ? Icon(
                      Icons.business, // Standard icon
                      color: Colors.black,
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                company.profile.companyName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 180,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'No jobs available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new opportunities',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
