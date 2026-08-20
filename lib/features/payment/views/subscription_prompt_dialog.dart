import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbay_candidate/core/constants/payment_constants.dart';
import 'package:talentbay_candidate/core/utils/platform_utils.dart';
import 'package:talentbay_candidate/features/candidate/controllers/candidate_controller.dart';
import 'package:talentbay_candidate/features/payment/controllers/subscription_controller.dart';
import '../../../core/theme/app_colors.dart';

class SubscriptionPromptDialog extends ConsumerWidget {
  const SubscriptionPromptDialog({super.key});

  static Future<T?> show<T>(BuildContext context, {bool barrierDismissible = true}) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95), // Highly opaque to prevent background text visibility
      barrierDismissible: barrierDismissible,
      builder: (context) => const SubscriptionPromptDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final user = ref.watch(candidateControllerProvider).value;
    final hasUsedTrial = user?.hasUsedTrial ?? false;

    // Show all plans together
    final plansToShow = [
      PaymentConstants.trialPlan,
      ...PaymentConstants.subscriptionPlans,
    ];

    // Watch Apple product details on iOS
    final appleProductsAsync = ref.watch(appleProductsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const titleText = 'PREMIUM MEMBER';
    const subtitleText = 'Full access to all features. Cancel anytime.';

    String getDisplayPrice(Map<String, dynamic> plan) {
      if (Platform.isAndroid) {
        return '₹${plan['displayAmount']}';
      }
      
      // On iOS
      if (plan['id'] == '7_days_trial') {
        return 'Free';
      }
      
      final appleProductId = plan['appleProductId'];
      return appleProductsAsync.when(
        data: (products) {
          final match = products.where(
            (p) => p.id == appleProductId,
          );
          return match.isNotEmpty ? match.first.price : '₹${plan['displayAmount']}';
        },
        loading: () => '...',
        error: (err, stack) => '₹${plan['displayAmount']}',
      );
    }

    String getPlanTitle(Map<String, dynamic> plan) {
      if (Platform.isIOS && plan['id'] == '7_days_trial') {
        return '7 Days Free Trial';
      }
      return plan['title'];
    }

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.shortestSide >= 600
            ? (MediaQuery.of(context).size.width - 480) / 2
            : 16,
        vertical: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Image
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/splash.png',
                    fit: BoxFit.cover,
                    color: isDark ? Colors.white : Colors.black,
                    colorBlendMode: isDark ? BlendMode.modulate : null,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    color: isDark ? Colors.white : Colors.black,
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.scaffoldBackgroundColor
                          .withOpacity(0.7),
                      shape: const RoundedRectangleBorder(),
                    ),
                  ),
                ),
              ],
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
                      fontFamily:
                          'Futura', // Fallback will handle if not present
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
                  _buildBenefitRow(context, 'Applying for the job'),
                  _buildBenefitRow(context, 'Chat with this recruiter'),
                  _buildBenefitRow(context, 'Score this assessment'),
                  const SizedBox(height: 32),

                  // Plans
                  ...plansToShow.map((plan) {
                    final isTrialUsed = plan['id'] == '7_days_trial' && hasUsedTrial;
                    return _buildPlanCard(
                      context,
                      plan,
                      isLoading,
                      isTrialUsed,
                      getDisplayPrice(plan),
                      getPlanTitle(plan),
                      () {
                        controller.startSubscription(context, plan);
                        Navigator.pop(context);
                      },
                    );
                  }),

                  const SizedBox(height: 24),

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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
    bool isUsed,
    String priceText,
    String titleText,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final offer = plan['offer'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: (isLoading || isUsed) ? null : onTap,
        child: Opacity(
          opacity: isUsed ? 0.5 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: plan['id'] == '7_days_trial' && !isUsed
                    ? AppColors.primaryBrand
                    : theme.colorScheme.onSurface.withOpacity(0.1),
                width: plan['id'] == '7_days_trial' && !isUsed ? 2 : 1,
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
                          if (offer != null && !isUsed) ...[
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
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUsed)
                  Text(
                    'USED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  )
                else if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
