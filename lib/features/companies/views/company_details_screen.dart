import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_model.dart';
import '../../../../core/theme/app_colors.dart';

class CompanyDetailsScreen extends StatelessWidget {
  final CompanyModel company;

  const CompanyDetailsScreen({super.key, required this.company});

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(
      urlString.startsWith('http') ? urlString : 'https://$urlString',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = company.profile;
    final contact = company.contact;
    final business = company.business;
    final social = company.social;

    // H&M Aesthetic - Dynamic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark ? Colors.grey[900] : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark
        ? Colors.grey[400]
        : Colors.grey[600]; // Defined but check usage
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFEEEEEE);
    final dividerColor = isDark ? Colors.grey[800] : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            expandedHeight: 140,
            leading: BackButton(color: textColor),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
              title: Text(
                profile.companyName.toUpperCase(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'Futura',
                ),
              ),
              background: Container(color: backgroundColor),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Logo and Website
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                            image: profile.logoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(profile.logoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: profile.logoUrl.isEmpty
                              ? Center(
                                  child: Text(
                                    profile.companyName.isNotEmpty
                                        ? profile.companyName[0].toUpperCase()
                                        : 'C',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w300,
                                      color: textColor,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 24),
                        if (profile.tagline.isNotEmpty) ...[
                          Text(
                            profile.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: subTextColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (profile.website.isNotEmpty)
                          GestureDetector(
                            onTap: () => _launchUrl(profile.website),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primaryBrand,
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                'VISIT WEBSITE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryBrand,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  Divider(height: 1, color: dividerColor),
                  const SizedBox(height: 32),

                  // Info Grid (Industry, Size, Type, Found Year)
                  _buildInfoGrid(context, profile),

                  const SizedBox(height: 32),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 32),

                  // About Section
                  _buildSectionTitle(context, 'ABOUT'),
                  const SizedBox(height: 16),
                  Text(
                    profile.about.isNotEmpty
                        ? profile.about
                        : 'No description available.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 32),

                  // Location / Contact Section
                  if (company.settings.showContactInfo) ...[
                    _buildSectionTitle(context, 'LOCATION & CONTACT'),
                    const SizedBox(height: 16),
                    _buildContactRow(
                      context,
                      Icons.location_on_outlined,
                      '${contact.city}, ${contact.country}',
                    ),
                    if (contact.email.isNotEmpty)
                      _buildContactRow(
                        context,
                        Icons.email_outlined,
                        contact.email,
                      ),
                    if (company.settings.showContactInfo &&
                        contact.phone.isNotEmpty)
                      _buildContactRow(
                        context,
                        Icons.phone_outlined,
                        contact.phone,
                      ),

                    const SizedBox(height: 32),
                    Divider(height: 1, color: dividerColor),
                    const SizedBox(height: 32),
                  ],

                  // Social Media
                  _buildSectionTitle(context, 'CONNECT'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (social.linkedin.isNotEmpty)
                        _buildSocialIcon(
                          context,
                          social.linkedin,
                          'assets/icons/linkedin.png',
                          Icons.link,
                        ), // Fallback to icon
                      if (social.twitter.isNotEmpty)
                        _buildSocialIcon(
                          context,
                          social.twitter,
                          'assets/icons/twitter.png',
                          Icons.link,
                        ),
                      if (social.facebook.isNotEmpty)
                        _buildSocialIcon(
                          context,
                          social.facebook,
                          'assets/icons/facebook.png',
                          Icons.facebook,
                        ),

                      // Use generic icons if specific assets aren't available, or simple text links
                      if (social.linkedin.isEmpty &&
                          social.twitter.isEmpty &&
                          social.facebook.isEmpty)
                        const Text(
                          "No social media links provided.",
                          style: TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        color: isDark ? Colors.white : Colors.black,
        fontFamily: 'Futura',
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, CompanyProfile profile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildInfoItem(context, 'INDUSTRY', profile.industry),
        _buildInfoItem(context, 'SIZE', profile.companySize),
        _buildInfoItem(context, 'TYPE', profile.companyType),
        _buildInfoItem(
          context,
          'FOUNDED',
          profile.foundedYear?.toString() ?? 'N/A',
        ),
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildContactRow(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(
    BuildContext context,
    String url,
    String assetPath,
    IconData fallbackIcon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            fallbackIcon,
            size: 20,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
