import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../jobs/repositories/job_repository.dart';
import '../../jobs/models/job_model.dart';
import 'widgets/job_card.dart';
import '../../../features/jobs/views/job_details_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Remote',
    'Full-time',
    'Part-time',
    'Contract',
  ];

  List<SearchHistoryItem> _searchHistory = [];
  List<JobModel> _allJobs = [];
  List<JobModel> _filteredJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // Fetch jobs initially so we can search locally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchJobs();
      _searchFocus.requestFocus();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    final jobsStream = ref.read(jobRepositoryProvider).getJobsStream();
    final jobs = await jobsStream.first; // Fetch once for client-side filtering
    if (mounted) {
      setState(() {
        _allJobs = jobs;
        _isLoading = false;
      });
    }
  }

  // --- Search History Logic ---

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('search_history');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final now = DateTime.now();

      final validItems = decoded
          .map((item) => SearchHistoryItem.fromMap(item))
          .where(
            (item) => now.difference(item.timestamp).inDays <= 30,
          ) // Remove > 30 days
          .toList();

      if (mounted) {
        setState(() {
          _searchHistory = validItems;
        });
      }

      // If we filtered out items, save the clean list back
      if (validItems.length != decoded.length) {
        _saveSearchHistory(validItems);
      }
    }
  }

  Future<void> _saveSearchHistory(List<SearchHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(items.map((e) => e.toMap()).toList());
    await prefs.setString('search_history', jsonString);
  }

  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;

    // Remove if exists to bubble to top
    final existingIndex = _searchHistory.indexWhere(
      (item) => item.query.toLowerCase() == query.toLowerCase(),
    );
    if (existingIndex != -1) {
      _searchHistory.removeAt(existingIndex);
    }

    final newItem = SearchHistoryItem(
      query: query.trim(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _searchHistory.insert(0, newItem);
      // Keep only recent 20 for example
      if (_searchHistory.length > 20) {
        _searchHistory = _searchHistory.sublist(0, 20);
      }
    });

    _saveSearchHistory(_searchHistory);
  }

  void _removeFromHistory(SearchHistoryItem item) {
    setState(() {
      _searchHistory.remove(item);
    });
    _saveSearchHistory(_searchHistory);
  }

  void _onSearchChanged() {
    _filterJobs();
  }

  void _filterJobs() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty && _selectedCategory == 'All') {
      setState(() {
        _filteredJobs = [];
      });
      return;
    }

    setState(() {
      _filteredJobs = _allJobs.where((job) {
        // Text Match
        final roleMatch = job.roleName.toLowerCase().contains(query);
        final designationMatch = job.designationName.toLowerCase().contains(
          query,
        );
        final companyMatch = (job.companyName ?? '').toLowerCase().contains(
          query,
        );
        final expMatch = job.experienceLevel.toLowerCase().contains(query);

        final matchesText =
            query.isEmpty ||
            roleMatch ||
            designationMatch ||
            companyMatch ||
            expMatch;

        // Category Match
        bool matchesCategory = true;
        if (_selectedCategory == 'Remote') {
          matchesCategory = job.workMode.toLowerCase().contains('remote');
        } else if (_selectedCategory != 'All') {
          // 'Full-time', 'Part-time', 'Contract' usually map to employmentType
          matchesCategory =
              job.employmentType.toLowerCase() ==
              _selectedCategory.toLowerCase();
        }

        return matchesText && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onSubmitted: (value) {
            _addToHistory(value);
          },
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Search title, skill, or company...',
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
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return _buildMinimalCategoryChip(category, isSelected);
                },
              ),
            ),
          ),

          // Content
          Expanded(
            child: hasQuery || _selectedCategory != 'All'
                ? _buildSearchResults()
                : _buildRecentSearches(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBrand),
      );
    }

    if (_filteredJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No jobs found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredJobs.length,
      itemBuilder: (context, index) {
        final job = _filteredJobs[index];
        return JobCard(
          job: job,
          onTap: () {
            // Add to history if tapped? OPTIONAL.
            // Usually we add when typed & submitted.
            // Let's assume on tap details page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    JobDetailsScreen(job: job, jobId: job.jobId),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_searchHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'RECENT SEARCHES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchHistory.length,
          itemBuilder: (context, index) {
            final item = _searchHistory[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.history, color: Colors.grey, size: 20),
              title: Text(
                item.query,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => _removeFromHistory(item),
              ),
              onTap: () {
                _searchController.text = item.query;
                _filterJobs();
                // Optionally move cursor to end
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: item.query.length),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMinimalCategoryChip(String category, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _filterJobs(); // Re-filter when category changes
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBrand : Colors.transparent,
          borderRadius: BorderRadius.zero, // Sharp
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBrand
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[400]!),
            width: 1,
          ),
        ),
        child: Text(
          category.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class SearchHistoryItem {
  final String query;
  final DateTime timestamp;

  SearchHistoryItem({required this.query, required this.timestamp});

  Map<String, dynamic> toMap() {
    return {'query': query, 'timestamp': timestamp.toIso8601String()};
  }

  factory SearchHistoryItem.fromMap(Map<String, dynamic> map) {
    return SearchHistoryItem(
      query: map['query'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
