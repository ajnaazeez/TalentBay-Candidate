import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../candidate/controllers/candidate_controller.dart';

import '../../../assessment/repositories/assessment_repository.dart';
import '../../../assessment/views/assessment_screen.dart';
import '../../../assessment/models/assessment_model.dart';
import '../../../assessment/services/assessment_service.dart';
import '../../../../core/utils/color_helper.dart';
import 'package:talentbay_candidate/features/payment/views/subscription_prompt_dialog.dart';

class ExploreTab extends ConsumerStatefulWidget {
  const ExploreTab({super.key});

  @override
  ConsumerState<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<ExploreTab> {
  // Cache for related skills to avoid re-fetching on every build
  Future<List<String>>? _relatedSkillsFuture;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final candidateState = ref.watch(candidateControllerProvider);
    final candidate = candidateState.value;

    if (candidate == null) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Get candidate's skills
    final candidateSkills = candidate.skills.map((s) => s.name).toList();

    // Initialize related skills fetch if not already done
    if (_relatedSkillsFuture == null && candidateSkills.isNotEmpty) {
      _relatedSkillsFuture = AssessmentService.getRelatedSkills(
        candidateSkills,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            backgroundColor: backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
              title: Text(
                'ASSESSMENTS',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  fontFamily: 'Futura',
                ),
              ),
              background: Container(color: backgroundColor),
            ),
          ),

