import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../notification/providers/notification_provider.dart';
import '../../../core/theme/app_colors.dart';

class JobInvitationScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String notificationId; // Added to easily mark action

  const JobInvitationScreen({
    Key? key,
    required this.jobId,
    required this.notificationId,
  }) : super(key: key);

  @override
  ConsumerState<JobInvitationScreen> createState() =>
      _JobInvitationScreenState();
}

class _JobInvitationScreenState extends ConsumerState<JobInvitationScreen> {
  bool _isLoading = false;

  Future<void> _handleAction(String action) async {
    setState(() => _isLoading = true);
    try {
      if (widget.notificationId.isNotEmpty) {
        await ref
            .read(notificationNotifierProvider.notifier)
            .performAction(widget.notificationId, action);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Successfully marked as $action')));
      context.pop(); // Go back after action
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // In a real app we would load the specific job detail based on jobId using a FutureProvider/StreamProvider
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'You have a new Job Invitation!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job ID placeholder: ${widget.jobId}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'A recruiter thinks you are a great fit for this position. Please review the details carefully and select your response below.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Action Buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _handleAction('Accepted'),
                    child: const Text(
                      'Accept Invitation',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _handleAction('Shortlisted'),
                    child: const Text(
                      'Shortlist',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _handleAction('Rejected'),
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      ),
    );
  }
}
