import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

/// Service for creating notifications in the app
class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a notification for a user
  /// 
  /// [toUserId] - The ID of the user who will receive the notification
  /// [title] - The title of the notification
  /// [body] - The body/message of the notification
  /// [type] - Optional type of notification (e.g., 'item_found', 'item_claimed', 'message', 'match')
  /// [data] - Optional additional data (e.g., itemId, chatId, etc.)
  static Future<void> createNotification({
    required String toUserId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('[NotificationService] Creating notification for user: $toUserId, title: $title');
      final docRef = await _firestore.collection('notifications').add({
        'toUserId': toUserId,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        if (data != null) ...data,
      });
      print('[NotificationService] Notification created successfully with ID: ${docRef.id}');
      
      // Also send push notification via FCM
      try {
        await FCMService.sendNotificationToUser(
          userId: toUserId,
          title: title,
          body: body,
          data: data,
        );
        print('[NotificationService] Push notification sent via FCM');
      } catch (e) {
        print('[NotificationService] Error sending push notification: $e');
        // Don't fail if push notification fails
      }
    } catch (e) {
      print('[NotificationService] Error creating notification: $e');
      // Don't throw - notifications shouldn't break the app flow
    }
  }

  /// Notify user when their lost item is found
  static Future<void> notifyItemFound({
    required String toUserId,
    required String itemTitle,
    required String finderName,
    String? itemId,
  }) async {
    await createNotification(
      toUserId: toUserId,
      title: 'Item Found!',
      body: '$finderName found your lost item: $itemTitle',
      type: 'item_found',
      data: itemId != null ? {'itemId': itemId} : null,
    );
  }

  /// Notify user when their found item is claimed
  static Future<void> notifyItemClaimed({
    required String toUserId,
    required String itemTitle,
    required String claimantName,
    String? itemId,
  }) async {
    await createNotification(
      toUserId: toUserId,
      title: 'Item Claimed',
      body: '$claimantName claimed your found item: $itemTitle',
      type: 'item_claimed',
      data: itemId != null ? {'itemId': itemId} : null,
    );
  }

  /// Notify user when they receive a new message
  static Future<void> notifyNewMessage({
    required String toUserId,
    required String senderName,
    required String messagePreview,
    String? chatId,
  }) async {
    await createNotification(
      toUserId: toUserId,
      title: 'New Message from $senderName',
      body: messagePreview,
      type: 'message',
      data: chatId != null ? {'chatId': chatId} : null,
    );
  }

  /// Notify user when a new item matches their search criteria
  static Future<void> notifyItemMatch({
    required String toUserId,
    required String itemTitle,
    required String itemType, // 'lost' or 'found'
    String? itemId,
  }) async {
    await createNotification(
      toUserId: toUserId,
      title: 'New Match Found',
      body: 'A new $itemType item might match your search: $itemTitle',
      type: 'match',
      data: itemId != null ? {'itemId': itemId} : null,
    );
  }

  /// Notify user when their post is approved/rejected (for admin approval workflows)
  static Future<void> notifyPostStatus({
    required String toUserId,
    required String itemTitle,
    required bool approved,
    String? itemId,
  }) async {
    await createNotification(
      toUserId: toUserId,
      title: approved ? 'Post Approved' : 'Post Rejected',
      body: approved
          ? 'Your post "$itemTitle" has been approved and is now visible to others.'
          : 'Your post "$itemTitle" has been rejected. Please check the details.',
      type: 'post_status',
      data: itemId != null ? {'itemId': itemId, 'approved': approved} : null,
    );
  }
}

