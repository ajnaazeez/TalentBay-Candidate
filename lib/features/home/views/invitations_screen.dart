import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../candidate/controllers/candidate_controller.dart';
import '../../jobs/repositories/job_repository.dart';
import '../../jobs/models/job_model.dart';
import '../../jobs/models/job_application_model.dart';
import 'widgets/job_card.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:talentbay_candidate/features/payment/views/subscription_prompt_dialog.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidateState = ref.watch(candidateControllerProvider);
    final uid = candidateState.value?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final jobRepo = ref.watch(jobRepositoryProvider);

    // H&M Aesthetic - Dynamic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'INVITATIONS', // All caps consistency
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.0,
            color: textColor,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<List<JobApplicationModel>>(
        stream: jobRepo.getInvites(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final invites = snapshot.data ?? [];

          if (invites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'NO INVITATIONS YET',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: subTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              return _InvitationCard(invite: invite);
            },
          );
        },
      ),
    );
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  final JobApplicationModel invite;

  const _InvitationCard({required this.invite});

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final jobRepo = ref.watch(jobRepositoryProvider);

    return FutureBuilder<JobModel?>(
      future: jobRepo.getJob(widget.invite.jobId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final job = snapshot.data!;

        return Column(
          children: [
            // Reusing JobCard for job details
            JobCard(
              job: job,
              isApplied: false,
              isInvited: true,
              onTap: () {
                // Navigate to details if needed, logic is inside JobCard usually or handled by parent.
                // JobCard handles onTap. But here we might want to disable it or allow viewing details.
                // Let's passed null or navigation.
              },
            ),

            // Action Buttons
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          try {
                            await jobRepo.declineInvitation(
                              widget.invite.applicationId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invitation declined'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('DECLINE'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final candidate = ref
                              .read(candidateControllerProvider)
                              .value;
                          if (candidate != null && !candidate.isPremium) {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  const SubscriptionPromptDialog(),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            await jobRepo.acceptInvitation(
                              widget.invite.applicationId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invitation Accepted!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('ACCEPT'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
