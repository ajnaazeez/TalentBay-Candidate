import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:talentbay_candidate/core/constants/payment_constants.dart';
import 'package:talentbay_candidate/core/utils/platform_utils.dart';
import 'package:talentbay_candidate/features/candidate/controllers/candidate_controller.dart';
import 'package:talentbay_candidate/features/payment/controllers/subscription_controller.dart';
import 'subscription_prompt_dialog.dart';
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

    final isTrialActive = user?.isTrialActive ?? false;
    final isPremium = user?.isPremium ?? false;
    final hasUsedTrial = user?.hasUsedTrial ?? false;
    final plan = PaymentConstants.subscriptionPlans.first;

    // Watch Apple product details on iOS
    final appleProductsAsync = ref.watch(appleProductsProvider);

    final titleText = isTrialActive
        ? '7-DAY FREE TRIAL ACTIVE'
        : (hasUsedTrial
            ? 'RENEW SUBSCRIPTION'
            : 'START 7-DAY FREE TRIAL');
    final subtitleText = isTrialActive
        ? 'You have full access to skill assessments, career guidance, and direct recruiter chat.'
        : (hasUsedTrial
            ? 'Renew your subscription to keep your Premium access.'
            : 'Get 7 days of completely free Premium access. No payment details required.');

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

                  if (isTrialActive) ...[
                    // Active Free Trial Card
                    _buildPlanCard(
                      context,
                      {
                        'id': 'free_trial_7d',
                        'title': '7-Day Free Premium',
                        'displayAmount': '0',
                      },
                      isLoading,
                      '7-Day Free Trial',
                      'FREE',
                      () => Navigator.pop(context),
                      subtitleText: user?.trialExpiryDate != null
                          ? 'Active until ${user!.trialExpiryDate!.day}/${user.trialExpiryDate!.month}/${user.trialExpiryDate!.year}'
                          : 'Full access to all features enabled',
                      customOfferTag: 'ACTIVE',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        SubscriptionPromptDialog.show(context);
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text(
                        'VIEW ALL SUBSCRIPTION PLANS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBrand,
                        side: const BorderSide(color: AppColors.primaryBrand),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(),
                      ),
                    ),
                  ] else if (hasUsedTrial && !isPremium) ...[
                    // Renew Plan Card (1 Month ₹399)
                    _buildPlanCard(
                      context,
                      plan,
                      isLoading,
                      plan['title'],
                      Platform.isAndroid
                          ? '₹${plan['displayAmount']}'
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
                            ),
                      () {
                        Navigator.pop(context);
                        controller.startSubscription(context, plan);
                      },
                    ),
                  ] else ...[
                    // First-Time Free Trial Activation Card
                    _buildPlanCard(
                      context,
                      {
                        'id': 'free_trial_7d',
                        'title': '7-Day Free Premium',
                        'displayAmount': '0',
                      },
                      isLoading,
                      'Start 7-Day Free Trial',
                      '₹0',
                      () async {
                        Navigator.pop(context);
                        // Trigger immediate idempotent trial initialization
                        try {
                          await FirebaseFunctions.instanceFor(region: 'us-central1')
                              .httpsCallable('startCandidateFreeTrial')
                              .call();
                        } catch (e) {
                          debugPrint('[SubscriptionTrialBottomSheet] startCandidateFreeTrial error: $e');
                        }
                      },
                      subtitleText: 'No credit card or payment details required',
                      customOfferTag: 'FREE',
                    ),
                  ],

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
                    PlatformUtils.getPaymentFooterText(),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. Manage your subscription in your iTunes Account settings.',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => PlatformUtils.launchURL(
                            context,
                            'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                          ),
                          child: const Text(
                            'Terms of Use (EULA)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryBrand,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => PlatformUtils.launchURL(
                            context,
                            'https://www.waqtixllp.com/privacy-and-policy',
                          ),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryBrand,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
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
    VoidCallback onTap, {
    String? subtitleText,
    String? customOfferTag,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final offer = customOfferTag ?? (plan['offer'] as String?);

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
                        Flexible(
                          child: Text(
                            titleText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (offer != null) ...[
                          const SizedBox(width: 8),
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
                    if (subtitleText != null && subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
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
