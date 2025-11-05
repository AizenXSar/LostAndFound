import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_logger.dart';

/// Service for handling Firebase Cloud Messaging (FCM) push notifications
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local notifications plugin for foreground notifications
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  /// Initialize FCM service
  static Future<void> initialize() async {
    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.debug('Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.info('User granted provisional permission');
      } else {
        AppLogger.warning('User declined or has not accepted permission');
        return;
      }

      // Initialize local notifications for foreground
      await _initializeLocalNotifications();

      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        AppLogger.debug('FCM Token obtained');
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        AppLogger.debug('FCM Token refreshed');
        _saveTokenToFirestore(newToken);
      });

      // Set up message handlers
      _setupMessageHandlers();

      AppLogger.info('FCM initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing FCM', e);
    }
  }

  /// Initialize local notifications for foreground notifications
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        AppLogger.debug('Notification tapped');
        // Handle notification tap
      },
    );
  }

  /// Save FCM token to Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Save token to user document
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Also save to fcmTokens collection for easy lookup
      await _firestore.collection('fcmTokens').doc(user.uid).set({
        'userId': user.uid,
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.debug('FCM token saved to Firestore');
    } catch (e) {
      AppLogger.error('Error saving FCM token', e);
    }
  }

  /// Set up message handlers for different app states
  static void _setupMessageHandlers() {
    // Foreground messages (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.debug('Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Background messages (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.debug('Notification opened app: ${message.notification?.title}');
      // Handle navigation based on notification data
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        AppLogger.debug('App opened from terminated state: ${message.notification?.title}');
        _handleNotificationTap(message);
      }
    });
  }

  /// Show local notification for foreground messages
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Notifications',
      channelDescription: 'Notifications for Lost and Found app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    
    // Handle different notification types
    if (data.containsKey('chatId')) {
      // Navigate to chat
      AppLogger.debug('Navigate to chat: ${data['chatId']}');
    } else if (data.containsKey('itemId')) {
      // Navigate to item
      AppLogger.debug('Navigate to item: ${data['itemId']}');
    }
  }

  /// Send push notification to a user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final tokenDoc = await _firestore.collection('fcmTokens').doc(userId).get();
      if (!tokenDoc.exists) {
        AppLogger.warning('No FCM token found for user: $userId');
        return;
      }

      final token = tokenDoc.data()?['token'] as String?;
      if (token == null || token.isEmpty) {
        AppLogger.warning('Invalid FCM token for user: $userId');
        return;
      }

      // Note: In a production app, you would send this via a backend server
      // For now, we'll use Firestore Cloud Functions or a backend service
      // This is a placeholder - actual implementation requires backend
      AppLogger.debug('Sending notification - Title: $title');
      
      // Store notification request in Firestore for Cloud Functions to process
      await _firestore.collection('notificationRequests').add({
        'userId': userId,
        'fcmToken': token,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      AppLogger.error('Error sending notification', e);
    }
  }
}

/// Background message handler (must be top-level function)
/// This must be a top-level or static function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.debug('Background message received: ${message.notification?.title}');
  // Handle background message
}

