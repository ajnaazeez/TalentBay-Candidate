import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/storage_service.dart';

import '../../auth/models/candidate_model.dart';
import '../../candidate/controllers/candidate_controller.dart';
import '../../candidate/models/profile_sections.dart';
import 'forms/add_edit_education_screen.dart';
import 'forms/add_edit_experience_screen.dart';
import 'forms/add_edit_project_screen.dart';
import 'widgets/edit_job_preference_dialog.dart';
import 'widgets/edit_skills_dialog.dart';
import 'widgets/edit_summary_dialog.dart';
import 'widgets/resume_section.dart';
import '../../assessment/repositories/assessment_repository.dart';
import '../../assessment/models/assessment_model.dart';
import '../../jobs/repositories/job_repository.dart';
import '../../jobs/models/job_application_model.dart';
import '../utils/profile_completion_calculator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/firebase_error_handler.dart';
import '../../../core/theme/app_colors.dart';
import 'package:talentbay_candidate/features/payment/views/subscription_prompt_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // Recalculate profile completion on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateProfileCompletion();
    });
  }

  Future<void> _recalculateProfileCompletion() async {
    try {
      final candidateState = ref.read(candidateControllerProvider);
      candidateState.whenData((candidate) async {
        if (candidate != null) {
          final currentCompletion = candidate.profileCompletionPercentage;
          final calculatedCompletion = ProfileCompletionCalculator.calculate(
            candidate,
          );

          // Only update if there's a difference
          if ((currentCompletion - calculatedCompletion).abs() > 0.01) {
            await ref
                .read(candidateControllerProvider.notifier)
                .updateProfile(
                  candidate.copyWith(
                    profileCompletionPercentage: calculatedCompletion,
                  ),
                );
          }
        }
      });
    } catch (e) {
      debugPrint('Error recalculating profile completion: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile(
    CandidateModel candidate, {
    String? successMessage,
  }) async {
    try {
      await ref
          .read(candidateControllerProvider.notifier)
          .updateProfile(candidate);
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating profile: ${FirebaseErrorHandler.getMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(
    CandidateModel candidate,
    ImageSource source,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading profile picture...')),
          );
        }

        final storageService = ref.read(storageServiceProvider);

        // Delete old profile image(s) first before uploading the new one
        try {
          await storageService.deleteProfileImage(candidate.uid);
        } catch (storageError) {
          debugPrint('Failed to delete old image: $storageError');
        }

        final String imageUrl = await storageService.uploadProfileImage(
          candidate.uid,
          File(image.path),
        );

        await _updateProfile(
          candidate.copyWith(photoUrl: imageUrl),
          successMessage: 'Profile picture updated successfully',
        );
      }
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile picture: ${FirebaseErrorHandler.getMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeProfileImage(CandidateModel candidate) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removing profile picture...')),
        );
      }

      final storageService = ref.read(storageServiceProvider);
      try {
        await storageService.deleteProfileImage(candidate.uid);
      } catch (storageError) {
        debugPrint('Failed to delete image: $storageError');
      }

      await _updateProfile(
        candidate.copyWith(photoUrl: ''),
        successMessage: 'Profile picture removed successfully',
      );
    } catch (e) {
      debugPrint('Error removing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove profile picture: ${FirebaseErrorHandler.getMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  void _showImageOptions(CandidateModel candidate) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPhoto =
        candidate.photoUrl != null && candidate.photoUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.shortestSide >= 600 ? 550 : double.infinity,
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROFILE PICTURE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(candidate, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(candidate, ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfileImage(candidate);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidateState = ref.watch(candidateControllerProvider);

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: candidateState.when(
        data: (candidate) {
          if (candidate == null) {
            return const Center(child: Text('No Profile Found'));
          }

          return CustomScrollView(
            slivers: [
              // Minimalist App Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                expandedHeight: 120,

                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
                  title: Text(
                    'MY PROFILE',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontFamily: 'Futura',
                    ),
                  ),
                  background: Container(color: theme.scaffoldBackgroundColor),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SafeArea(
                    // Added SafeArea
                    top: false, // Top is handled by SliverAppBar
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildProfileHeader(candidate),
                          const SizedBox(height: 32),
                          _buildStatsCards(candidate),
                          const SizedBox(height: 32),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.12,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildCVHeadline(candidate),
                          const SizedBox(height: 32),
                          _buildKeySkills(candidate),
                          const SizedBox(height: 32),
                          _buildSkillAssessments(candidate),
                          const SizedBox(height: 32),
                          _buildEmploymentDetails(candidate),
                          const SizedBox(height: 32),
                          _buildEducation(candidate),
                          const SizedBox(height: 32),
                          _buildProjects(candidate),
                          const SizedBox(height: 32),
                          _buildPersonalDetails(candidate),
                          const SizedBox(height: 32),
                          _buildDesiredJobs(candidate),
                          const SizedBox(height: 32),
                          _buildAttachedCV(candidate),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primaryBrand),
        ),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget content,
    VoidCallback? onEdit,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else if (onAction != null && actionLabel != null)
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
                label: Text(
                  actionLabel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildStatsCards(CandidateModel candidate) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<JobApplicationModel>>(
      stream: ref
          .read(jobRepositoryProvider)
          .getCandidateApplications(user.uid),
      builder: (context, snapshot) {
        final applicationsCount = snapshot.hasData ? snapshot.data!.length : 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'APPLICATIONS',
                  value: '$applicationsCount',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'SKILLS',
                  value: '${candidate.skills.length}',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'PROFILE\nCOMPLETION',
                  value:
                      '${(candidate.profileCompletionPercentage * 100).toInt()}%',
                  valueColor: ColorHelper.getColorForScore(
                    candidate.profileCompletionPercentage * 100,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300, // Light/Thin font for numbers
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(CandidateModel candidate) {
    // Calculate total experience
    final totalExp = _calculateTotalExperience(candidate.workExperience);
    final totalExpString = totalExp > 0
        ? '$totalExp Years Experience'
        : 'Fresher';
    final theme = Theme.of(context);

    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => _showImageOptions(candidate),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.onSurface.withOpacity(0.04),
                    image:
                        candidate.photoUrl != null &&
                            candidate.photoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(candidate.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: candidate.photoUrl == null || candidate.photoUrl!.isEmpty
                      ? Center(
                          child: Text(
                            (candidate.firstName?.isNotEmpty == true
                                    ? candidate.firstName![0]
                                    : 'U')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showImageOptions(candidate),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: theme.scaffoldBackgroundColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        if (candidate.isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 14, color: Colors.black),
                SizedBox(width: 4),
                Text(
                  'PREMIUM MEMBER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: () {
              SubscriptionPromptDialog.show(context);
            },
            icon: const Icon(Icons.workspace_premium, size: 16),
            label: const Text('Upgrade to Premium'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBrand,
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Text(
                '${candidate.firstName ?? "Your"} ${candidate.lastName ?? "Name"}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.normal, // Regular weight, not bold
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (candidate.bio != null && candidate.bio!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  candidate.bio!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
              ],
              if (candidate.designation != null &&
                  candidate.designation!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  candidate.designation!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 1.0,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
              if (candidate.aboutMe != null &&
                  candidate.aboutMe!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    candidate.aboutMe!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.normal,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                totalExpString,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 16),
              // Contact Row
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  if (candidate.currentLocation != null)
                    _buildCompactContactInfo(
                      '${candidate.currentLocation!.city}, ${candidate.currentLocation!.country}',
                    ),
                  if (candidate.currentLocation != null)
                    Text(
                      "•",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  _buildCompactContactInfo(candidate.email),
                  if (candidate.phoneNumber?.isNotEmpty == true) ...[
                    Text(
                      "•",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    _buildCompactContactInfo(candidate.phoneNumber!),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  context.push('/profile/edit-basic');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBrand,
                  side: const BorderSide(color: AppColors.primaryBrand),
                  shape: const RoundedRectangleBorder(), // Square/sharp
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('EDIT INTRODUCTION'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContactInfo(String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  Widget _buildCVHeadline(CandidateModel candidate) {
    final theme = Theme.of(context);
    return _buildSectionCard(
      title: 'CV Headline',
      onEdit: () {
        showDialog(
          context: context,
          builder: (context) => EditSummaryDialog(
            initialBio: candidate.bio ?? '',
            initialAboutMe: candidate.aboutMe ?? '',
            onSave: (newBio, newAboutMe) {
              _updateProfile(
                candidate.copyWith(bio: newBio, aboutMe: newAboutMe),
              );
            },
          ),
        );
      },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (candidate.bio != null && candidate.bio!.isNotEmpty)
            Text(
              candidate.bio!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            candidate.aboutMe ?? 'Add a professional description...',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.87),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withOpacity(0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep it updated for better job opportunities',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeySkills(CandidateModel candidate) {
    final theme = Theme.of(context);
    return _buildSectionCard(
      title: 'Key Skills',
      onEdit: () {
        showDialog(
          context: context,
          builder: (context) => EditSkillsDialog(
            initialSkills: candidate.skills,
            onSave: (skills) {
              _updateProfile(candidate.copyWith(skills: skills));
            },
          ),
        );
      },
      content: candidate.skills.isEmpty
          ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 32,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No skills added yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => EditSkillsDialog(
                          initialSkills: [],
                          onSave: (skills) {
                            _updateProfile(candidate.copyWith(skills: skills));
                          },
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: theme.colorScheme.onSurface,
                    ),
                    label: const Text('Add Skills'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidate.skills
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.zero, // Sharp corners
                        border: Border.all(
                          color: theme.colorScheme.onSurface,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        s.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSkillAssessments(CandidateModel candidate) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AssessmentResult>>(
      stream: ref
          .read(assessmentRepositoryProvider)
          .getCandidateAssessments(candidate.uid),
      builder: (context, snapshot) {
        final assessments = snapshot.data ?? [];

        if (assessments.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort assessments: Skill Name -> Difficulty (Easy -> Medium -> Hard -> Mixed)
        assessments.sort((a, b) {
          int skillComp = a.skill.compareTo(b.skill);
          if (skillComp != 0) return skillComp;

          final difficultyOrder = {
            'Easy': 1,
            'Medium': 2,
            'Hard': 3,
            'Mixed': 4,
          };
          final diffA = difficultyOrder[a.difficulty] ?? 0;
          final diffB = difficultyOrder[b.difficulty] ?? 0;
          return diffA.compareTo(diffB);
        });

        return _buildSectionCard(
          title: 'Skill Assessments',
          content: Column(
            children: assessments.map((assessment) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.onSurface.withOpacity(0.12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assessment.skill.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${assessment.difficulty} • ${assessment.proficiencyLevel}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${assessment.percentage.toInt()}% Score',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorHelper.getColorForScore(
                                assessment.percentage,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.verified,
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPersonalDetails(CandidateModel candidate) {
    return _buildSectionCard(
      title: 'Personal Details',
      onEdit: () {
        context.push('/profile/edit-basic');
      },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            'Date of Birth',
            candidate.dob != null ? _formatDate(candidate.dob!) : 'Add DOB',
          ),
          _buildDetailRow('Gender', candidate.gender ?? 'Add Gender'),
          _buildDetailRow(
            'Nationality',
            candidate.nationality ?? 'Add Nationality',
          ),
          _buildDetailRow(
            'Current City',
            candidate.currentLocation?.city ?? 'Add City',
          ),
          _buildDetailRow(
            'Country',
            candidate.currentLocation?.country ?? 'Add Country',
          ),
          _buildDetailRow(
            'Languages Known',
            candidate.languages.keys.join(', ').isEmpty
                ? 'Add Languages'
                : candidate.languages.keys.join(', '),
          ),
          _buildDetailRow(
            'LinkedIn',
            candidate.linkedinProfile != null &&
                    candidate.linkedinProfile!.isNotEmpty
                ? candidate.linkedinProfile!
                : 'Add LinkedIn',
            isLink: true,
          ),
          _buildDetailRow('Email', candidate.email),
        ],
      ),
    );
  }

  Widget _buildEmploymentDetails(CandidateModel candidate) {
    final theme = Theme.of(context);
    return _buildSectionCard(
      title: 'Employment Details',
      actionLabel: candidate.workExperience.isEmpty ? 'Add Experience' : 'Add',
      onAction: () async {
        final result = await Navigator.push<WorkExperience>(
          context,
          MaterialPageRoute(
            builder: (context) => const AddEditExperienceScreen(),
          ),
        );
        if (result != null) {
          final updatedList = List<WorkExperience>.from(
            candidate.workExperience,
          )..add(result);
          _updateProfile(candidate.copyWith(workExperience: updatedList));
        }
      },
      content: candidate.workExperience.isEmpty
          ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 32,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No work experience added yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: candidate.workExperience.map((exp) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Simple Dot
                      Container(
                        margin: const EdgeInsets.all(5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    exp.jobTitle.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final result =
                                        await Navigator.push<WorkExperience>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddEditExperienceScreen(
                                                  initialExperience: exp,
                                                ),
                                          ),
                                        );
                                    if (result != null) {
                                      final updatedList =
                                          List<WorkExperience>.from(
                                            candidate.workExperience,
                                          );
                                      final idx = updatedList.indexWhere(
                                        (e) => e.id == exp.id,
                                      );
                                      if (idx != -1) {
                                        updatedList[idx] = result;
                                        _updateProfile(
                                          candidate.copyWith(
                                            workExperience: updatedList,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exp.companyName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('MMM yyyy').format(exp.startDate)} - ${exp.endDate != null ? DateFormat('MMM yyyy').format(exp.endDate!) : 'Present'} • ${_calculateDuration(exp.startDate, exp.endDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                              ),
                            ),
                            if (exp.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                exp.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEducation(CandidateModel candidate) {
    final theme = Theme.of(context);
    return _buildSectionCard(
      title: 'Education',
      actionLabel: candidate.education.isEmpty ? 'Add Education' : 'Add',
      onAction: () async {
        final result = await Navigator.push<Education>(
          context,
          MaterialPageRoute(
            builder: (context) => const AddEditEducationScreen(),
          ),
        );
        if (result != null) {
          final updatedList = List<Education>.from(candidate.education)
            ..add(result);
          _updateProfile(candidate.copyWith(education: updatedList));
        }
      },
      content: candidate.education.isEmpty
          ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No education added yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: candidate.education.map((edu) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    edu.degree.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final result =
                                        await Navigator.push<Education>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddEditEducationScreen(
                                                  initialEducation: edu,
                                                ),
                                          ),
                                        );
                                    if (result != null) {
                                      final updatedList = List<Education>.from(
                                        candidate.education,
                                      );
                                      final idx = updatedList.indexWhere(
                                        (e) => e.id == edu.id,
                                      );
                                      if (idx != -1) {
                                        updatedList[idx] = result;
                                        _updateProfile(
                                          candidate.copyWith(
                                            education: updatedList,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              edu.institution,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${edu.startYear} - ${edu.endYear}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDesiredJobs(CandidateModel candidate) {
    final theme = Theme.of(context);
    final pref = candidate.jobPreference;
    return _buildSectionCard(
      title: 'Desired Jobs',
      onEdit: () {
        showDialog(
          context: context,
          builder: (context) => EditJobPreferenceDialog(
            initialPreference: candidate.jobPreference,
            onSave: (pref) {
              _updateProfile(candidate.copyWith(jobPreference: pref));
            },
          ),
        );
      },
      content: pref == null
          ? Text(
              'Add your job preferences to get better recommendations',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.87),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubDetail('Preferred Designations', pref.role),
                const SizedBox(height: 12),
                _buildSubDetail(
                  'Preferred Locations',
                  pref.preferredLocations.join(', '),
                ),
                const SizedBox(height: 12),
                _buildSubDetail(
                  'Preferred Industry',
                  pref.preferredIndustry.isEmpty
                      ? 'Not specified'
                      : pref.preferredIndustry,
                ),
                const SizedBox(height: 12),
                _buildSubDetail(
                  'Work Mode',
                  '${pref.workMode} • ${pref.employmentType}',
                ),
              ],
            ),
    );
  }

  Widget _buildAttachedCV(CandidateModel candidate) {
    return _buildSectionCard(
      title: 'Attached CV',
      content: ResumeSection(
        resumeUrl: candidate.resumeUrl,
        onUpload: (platformFile) async {
          try {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uploading resume...')),
              );
            }

            final storageService = ref.read(storageServiceProvider);
            // Convert PlatformFile to File
            final file = File(platformFile.path!);

            final String resumeUrl = await storageService.uploadResume(
              candidate.uid,
              file,
            );

            // Update profile with resume URL
            await _updateProfile(
              candidate.copyWith(resumeUrl: resumeUrl),
              successMessage: 'Resume uploaded successfully',
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to upload resume: ${FirebaseErrorHandler.getMessage(e)}',
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLink = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          isLink
              ? GestureDetector(
                  onTap: () async {
                    final Uri uri = Uri.parse(value);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.87),
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSubDetail(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  // Helpers
  int _calculateTotalExperience(List<WorkExperience> experiences) {
    if (experiences.isEmpty) return 0;
    // Simple verification - sum of durations
    // Ideally need to handle overlaps
    int totalMonths = 0;
    for (var exp in experiences) {
      final end = exp.endDate ?? DateTime.now();
      final start = exp.startDate;
      final difference = end.difference(start).inDays;
      totalMonths += (difference / 30).round();
    }
    return (totalMonths / 12).floor();
  }

  String _calculateDuration(DateTime start, DateTime? end) {
    final endDate = end ?? DateTime.now();
    final difference = endDate.difference(start);
    final years = (difference.inDays / 365).floor();
    final months = ((difference.inDays % 365) / 30).floor();

    if (years > 0) {
      if (months > 0) {
        return '$years Year $months Months';
      }
      return '$years Year';
    }
    return '$months Months';
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  Widget _buildProjects(CandidateModel candidate) {
    final theme = Theme.of(context);
    return _buildSectionCard(
      title: 'Projects',
      actionLabel: candidate.projects.isEmpty ? 'Add Projects' : 'Add',
      onAction: () async {
        final result = await Navigator.push<Project>(
          context,
          MaterialPageRoute(builder: (context) => const AddEditProjectScreen()),
        );
        if (result != null) {
          final updatedList = List<Project>.from(candidate.projects)
            ..add(result);
          _updateProfile(candidate.copyWith(projects: updatedList));
        }
      },
      content: candidate.projects.isEmpty
          ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No projects added yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: candidate.projects.map((project) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    project.title.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final result =
                                        await Navigator.push<Project>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddEditProjectScreen(
                                                  initialProject: project,
                                                ),
                                          ),
                                        );
                                    if (result != null) {
                                      final updatedList = List<Project>.from(
                                        candidate.projects,
                                      );
                                      final index = updatedList.indexWhere(
                                        (e) => e.id == project.id,
                                      );
                                      if (index != -1) {
                                        updatedList[index] = result;
                                        _updateProfile(
                                          candidate.copyWith(
                                            projects: updatedList,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.role,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                            if (project.technologies.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: project.technologies.map((tech) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.04),
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: Text(
                                      tech,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (project.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                project.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (project.link != null &&
                                project.link!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.link,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final Uri uri = Uri.parse(
                                          project.link!,
                                        );
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        }
                                      },
                                      child: Text(
                                        project.link!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
