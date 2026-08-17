import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;

// Top level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

@pragma('vm:entry-point')
void _localNotificationBackgroundHandler(NotificationResponse response) {
  print('Local notification clicked in background');
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final GoRouter _router;

  NotificationService(this._router);

  Future<void> init() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permissions');
    }

    // Register Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialise local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          _localNotificationBackgroundHandler,
    );

    // Handle messages while in Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title ?? '',
          body: notification.body ?? '',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'talentbay_candidate_channel',
              'TalentBay Candidate Notifications',
              channelDescription: 'Notifications for jobs and updates',
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
        );
      }
    });

    // Handle background notification clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageOpen(message);
    });

    // Handle notification click from terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpen(initialMessage);
    }

    // Save Token
    await saveUserToken();

    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen((String token) {
      _updateUserTokenInFirestore(token);
    });
  }

  void _handleMessageOpen(RemoteMessage message) {
    print('Message clicked!');
    if (message.data.isNotEmpty) {
      String? type = message.data['type'];
      String? jobId = message.data['jobId'];

      if (type == 'job_invitation') {
        _router.push('/invitations');
      } else if (type == 'job_match' && jobId != null) {
        _router.push('/job/$jobId');
      }
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload != null) {
      Map<String, dynamic> data = jsonDecode(payload);
      String? type = data['type'];
      String? jobId = data['jobId'];

      if (type == 'job_invitation') {
        _router.push('/invitations');
      } else if (type == 'job_match' && jobId != null) {
        _router.push('/job/$jobId');
      }
    }
  }

  Future<void> saveUserToken() async {
    try {
      String? token;

      if (Platform.isIOS) {
        // Required for iOS
        token = await _firebaseMessaging.getAPNSToken();
        if (token != null) {
          token = await _firebaseMessaging.getToken();
        }
      } else {
        token = await _firebaseMessaging.getToken();
      }

      print('FCM Token: $token');
      if (token != null) {
        await _updateUserTokenInFirestore(token);
      }
    } catch (e) {
      print('Failed to get FCM token: $e');
    }
  }

  Future<void> _updateUserTokenInFirestore(String token) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('candidates')
            .doc(currentUser.uid)
            .update({
              'fcmTokens': FieldValue.arrayUnion([token]),
            });
      } catch (e) {
        // Collection might not be created or user doc doesn't exist
        print('Error saving token: $e');
      }
    }
  }
}
