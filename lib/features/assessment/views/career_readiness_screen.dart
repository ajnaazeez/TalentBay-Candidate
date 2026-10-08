import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/assessment_model.dart';
import '../repositories/assessment_repository.dart';
import '../services/assessment_service.dart';
import 'assessment_screen.dart';
import '../../jobs/models/job_model.dart';
import '../../../core/theme/app_colors.dart';

/// Structured representation of an AI roadmap step
class RoadmapStepItem {
  final int stepNumber;
  final String title;
  final String description;
  final String actionHeader;
  final List<String> actionItems;

  const RoadmapStepItem({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.actionHeader,
    required this.actionItems,
  });
}

class CareerReadinessScreen extends ConsumerStatefulWidget {
  final String? jobId;

  const CareerReadinessScreen({super.key, this.jobId});

  @override
  ConsumerState<CareerReadinessScreen> createState() =>
      _CareerReadinessScreenState();
}

class _CareerReadinessScreenState
    extends ConsumerState<CareerReadinessScreen> {
  bool _isLoadingAi = false;
  String? _aiError;
  Map<String, dynamic>? _aiGuidance;
  JobModel? _targetJob;
  bool _isLoadingJob = false;

  /// Set of skill names whose detailed 4-step plan is expanded
  final Set<String> _expandedSkills = {};

  /// Scroll controller to allow auto-scrolling to roadmap when "Start Learning Plan" is tapped
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _roadmapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null && widget.jobId!.isNotEmpty) {
      _loadJobDetails(widget.jobId!);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadJobDetails(String jobId) async {
    setState(() => _isLoadingJob = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('jobs').doc(jobId).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _targetJob = JobModel.fromMap(doc.data()!);
        });
      }
    } catch (e) {
      debugPrint('Error loading job details for readiness: $e');
    } finally {
      if (mounted) setState(() => _isLoadingJob = false);
    }
  }

  Future<void> _fetchAiGuidance(Map<String, double> skillScores) async {
    if (_isLoadingAi) return;
    setState(() {
      _isLoadingAi = true;
      _aiError = null;
    });

    try {
      final targetSkills = _targetJob != null
          ? (_targetJob!.skillsRequired.isNotEmpty
              ? _targetJob!.skillsRequired
              : _targetJob!.mustHaveSkills)
          : null;

      final guidance = await AssessmentService.getCareerReadinessGuidance(
        skillScores: skillScores,
        targetJobTitle: _targetJob?.roleName,
        targetJobSkills: targetSkills,
      );

      if (mounted) {
        setState(() {
          _aiGuidance = guidance;
          _isLoadingAi = false;

          // Expand the top focus skill by default for immediate value
          final skillsList = guidance['skillsToStrengthen'] as List?;
          if (skillsList != null && skillsList.isNotEmpty) {
            final firstSkill = skillsList.first['skill']?.toString();
            if (firstSkill != null && firstSkill.isNotEmpty) {
              _expandedSkills.add(firstSkill.toLowerCase().trim());
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Career Readiness AI error: $e');
      if (mounted) {
        setState(() {
          _aiError =
              'AI suggestions are temporarily unavailable. Your skill scores are still displayed below.';
          _isLoadingAi = false;
        });
      }
    }
  }

  void _scrollToRoadmap(String skillName) {
    setState(() {
      _expandedSkills.add(skillName.toLowerCase().trim());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_roadmapKey.currentContext != null) {
        Scrollable.ensureVisible(
          _roadmapKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Parses raw roadmap steps (supports both structured JSON and plain string arrays)
  List<RoadmapStepItem> _parseSteps(dynamic rawSteps, String skillName) {
    if (rawSteps is! List || rawSteps.isEmpty) {
      return _generateDefaultSteps(skillName);
    }

    final parsed = <RoadmapStepItem>[];

    for (int i = 0; i < rawSteps.length; i++) {
      final item = rawSteps[i];

      if (item is Map) {
        // Structured JSON format from Cloud Function
        final stepNum = (item['stepNumber'] is num)
            ? (item['stepNumber'] as num).toInt()
            : (i + 1);
        final title = item['title']?.toString() ?? _defaultTitleForStep(stepNum);
        final description = item['description']?.toString() ?? '';
        final actionHeader =
            item['actionHeader']?.toString() ?? _defaultHeaderForStep(stepNum);
        final actionItems = (item['actionItems'] as List? ?? [])
            .map((s) => s.toString())
            .where((s) => s.isNotEmpty)
            .toList();

        parsed.add(
          RoadmapStepItem(
            stepNumber: stepNum,
            title: title,
            description: description,
            actionHeader: actionHeader,
            actionItems: actionItems.isNotEmpty
                ? actionItems
                : ['Focus on fundamental concepts and practical application.'],
          ),
        );
      } else if (item is String) {
        // Plain string format parsing (backward compatible)
        final cleanText = item.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '').trim();
        final stepNum = i + 1;
        final title = _defaultTitleForStep(stepNum);
        final actionHeader = _defaultHeaderForStep(stepNum);
        final items = _extractActionBullets(cleanText);

        parsed.add(
          RoadmapStepItem(
            stepNumber: stepNum,
            title: title,
            description: cleanText.length > 80
                ? '${cleanText.substring(0, 77)}...'
                : cleanText,
            actionHeader: actionHeader,
            actionItems: items,
          ),
        );
      }
    }

    return parsed;
  }

  String _defaultTitleForStep(int stepNum) {
    switch (stepNum) {
      case 1:
        return 'Build the basics';
      case 2:
        return 'Practice';
      case 3:
        return 'Go deeper';
      case 4:
        return 'Check your progress';
      default:
        return 'Step $stepNum';
    }
  }

  String _defaultHeaderForStep(int stepNum) {
    switch (stepNum) {
      case 1:
        return 'LEARN';
      case 2:
        return 'DO';
      case 3:
        return 'FOCUS ON';
      case 4:
        return 'CHECK YOUR PROGRESS';
      default:
        return 'ACTION ITEMS';
    }
  }

  List<String> _extractActionBullets(String text) {
    if (text.contains('•') || text.contains('- ')) {
      return text
          .split(RegExp(r'[•\-]\s*'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Split long sentence by key delimiters like " such as ", ", ", or " and "
    final parts = text
        .split(RegExp(r'(?:,?\s+such as\s+|,?\s+including\s+|,|;|\band\b)'))
        .map((s) => s.trim())
        .where((s) => s.length > 3)
        .toList();

    if (parts.length >= 2) {
      return parts;
    }

    return [text];
  }

  List<RoadmapStepItem> _generateDefaultSteps(String skillName) {
    return [
      RoadmapStepItem(
        stepNumber: 1,
        title: 'Build the basics',
        description: 'Review core definitions, formulas, and fundamental concepts.',
        actionHeader: 'LEARN',
        actionItems: [
          'Core principles & vocabulary',
          'Foundational syntax or design patterns',
        ],
      ),
      RoadmapStepItem(
        stepNumber: 2,
        title: 'Practice',
        description: 'Apply concepts through hands-on exercises and micro-projects.',
        actionHeader: 'DO',
        actionItems: [
          'Build a small sample project',
          'Solve practical exercise scenarios',
        ],
      ),
      RoadmapStepItem(
        stepNumber: 3,
        title: 'Go deeper',
        description: 'Explore advanced optimizations and best practices.',
        actionHeader: 'FOCUS ON',
        actionItems: [
          'Performance optimization',
          'Industry standard workflow patterns',
        ],
      ),
      RoadmapStepItem(
        stepNumber: 4,
        title: 'Check your progress',
        description: 'Verify your skills with an updated assessment.',
        actionHeader: 'CHECK YOUR PROGRESS',
        actionItems: [
          'Retake skill assessment to verify score improvement',
        ],
      ),
    ];
  }

  void _showReassessModal(
    BuildContext context,
    Map<String, double> candidateSkillScores,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Collect all job required skills or assessed skills
    final allSkills = <String>{};
    if (_targetJob != null) {
      final req = _targetJob!.skillsRequired.isNotEmpty
          ? _targetJob!.skillsRequired
          : _targetJob!.mustHaveSkills;
      allSkills.addAll(req);
    }
    allSkills.addAll(candidateSkillScores.keys);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Skill to Assess',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Retake an assessment after revising to measure your progress.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              if (allSkills.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No skills available yet.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allSkills.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final skill = allSkills.elementAt(idx);
                      final currentScore = candidateSkillScores[skill];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          skill,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          currentScore != null
                              ? 'Current score: ${currentScore.toInt()}%'
                              : 'Not assessed yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: currentScore != null
                                ? (currentScore >= 70
                                    ? Colors.green
                                    : Colors.orange)
                                : Colors.grey,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppColors.primaryBrand,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AssessmentScreen(
                                skill: skill,
                                difficulty: 'Medium',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E242B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prepare for Role')),
        body: const Center(child: Text('Please log in to view performance.')),
      );
    }

    final repo = ref.watch(assessmentRepositoryProvider);

    if (_isLoadingJob) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            'Prepare for Role',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: cardColor,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _targetJob != null ? 'Prepare for Role' : 'Personal Preparation Plan',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<List<AssessmentResult>>(
        stream: repo.getCandidateAssessments(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final assessments = snapshot.data ?? [];
          final skillScores =
              AssessmentRepository.extractLatestSkillScores(assessments);
          final overallReadiness =
              AssessmentRepository.calculateOverallPerformance(skillScores);

          // Job required skills (if target job)
          final requiredJobSkills = _targetJob != null
              ? (_targetJob!.skillsRequired.isNotEmpty
                  ? _targetJob!.skillsRequired
                  : _targetJob!.mustHaveSkills)
              : <String>[];

          final jobSkillMatch = _targetJob != null
              ? AssessmentRepository.calculateJobSkillMatch(
                  candidateSkillScores: skillScores,
                  requiredSkills: requiredJobSkills,
                )
              : overallReadiness;

          // Identify unassessed required skills
          final unassessedSkills = requiredJobSkills.where((reqSkill) {
            final normalizedKey = reqSkill.trim().toLowerCase();
            return !skillScores.keys.any((k) => k.trim().toLowerCase() == normalizedKey);
          }).toList();

          // Auto-trigger AI guidance fetch if guidance is null and not loading
          if (_aiGuidance == null && !_isLoadingAi && _aiError == null && skillScores.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchAiGuidance(skillScores);
            });
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP PREPARATION HERO SUMMARY CARD
                _buildHeroHeaderCard(
                  context,
                  jobTitle: _targetJob?.roleName,
                  companyName: _targetJob?.companyName,
                  matchScore: jobSkillMatch,
                  overallReadiness: overallReadiness,
                  unassessedCount: unassessedSkills.length,
                  totalAssessedCount: skillScores.length,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 2. "START HERE" TOP FOCUS BANNER
                _buildStartHereBanner(
                  context,
                  skillScores: skillScores,
                  unassessedSkills: unassessedSkills,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // 3. YOUR PREPARATION PRIORITIES (Skills You Can Strengthen)
                _buildPrioritySkillsSection(
                  context,
                  skillScores: skillScores,
                  requiredJobSkills: requiredJobSkills,
                  unassessedSkills: unassessedSkills,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // 4. ACTIONABLE AI IMPROVEMENT ROADMAP SECTION
                Container(key: _roadmapKey),
                _buildAiRoadmapSection(
                  context,
                  skillScores: skillScores,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // 5. READY TO CHECK YOUR PROGRESS? CTA
                _buildReassessCtaCard(
                  context,
                  skillScores: skillScores,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // 6. SUBTLE AI DISCLAIMER
                _buildSubtleAiDisclaimer(isDark: isDark),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 1. Hero Summary Header Widget
  Widget _buildHeroHeaderCard(
    BuildContext context, {
    required String? jobTitle,
    required String? companyName,
    required double matchScore,
    required double overallReadiness,
    required int unassessedCount,
    required int totalAssessedCount,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    final displayScore = jobTitle != null ? matchScore : overallReadiness;

    Color badgeBg;
    Color badgeFg;
    if (displayScore >= 75) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (displayScore >= 50) {
      badgeBg = const Color(0xFFE0F2FE);
      badgeFg = const Color(0xFF0369A1);
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFB45309);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jobTitle != null ? 'PREPARE FOR' : 'PREPARATION SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBrand,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jobTitle ?? 'Role Readiness Plan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (companyName != null && companyName.isNotEmpty)
                      Text(
                        companyName,
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                  ],
                ),
              ),

              // Match / Readiness Score Ring
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${displayScore.toInt()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: badgeFg,
                      ),
                    ),
                    Text(
                      jobTitle != null ? 'SKILL MATCH' : 'READINESS',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: badgeFg,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            jobTitle != null
                ? 'You\'re on a good start. Strengthen these key focus skills to improve your match score and readiness for this role.'
                : 'You\'re on a good start. Strengthen these key focus skills to maximize your overall career readiness.',
            style: TextStyle(
              fontSize: 13,
              color: subTextColor,
              height: 1.35,
            ),
          ),
          if (unassessedCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF451A03)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF78350F)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$unassessedCount required skill${unassessedCount == 1 ? '' : 's'} haven\'t been assessed yet',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 2. "START HERE" Top Priority Focus Card Widget
  Widget _buildStartHereBanner(
    BuildContext context, {
    required Map<String, double> skillScores,
    required List<String> unassessedSkills,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    if (skillScores.isEmpty && unassessedSkills.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine top focus skill: unassessed skill first, or skill with lowest score
    String topSkill;
    String topScoreLabel;
    String recommendation;

    if (unassessedSkills.isNotEmpty) {
      topSkill = unassessedSkills.first;
      topScoreLabel = 'Not assessed yet';
      recommendation =
          'Take this assessment first to discover your baseline readiness.';
    } else {
      final sortedAssessed = skillScores.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      topSkill = sortedAssessed.first.key;
      topScoreLabel = '${sortedAssessed.first.value.toInt()}%';
      recommendation =
          'Start with core concepts and fundamental topics to quickly raise your score.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2B3C), const Color(0xFF1E242B)]
              : [const Color(0xFFEFF6FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryBrand.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'START HERE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommended First Focus',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                topSkill,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  topScoreLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            recommendation,
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssessmentScreen(
                          skill: topSkill,
                          difficulty: 'Medium',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                  label: const Text(
                    'Start Learning Plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _scrollToRoadmap(topSkill),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBrand,
                  side: BorderSide(color: AppColors.primaryBrand.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Plan', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. Preparation Priorities (Skills You Can Strengthen) Widget
  Widget _buildPrioritySkillsSection(
    BuildContext context, {
    required Map<String, double> skillScores,
    required List<String> requiredJobSkills,
    required List<String> unassessedSkills,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    final sortedAssessed = skillScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Preparation Priorities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              'Sorted by priority',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Focus on skills with lower scores or unassessed gaps first.',
          style: TextStyle(fontSize: 12, color: subTextColor),
        ),
        const SizedBox(height: 12),

        // Render Unassessed Skills Cards
        if (unassessedSkills.isNotEmpty)
          ...unassessedSkills.map((skill) {
            return _buildSkillPriorityCard(
              context,
              skillName: skill,
              score: null,
              isUnassessed: true,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              subTextColor: subTextColor,
              isDark: isDark,
            );
          }),

        // Render Assessed Skills Cards
        ...sortedAssessed.map((entry) {
          return _buildSkillPriorityCard(
            context,
            skillName: entry.key,
            score: entry.value,
            isUnassessed: false,
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
          );
        }),
      ],
    );
  }

  Widget _buildSkillPriorityCard(
    BuildContext context, {
    required String skillName,
    required double? score,
    required bool isUnassessed,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    final isExpanded = _expandedSkills.contains(skillName.toLowerCase().trim());

    String statusLabel;
    Color statusBg;
    Color statusFg;
    String reasonText;

    if (isUnassessed) {
      statusLabel = 'Not assessed yet';
      statusBg = isDark ? const Color(0xFF3B2D13) : const Color(0xFFFEF3C7);
      statusFg = isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706);
      reasonText =
          'Required for this role but not evaluated yet. Assess to establish baseline.';
    } else {
      final s = score!;
      if (s >= 80) {
        statusLabel = 'Already strong';
        statusBg = isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        statusFg = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        reasonText =
            'Great score! Review advanced practical topics to keep skills sharp.';
      } else if (s >= 60) {
        statusLabel = 'Good start';
        statusBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
        statusFg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        reasonText =
            'Solid foundation. Practice practical scenarios to boost your confidence.';
      } else {
        statusLabel = 'Needs improvement';
        statusBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFFEDD5);
        statusFg = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
        reasonText =
            'This is one of your priority focus areas to strengthen.';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? AppColors.primaryBrand : borderColor,
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        skillName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      score != null ? '${score.toInt()}%' : '--',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                if (!isUnassessed) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (score! / 100).clamp(0.0, 1.0),
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      color: statusFg,
                      minHeight: 6,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  reasonText,
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSkills.remove(skillName.toLowerCase().trim());
                      } else {
                        _expandedSkills.add(skillName.toLowerCase().trim());
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isExpanded ? 'Hide plan' : 'View 4-step plan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBrand,
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.primaryBrand,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Actionable AI Improvement Roadmap Section Widget
  Widget _buildAiRoadmapSection(
    BuildContext context, {
    required Map<String, double> skillScores,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Step-by-Step Roadmap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (_aiGuidance != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => _fetchAiGuidance(skillScores),
                tooltip: 'Refresh AI Roadmap',
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Actionable steps designed to systematically improve your readiness.',
          style: TextStyle(fontSize: 12, color: subTextColor),
        ),
        const SizedBox(height: 12),

        // Loading State
        if (_isLoadingAi)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                CircularProgressIndicator(color: AppColors.primaryBrand),
                const SizedBox(height: 12),
                Text(
                  'Building your custom preparation roadmap with AI...',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),

        // Error State (Graceful fallback)
        if (_aiError != null && !_isLoadingAi)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Text(
                  _aiError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _fetchAiGuidance(skillScores),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),

        // Loaded AI Content State
        if (_aiGuidance != null && !_isLoadingAi) ...[
          // Overall Summary Banner
          if (_aiGuidance!['overallSummary'] != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppColors.primaryBrand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI SUMMARY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBrand,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _aiGuidance!['overallSummary'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Skill Roadmaps
          if (_aiGuidance!['skillsToStrengthen'] is List) ...[
            ...(_aiGuidance!['skillsToStrengthen'] as List).map((item) {
              if (item is! Map) return const SizedBox.shrink();

              final skillName = item['skill']?.toString() ?? 'Skill';
              final guidanceText = item['guidance']?.toString() ?? '';
              final steps = _parseSteps(item['roadmapSteps'], skillName);

              final isExpanded =
                  _expandedSkills.contains(skillName.toLowerCase().trim());

              if (!isExpanded) {
                return const SizedBox.shrink(); // Progressive disclosure: only rendered when expanded
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryBrand.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: AppColors.primaryBrand,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              skillName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBrand.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YOUR PLAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBrand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (guidanceText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        guidanceText,
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Render 4 Actionable Steps
                    ...steps.map((step) {
                      return _buildStepCard(
                        context,
                        step: step,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        isDark: isDark,
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  /// Single Actionable Step Card
  Widget _buildStepCard(
    BuildContext context, {
    required RoadmapStepItem step,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    IconData stepIcon;
    switch (step.stepNumber) {
      case 1:
        stepIcon = Icons.menu_book_rounded;
        break;
      case 2:
        stepIcon = Icons.code_rounded;
        break;
      case 3:
        stepIcon = Icons.psychology_rounded;
        break;
      case 4:
        stepIcon = Icons.fact_check_rounded;
        break;
      default:
        stepIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15191E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${step.stepNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'STEP ${step.stepNumber} — ${step.title.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(stepIcon, size: 16, color: subTextColor),
            ],
          ),
          if (step.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              step.description,
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            step.actionHeader,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBrand,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          ...step.actionItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: AppColors.primaryBrand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 12, color: textColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 5. Reassess CTA Card Widget
  Widget _buildReassessCtaCard(
    BuildContext context, {
    required Map<String, double> skillScores,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'READY TO CHECK YOUR PROGRESS?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Improve your skills and retake the assessment to see your progress.',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showReassessModal(context, skillScores),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
              label: const Text('Reassess Skills'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBrand,
                side: BorderSide(color: AppColors.primaryBrand),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Subtle AI Disclaimer Widget
  Widget _buildSubtleAiDisclaimer({required bool isDark}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'AI guidance is based on your assessment and job requirements. It is intended as guidance and does not guarantee job selection.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
