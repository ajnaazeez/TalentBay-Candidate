import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/company_repository.dart';
import '../models/company_model.dart';
import 'company_details_screen.dart';

class AllCompaniesScreen extends ConsumerStatefulWidget {
  const AllCompaniesScreen({super.key});

  @override
  ConsumerState<AllCompaniesScreen> createState() => _AllCompaniesScreenState();
}

class _AllCompaniesScreenState extends ConsumerState<AllCompaniesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyRepo = ref.watch(companyRepositoryProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Search companies...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: StreamBuilder<List<CompanyModel>>(
        stream: companyRepo.getCompanies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading companies'));
          }

          final companies = snapshot.data ?? [];

          // 1. Filter
          final filteredCompanies = companies.where((c) {
            if (_searchQuery.isEmpty) return true;
            return c.profile.companyName.toLowerCase().contains(_searchQuery) ||
                c.profile.industry.toLowerCase().contains(_searchQuery);
          }).toList();

          // 2. Sort by totalApplicants descending
          filteredCompanies.sort(
            (a, b) =>
                b.stats.totalApplicants.compareTo(a.stats.totalApplicants),
          );

          if (filteredCompanies.isEmpty) {
            return Center(
              child: Text(
                'No companies found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: filteredCompanies.length,
            itemBuilder: (context, index) {
              final company = filteredCompanies[index];
              return _buildCompanyCard(
                context,
                company,
                cardColor,
                borderColor,
                textColor,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    CompanyModel company,
    Color? cardColor,
    Color borderColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompanyDetailsScreen(company: company),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: borderColor),
                shape: BoxShape.circle,
                image: company.profile.logoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(company.profile.logoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: company.profile.logoUrl.isEmpty
                  ? const Icon(Icons.business, color: Colors.black, size: 24)
                  : null,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                company.profile.companyName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${company.stats.totalApplicants} Applicants',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
