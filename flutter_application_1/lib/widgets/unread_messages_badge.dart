import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UnreadMessagesBadge extends StatelessWidget {
  const UnreadMessagesBadge({
    super.key,
    required this.iconPath,
    required this.onPressed,
    this.iconSize = 24,
  });

  final String iconPath;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      return IconButton(
        tooltip: 'Messages',
        onPressed: onPressed,
        icon: SvgPicture.asset(
          iconPath,
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            Theme.of(context).iconTheme.color ?? Colors.black,
            BlendMode.srcIn,
          ),
        ),
      );
    }

    // Query all chats where current user is involved
    final chatsQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chatsQuery,
      builder: (context, chatsSnap) {
        if (!chatsSnap.hasData) {
          return IconButton(
            tooltip: 'Messages',
            onPressed: onPressed,
            icon: SvgPicture.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                Theme.of(context).iconTheme.color ?? Colors.black,
                BlendMode.srcIn,
              ),
            ),
          );
        }

        final chats = chatsSnap.data?.docs ?? [];
        final chatIds = chats.map((doc) => doc.id).toList();

        return StreamBuilder<int>(
          stream: _getUnreadCount(chatIds, uid),
          builder: (context, countSnap) {
            final totalUnread = countSnap.data ?? 0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Messages',
                  onPressed: onPressed,
                  icon: SvgPicture.asset(
                    iconPath,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).iconTheme.color ?? Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                if (totalUnread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        totalUnread > 99 ? '99+' : totalUnread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // Count chats that have unread messages (not individual messages)
  // Each user/conversation counts as 1, regardless of message count
  // Only counts messages that arrived after the user last viewed the chat
  Stream<int> _getUnreadCount(List<String> chatIds, String currentUserId) {
    if (chatIds.isEmpty) {
      return Stream.value(0);
    }

    // Create a combined stream that emits whenever any chat's messages change
    return Stream.periodic(const Duration(milliseconds: 1000), (_) async {
      int chatCount = 0;
      for (final chatId in chatIds) {
        try {
          // Get the chat document to check lastViewedAt timestamp
          final chatDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();
          
          final chatData = chatDoc.data();
          final lastViewedAt = chatData?['lastViewedAt_$currentUserId'] as Timestamp?;
          
          // Query messages - handle both unread check and senderId filter
          // Firestore doesn't allow isNotEqualTo with isGreaterThan in same query without composite index
          // So we'll query by createdAt first, then filter by senderId client-side
          Query<Map<String, dynamic>> messagesQuery = FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages');
          
          // If user has viewed this chat before, only get messages after that time
          if (lastViewedAt != null) {
            messagesQuery = messagesQuery.where(
              'createdAt',
              isGreaterThan: lastViewedAt,
            );
          }
          
          // Get all unread messages (or all if never viewed)
          final snapshot = await messagesQuery.get();
          
          // Filter for messages from other users (including admins) and check if any exist
          final hasUnreadFromOthers = snapshot.docs.any((doc) {
            final msgData = doc.data();
            final senderId = msgData['senderId'] as String?;
            // Count messages from anyone except the current user (including admins)
            return senderId != null && senderId != currentUserId;
          });
          
          // If there are any unread messages from other users (including admins), count this chat
          if (hasUnreadFromOthers) {
            chatCount++;
          }
        } catch (_) {
          // Skip this chat if there's an error
        }
      }
      return chatCount;
    }).asyncMap((future) => future);
  }
}