          // Assessment Stats
          SliverToBoxAdapter(
            child: StreamBuilder<List<AssessmentResult>>(
              stream: ref
                  .watch(assessmentRepositoryProvider)
                  .getCandidateAssessments(candidate.uid),
              builder: (context, snapshot) {
                final assessments = snapshot.data ?? [];
                final completedCount = assessments.length;
                final averageScore = assessments.isEmpty
                    ? 0.0
                    : assessments
                              .map((a) => a.percentage)
                              .reduce((a, b) => a + b) /
                          assessments.length;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: AppColors.primaryBrand.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'COMPLETED',
                            completedCount.toString(),
                            isDark: isDark,
                          ),
                          _buildStatItem(
                            'AVG SCORE',
                            '${averageScore.toInt()}%',
                            isDark: true,
                            valueColor: ColorHelper.getColorForScore(
                              averageScore,
                            ),
                          ),
                          _buildStatItem(
                            'SKILLS',
                            candidateSkills.length.toString(),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primaryBrand.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: AppColors.primaryBrand,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI-POWERED ASSESSMENTS ACTIVE',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Your Skills Section
          if (candidateSkills.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Text(
                  'YOUR SKILLS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[400],
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: StreamBuilder<List<AssessmentResult>>(
                stream: ref
                    .watch(assessmentRepositoryProvider)
                    .getCandidateAssessments(candidate.uid),
                builder: (context, snapshot) {
                  final assessments = snapshot.data ?? [];

                  // Group assessments by skill
                  final Map<String, List<AssessmentResult>> assessmentMap = {};
                  for (var a in assessments) {
                    if (!assessmentMap.containsKey(a.skill)) {
                      assessmentMap[a.skill] = [];
                    }
                    assessmentMap[a.skill]!.add(a);
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final skill = candidateSkills[index];
                      final skillAssessments = assessmentMap[skill] ?? [];

                      return _buildSkillCard(
                        skill,
                        skillAssessments,
                        isYourSkill: true,
                      );
                    }, childCount: candidateSkills.length),
                  );
                },
              ),
            ),
          ],

          // Related Skills Section
          if (_relatedSkillsFuture != null)
            SliverToBoxAdapter(
              child: FutureBuilder<List<String>>(
                future: _relatedSkillsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final relatedSkills = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                        child: Text(
                          'RECOMMENDED FOR YOU',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey[400],
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: relatedSkills.map((skill) {
                            return StreamBuilder<List<AssessmentResult>>(
                              stream: ref
                                  .watch(assessmentRepositoryProvider)
                                  .getCandidateAssessments(candidate.uid),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  debugPrint(
                                    'Error loading assessments: ${snapshot.error}',
                                  );
                                  // Return basic card without assessment info if error
                                  return _buildSkillCard(
                                    skill,
                                    [],
                                    isYourSkill: false,
                                  );
                                }

                                final assessments = snapshot.data ?? [];
                                // Filter assessments for this specific skill (case-insensitive)
                                final skillAssessments = assessments
                                    .where(
                                      (a) =>
                                          a.skill.toLowerCase() ==
                                          skill.toLowerCase(),
                                    )
                                    .toList();

                                return _buildSkillCard(
                                  skill,
                                  skillAssessments,
                                  isYourSkill: false,
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value, {
    bool isDark = false,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: valueColor ?? (isDark ? Colors.white : Colors.black),
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withOpacity(0.6) : Colors.grey[400],
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillCard(
    String skill,
    List<AssessmentResult> assessments, {
    required bool isYourSkill,
  }) {
    final hasAssessment = assessments.isNotEmpty;
    // Get the highest level completed
    AssessmentResult? bestAssessment;
    if (hasAssessment) {
      // Logic to find best assessment could be highest score or highest difficulty
      // For now, let's just show the most recent one or highest difficulty
      // Sorting: Mix > Hard > Medium > Easy
      assessments.sort((a, b) {
        final difficultyOrder = {'Easy': 1, 'Medium': 2, 'Hard': 3, 'Mixed': 4};
        final diffA = difficultyOrder[a.difficulty] ?? 0;
        final diffB = difficultyOrder[b.difficulty] ?? 0;
        return diffB.compareTo(diffA);
      });
      bestAssessment = assessments.first;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.grey[200]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDifficultySelection(
            skill,
            assessments,
          ), // Pass all assessments
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Skill Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              skill.toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isYourSkill) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBrand,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                'ADDED',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (hasAssessment && bestAssessment != null)
                        Row(
                          children: [
                            Text(
                              bestAssessment.proficiencyLevel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•   ${bestAssessment.percentage.toInt()}% SCORE',
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorHelper.getColorForScore(
                                  bestAssessment.percentage,
                                ),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                bestAssessment.difficulty.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '15 QUESTIONS • ~10 MIN',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

                // Action
                Icon(
                  Icons.arrow_forward,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDifficultySelection(
    String skill,
    List<AssessmentResult> completedAssessments,
  ) {
    final candidate = ref.read(candidateControllerProvider).value;
    if (candidate != null && !candidate.isPremium) {
      SubscriptionPromptDialog.show(context);
      return;
    }

    // Check completion status for each level
    // Case insensitive comparison for safety
    bool isCompleted(String difficulty) {
      return completedAssessments.any(
        (a) => a.difficulty.toLowerCase() == difficulty.toLowerCase(),
      );
    }

    final isEasyCompleted = isCompleted('Easy');
    final isMediumCompleted = isCompleted('Medium');
    final isHardCompleted = isCompleted('Hard');
    final isMixedCompleted = isCompleted('Mixed');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.shortestSide >= 600 ? 550 : double.infinity,
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SELECT DIFFICULTY',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildDifficultyOption(
              skill,
              'Easy',
              'Perfect for beginners starting their journey.',
              isLocked: false, // Easy is always unlocked
              isCompleted: isEasyCompleted,
            ),
            _buildDifficultyOption(
              skill,
              'Medium',
              'Test your core knowledge and practical skills.',
              isLocked: !isEasyCompleted, // Locked if Easy not completed
              isCompleted: isMediumCompleted,
            ),
            _buildDifficultyOption(
              skill,
              'Hard',
              'Challenge yourself with advanced complex concepts.',
              isLocked: !isMediumCompleted, // Locked if Medium not completed
              isCompleted: isHardCompleted,
            ),
            _buildDifficultyOption(
              skill,
              'Mixed',
              'A balanced set of questions across all levels.',
              isLocked: !isHardCompleted, // Locked if Hard not completed
              isCompleted: isMixedCompleted,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(
    String skill,
    String level,
    String description, {
    bool isLocked = false,
    bool isCompleted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = isLocked || isCompleted;

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AssessmentScreen(skill: skill, difficulty: level),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isLocked
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black),
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                      ],
                      if (isLocked) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock, size: 14, color: Colors.grey),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isDisabled)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
          ],
        ),
      ),
    );
  }
}
