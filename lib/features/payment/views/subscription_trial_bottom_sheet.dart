import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbay_candidate/core/constants/payment_constants.dart';
import 'package:talentbay_candidate/features/candidate/controllers/candidate_controller.dart';
import 'package:talentbay_candidate/features/payment/controllers/subscription_controller.dart';
import '../../../core/theme/app_colors.dart';

class SubscriptionTrialBottomSheet extends ConsumerWidget {
  const SubscriptionTrialBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final user = ref.watch(candidateControllerProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasUsedTrial = user?.hasUsedTrial ?? false;
    final plan = hasUsedTrial 
        ? PaymentConstants.subscriptionPlans.first
        : PaymentConstants.trialPlan;

    // Watch Apple product details on iOS
    final appleProductsAsync = ref.watch(appleProductsProvider);

    final titleText = hasUsedTrial ? 'RENEW SUBSCRIPTION' : 'START 7-DAY TRIAL';
    final subtitleText = hasUsedTrial
        ? 'Renew your subscription to keep your Premium access.'
        : 'Unlock full access to Premium features today.';

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle for drag
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header Image
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Image.asset(
                'assets/images/splash.png',
                fit: BoxFit.cover,
                color: isDark ? Colors.white : Colors.black,
                colorBlendMode: isDark ? BlendMode.modulate : null,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontFamily: 'Futura',
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildBenefitRow(context, 'Apply directly for the job'),
                  _buildBenefitRow(context, 'Chat securely with recruiters'),
                  _buildBenefitRow(context, 'Take skill assessments'),
                  const SizedBox(height: 32),

                  // Show ONLY trial plan (or 1 month plan if trial used)
                  _buildPlanCard(
                    context,
                    plan,
                    isLoading,
                    Platform.isIOS && plan['id'] == '7_days_trial'
                        ? '7 Days Free Trial'
                        : plan['title'],
                    Platform.isAndroid
                        ? '₹${plan['displayAmount']}'
                        : (plan['id'] == '7_days_trial'
                            ? 'Free'
                            : appleProductsAsync.when(
                                data: (products) {
                                  final match = products.where(
                                    (p) => p.id == plan['appleProductId'],
                                  );
                                  return match.isNotEmpty
                                      ? match.first.price
                                      : '₹${plan['displayAmount']}';
                                },
                                loading: () => '...',
                                error: (err, stack) => '₹${plan['displayAmount']}',
                              )),
                    () {
                      controller.startSubscription(context, plan);
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 16),
                  
                  // "Maybe Later" Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'MAYBE LATER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Footer
                  Text(
                    Platform.isAndroid
                        ? 'Secure payment securely processed by Razorpay.'
                        : 'Secured with App Store In-App Purchase.',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.primaryBrand,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    Map<String, dynamic> plan,
    bool isLoading,
    String titleText,
    String priceText,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final offer = plan['offer'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primaryBrand, // Highlighted border for trial
              width: 2,
            ),
            color: isDark ? Colors.grey[900] : Colors.white,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (offer != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            color: AppColors.primaryBrand,
                            child: Text(
                              offer,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
