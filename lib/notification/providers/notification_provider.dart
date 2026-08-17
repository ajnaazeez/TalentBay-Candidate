import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notification/models/notification_model.dart';
import '../../notification/repositories/notification_repository.dart';
import '../../features/auth/controllers/auth_controller.dart';

final userNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
      final user = ref.watch(authStateChangesProvider).value;
      if (user == null) {
        return Stream.value([]);
      }

      final repository = ref.watch(notificationRepositoryProvider);
      return repository.getUserNotifications(user.uid);
    });

class NotificationNotifier extends AsyncNotifier<void> {
  late NotificationRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.watch(notificationRepositoryProvider);
    return null;
  }

  Future<void> markAsRead(String notificationId) async {
    state = const AsyncLoading();
    try {
      await _repository.updateNotificationStatus(notificationId, 'Read');
      state = const AsyncData(null);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }

  Future<void> performAction(String notificationId, String action) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateNotificationActionStatus(notificationId, action);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteNotification(notificationId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

final notificationNotifierProvider =
    AsyncNotifierProvider<NotificationNotifier, void>(() {
      return NotificationNotifier();
    });
