import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../candidate/controllers/candidate_controller.dart';
import '../../jobs/repositories/job_repository.dart';
import '../../jobs/models/job_model.dart';
import '../models/chat_model.dart';
import '../repositories/chat_repository.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidateState = ref.watch(candidateControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    if (candidateState.value == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
      );
    }

    final userId = candidateState.value!.uid;
    final chatRepo = ref.watch(chatRepositoryProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MESSAGES',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: 'Futura',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: chatRepo.getChats(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: textColor));
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return ListView.separated(
            itemCount: chats.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? Colors.grey[900] : Colors.grey[100],
            ),
            itemBuilder: (context, index) {
              return _ChatListTile(chat: chats[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'NO MESSAGES YET',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your conversations with recruiters will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  final ChatModel chat;

  const _ChatListTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final jobRepo = ref.watch(jobRepositoryProvider);

    return FutureBuilder<JobModel?>(
      future: jobRepo.getJob(chat.jobId),
      builder: (context, snapshot) {
        final job = snapshot.data;
        final jobTitle = job?.title ?? 'Job Discussion';
        final companyName = job?.companyName ?? 'Company';
        final companyLogoUrl = job?.companyLogoUrl;

        return InkWell(
          onTap: () async {
            // Mark as read when opening
            final userId = ref.read(candidateControllerProvider).value?.uid;
            if (userId != null) {
              await ref
                  .read(chatRepositoryProvider)
                  .markAsRead(chat.id, userId);
            }

            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chat.id,
                    jobTitle: jobTitle,
                    companyName: companyName,
                    companyLogoUrl: companyLogoUrl,
                    recipientName:
                        'Recruiter', // Could be enhanced to show actual name
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Company Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                  child: companyLogoUrl != null && companyLogoUrl.isNotEmpty
                      ? Image.network(companyLogoUrl, fit: BoxFit.cover)
                      : Icon(Icons.business, color: textColor, size: 28),
                ),
                const SizedBox(width: 16),
                // Chat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              jobTitle.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(chat.lastMessageTime),
                            style: TextStyle(color: subTextColor, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyName.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primaryBrand,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.decryptedLastMessage,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                                fontWeight: chat.decryptedLastMessage.isEmpty
                                    ? FontWeight.w300
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Unread Badge
                          StreamBuilder<int>(
                            stream: ref
                                .watch(chatRepositoryProvider)
                                .getChatUnreadCount(
                                  chat.id,
                                  ref
                                          .read(candidateControllerProvider)
                                          .value
                                          ?.uid ??
                                      '',
                                ),
                            builder: (context, unreadSnapshot) {
                              final unreadCount = unreadSnapshot.data ?? 0;
                              if (unreadCount == 0)
                                return const SizedBox.shrink();

                              return Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBrand,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final chatDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (chatDate == today) {
      return DateFormat.jm().format(dateTime);
    } else if (chatDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat.E().format(dateTime);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }
}
