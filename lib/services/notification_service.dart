import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(initializationSettings);

    // 3. Setup Foreground Notification Channel (High Importance for Pop-up)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sahyog_notifications',
      'Sahyog Platform Alerts',
      description: 'Main notification channel for Sahyog updates',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificPlugin<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 5. Setup Firestore Real-time Listener (Fallback for real-time in-app alerts)
    _setupFirestoreListener();
  }

  void _setupFirestoreListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen for new notifications for THIS user added in the last 10 seconds
    FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: user.uid)
        .where('createdAt', isGreaterThan: Timestamp.now()) // Only new ones
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _showCustomNotification(
            data['title'] ?? 'Sahyog Update',
            data['body'] ?? '',
          );
        }
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _showCustomNotification(notification.title ?? '', notification.body ?? '');
    }
  }

  Future<void> _showCustomNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sahyog_notifications',
      'Sahyog Platform Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
