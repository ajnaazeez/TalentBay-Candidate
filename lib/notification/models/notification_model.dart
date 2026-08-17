import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String jobId;
  final String status;
  final String actionStatus;
  final String type;
  final String chatId;
  final String companyLogoUrl;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.jobId,
    required this.status,
    required this.actionStatus,
    this.type = 'general',
    this.chatId = '',
    this.companyLogoUrl = '',
    required this.createdAt,
  });

  factory NotificationModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return NotificationModel(
      id: documentId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      jobId: map['jobId'] ?? '',
      status: map['status'] ?? 'Unread',
      actionStatus: map['action_status'] ?? 'Pending',
      type: map['type'] ?? 'general',
      chatId: map['chatId'] ?? '',
      companyLogoUrl: map['companyLogoUrl'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'jobId': jobId,
      'status': status,
      'action_status': actionStatus,
      'type': type,
      'chatId': chatId,
      'companyLogoUrl': companyLogoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? jobId,
    String? status,
    String? actionStatus,
    String? type,
    String? chatId,
    String? companyLogoUrl,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      type: type ?? this.type,
      chatId: chatId ?? this.chatId,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
