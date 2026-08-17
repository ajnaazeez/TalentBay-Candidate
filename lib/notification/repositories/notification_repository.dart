import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notification/models/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(),
);

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'notifications';

  Future<void> saveNotification(NotificationModel notification) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(notification.id)
          .set(notification.toMap());
    } catch (e) {
      throw Exception('Failed to save notification: $e');
    }
  }

  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return NotificationModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> updateNotificationStatus(
    String notificationId,
    String status,
  ) async {
    try {
      await _firestore.collection(_collectionName).doc(notificationId).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update notification status: $e');
    }
  }

  Future<void> updateNotificationActionStatus(
    String notificationId,
    String actionStatus,
  ) async {
    try {
      await _firestore.collection(_collectionName).doc(notificationId).update({
        'action_status': actionStatus,
      });
    } catch (e) {
      throw Exception('Failed to update notification action status: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collectionName).doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }
}
