import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/theme_provider.dart';
import '../../candidate/controllers/candidate_controller.dart';
import 'about_us_screen.dart';

import '../../auth/repositories/auth_repository.dart';
import '../../auth/models/candidate_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final candidate = ref.watch(candidateControllerProvider).value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
              title: Text(
                'SETTINGS',
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
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Premium Section
                if (candidate != null && candidate.isPremium) ...[
                  _buildSectionCard(
                    context,
                    isDark,
                    title: 'Membership',
                    icon: Icons.star,
                    iconColor: Colors.amber,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: theme.scaffoldBackgroundColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'PREMIUM MEMBER',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (candidate.subscriptionExpiryDate != null)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDateInfo(
                                    context,
                                    'START DATE',
                                    // Using lastUpdated or createdAt as proxy for start if not explicitly stored,
                                    // but ideally we should have subscriptionStartDate.
                                    // For now using 30 days before expiry as an approximation if start date missing.
                                    candidate.subscriptionExpiryDate!.subtract(
                                      const Duration(days: 30),
                                    ),
                                  ),
                                  _buildDateInfo(
                                    context,
                                    candidate.subscriptionStatus == 'cancelled'
                                        ? 'EXPIRY DATE'
                                        : 'RENEWAL DATE',
                                    candidate.subscriptionExpiryDate!,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (candidate.subscriptionStatus != 'cancelled' &&
                          (candidate.subscriptionExpiryDate == null ||
                              DateTime.now().isBefore(
                                candidate.subscriptionExpiryDate!,
                              )))
                        _buildActionTile(
                          context,
                          isDark,
                          title: 'Cancel Subscription',
                          subtitle:
                              'Cancel your premium membership at any time',
                          icon: Icons.cancel_outlined,
                          iconColor: Colors.red,
                          onTap: () =>
                              _showCancelSubscriptionDialog(context, candidate),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Theme Section
                _buildSectionCard(
                  context,
                  isDark,
                  title: 'Appearance',
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  children: [
                    _buildThemeOption(
                      context,
                      isDark,
                      title: 'Light Mode',
                      icon: Icons.light_mode,
                      isSelected: themeMode == ThemeMode.light,
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).setLight(),
                    ),
                    const SizedBox(height: 8),
                    _buildThemeOption(
                      context,
                      isDark,
                      title: 'Dark Mode',
                      icon: Icons.dark_mode,
                      isSelected: themeMode == ThemeMode.dark,
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).setDark(),
                    ),
                    const SizedBox(height: 8),
                    _buildThemeOption(
                      context,
                      isDark,
                      title: 'System Default',
                      icon: Icons.brightness_auto,
                      isSelected: themeMode == ThemeMode.system,
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).setSystem(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Account Section
                _buildSectionCard(
                  context,
                  isDark,
                  title: 'Account',
                  icon: Icons.person_outline,
                  iconColor: const Color(0xFF3B82F6),
                  children: [
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      icon: Icons.logout,
                      iconColor: const Color(0xFFF59E0B),
                      onTap: () => _showLogoutDialog(context),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account',
                      icon: Icons.delete_forever,
                      iconColor: Colors.red,
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // About Section
                _buildSectionCard(
                  context,
                  isDark,
                  title: 'About',
                  icon: Icons.info_outline,
                  iconColor: const Color(0xFF10B981),
                  children: [
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'About Us',
                      subtitle: 'Our story and mission',
                      icon: Icons.info_outline,
                      iconColor: const Color(0xFF10B981),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutUsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoTile(
                      context,
                      isDark,
                      title: 'App Name',
                      value: _packageInfo?.appName ?? 'TalentBay Candidate',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoTile(
                      context,
                      isDark,
                      title: 'Version',
                      value: _packageInfo != null
                          ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                          : 'Loading...',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),

                const SizedBox(height: 16),

                // Support Section
                _buildSectionCard(
                  context,
                  isDark,
                  title: 'Support',
                  icon: Icons.support_agent_outlined,
                  iconColor: const Color(0xFFEC4899),
                  children: [
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'Call Support',
                      subtitle: '+91 99466 62410',
                      icon: Icons.phone_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      onTap: () => _launchPhone('+91 99466 62410'),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'Contact Support',
                      subtitle: 'info@waqtixllp.com',
                      icon: Icons.email_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      onTap: () => _launchEmail(),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'Visit Website',
                      subtitle: 'www.waqtixllp.com',
                      icon: Icons.language,
                      iconColor: const Color(0xFF10B981),
                      onTap: () => _launchWebsite(),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      context,
                      isDark,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      icon: Icons.privacy_tip_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      onTap: () => _launchPrivacyPolicy(),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
            ),
          ),
          child: Column(
            children: children
                .map(
                  (child) => Container(
                    decoration: BoxDecoration(
                      border: child == children.last
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                    ),
                    child: child,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    bool isDark, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.4),
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: theme.colorScheme.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    bool isDark, {
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog(
    BuildContext context,
    CandidateModel candidate,
  ) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'CANCEL SUBSCRIPTION',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel your premium subscription? You will still be able to access premium features until your current billing period ends.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.87),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.54),
            ),
            child: const Text('GO BACK'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final updatedCandidate = candidate.copyWith(
                subscriptionStatus: 'cancelled',
              );
              try {
                await ref
                    .read(candidateControllerProvider.notifier)
                    .updateProfile(updatedCandidate);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Subscription cancelled successfully',
                      ),
                      backgroundColor: theme.colorScheme.onSurface,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error cancelling subscription: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text(
              'CONFIRM',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'LOGOUT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authRepositoryProvider).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface,
              foregroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text(
              'LOGOUT',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE ACCOUNT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting your account will permanently remove:',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.87),
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Your profile information',
              'All job applications',
              'Chat history',
              'All saved preferences',
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.close, color: Colors.red, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.54),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.54),
            ),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authRepositoryProvider).deleteAccount();
                if (context.mounted) {
                  // Show success snackbar first
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Account deleted successfully'),
                      backgroundColor: theme.colorScheme.onSurface,
                    ),
                  );

                  // Navigate to login screen and remove all previous routes
                  // allowing the router to handle state changes if necessary,
                  // but explicitly going to login ensures the user sees the right screen
                  // even if the auth state stream has a delay.
                  // However, since we deleted the user, the auth state stream should trigger
                  // a redirect to login automatically in router.dart.
                  // But to be safe and responsive:
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting account: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'info@waqtixllp.com',
      query: 'subject=Support Request',
    );

    try {
      if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch email client')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    // Remove spaces for tel URI
    final cleanNumber = phoneNumber.replaceAll(' ', '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (!await launchUrl(phoneUri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch dialer')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _launchWebsite() async {
    final Uri websiteUri = Uri.parse('https://www.waqtixllp.com/');

    try {
      if (!await launchUrl(websiteUri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch website')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri privacyUri = Uri.parse(
      'https://www.waqtixllp.com/privacy-and-policy',
    );

    try {
      if (!await launchUrl(privacyUri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch privacy policy')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildDateInfo(BuildContext context, String label, DateTime date) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${date.day}/${date.month}/${date.year}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
