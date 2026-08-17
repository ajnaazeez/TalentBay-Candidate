import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../notification/providers/notification_provider.dart';
import '../../../notification/models/notification_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import '../../chat/views/chat_screen.dart';
import '../../jobs/repositories/job_repository.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread', 'Read'];

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 0.5,
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
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;
                  return _buildMinimalFilterChip(filter, isSelected);
                },
              ),
            ),
          ),
          
          // Notifications List
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                // Filter notifications based on tab selection
                List<NotificationModel> filteredList = notifications;
                if (_selectedFilter == 'Unread') {
                  filteredList = notifications.where((n) => n.status == 'Unread').toList();
                } else if (_selectedFilter == 'Read') {
                  filteredList = notifications.where((n) => n.status == 'Read').toList();
                }

                // Sort newest first
                filteredList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (filteredList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(
                      height: 1, 
                      color: isDark ? Colors.grey[800] : Colors.grey[200]
                    ),
                  ),
                  itemBuilder: (context, index) {
                    return _buildNotificationTile(filteredList[index], isDark);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBrand),
              ),
              error: (err, stack) => Center(
                child: Text('Failed to load notifications: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalFilterChip(String filter, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBrand : Colors.transparent,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBrand
                : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
            width: 1,
          ),
        ),
        child: Text(
          filter.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : Colors.black),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification, bool isDark) {
    final bool isUnread = notification.status == 'Unread';
    
    return InkWell(
      onTap: () async {
        // Mark as read in Firestore
        if (isUnread) {
          ref.read(notificationNotifierProvider.notifier).markAsRead(notification.id);
        }
        
        if (notification.type == 'chat_message' && notification.chatId.isNotEmpty) {
           final jobRepo = ref.read(jobRepositoryProvider);
           final job = await jobRepo.getJob(notification.jobId);
           
           if (job != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: notification.chatId,
                    jobTitle: job.title,
                    companyName: job.companyName ?? 'Company',
                    companyLogoUrl: job.companyLogoUrl,
                    recipientName: job.companyName ?? 'Recruiter',
                  ),
                ),
              );
           }
           return;
        }

        if (notification.type == 'job_invitation') {
          context.push('/invitations');
          return;
        }

        if (notification.type == 'job_match' && notification.jobId.isNotEmpty) {
          context.push('/job/${notification.jobId}');
          return;
        }

        // Default actionable navigation if jobId is present
        if (notification.jobId.isNotEmpty) {
          context.push('/job/${notification.jobId}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / Avatar indicating type
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnread 
                      ? AppColors.primaryBrand
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!), 
                  width: isUnread ? 2 : 1
                ),
              ),
              child: ClipOval(
                child: notification.companyLogoUrl.isNotEmpty
                    ? Image.network(
                        notification.companyLogoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business,
                          color: isDark ? Colors.white : Colors.black,
                          size: 20,
                        ),
                      )
                    : Icon(
                        notification.type == 'chat_message' 
                            ? Icons.chat_bubble_outline
                            : notification.title.contains('Invitation') 
                                ? Icons.mail_outline 
                                : Icons.work_outline,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeago.format(notification.createdAt, locale: 'en_short'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.4,
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined, 
            size: 64, 
            color: isDark ? Colors.grey[800] : Colors.grey[300]
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get matched or invited, they will show up here.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
