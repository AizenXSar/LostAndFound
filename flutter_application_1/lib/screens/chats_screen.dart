import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'messages_screen.dart';
import '../widgets/profile_avatar.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }
    // Query chats - try with orderBy first, if it fails fall back to in-memory sorting
    // Note: This query requires a composite index in Firestore
    // If you get an error about missing index, create it in Firebase Console
    final chatsQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots()
        .handleError((error) {
      print('Chats query error (might need index): $error');
      // If orderBy fails, we'll sort in memory instead
      return FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: uid)
          .snapshots();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatsQuery,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Check for errors
          if (snap.hasError) {
            print('Error loading chats: ${snap.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snap.error}'),
                  const SizedBox(height: 8),
                  Text('If this is a permission error, please deploy the Firestore rules.'),
                ],
              ),
            );
          }
          
          final docs = snap.data?.docs ?? [];
          print('Loaded ${docs.length} chats for user $uid');

          return _ChatsList(
            docs: docs,
            uid: uid,
            searchController: _searchController,
          );
        },
      ),
    );
  }
}

class _ChatsList extends StatefulWidget {
  const _ChatsList({required this.docs, required this.uid, required this.searchController});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String uid;
  final TextEditingController searchController;

  @override
  State<_ChatsList> createState() => _ChatsListState();
}

class _ChatsListState extends State<_ChatsList> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sort by updatedAt desc (newest first) so latest conversations appear at top
    // This ensures conversations where you sent the last message appear at the top
    final sorted = [...widget.docs];
    sorted.sort((a, b) {
      final ta = (a.data()['updatedAt'] as Timestamp?);
      final tb = (b.data()['updatedAt'] as Timestamp?);
      final da = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      // Descending order - newest first (latest conversation at top)
      // This means if you sent the last message, that conversation will be at the top
      return db.compareTo(da);
    });
    
    // Ensure the list starts at the top to show the latest conversation
    // Since ListView naturally starts at index 0, and we've sorted newest first,
    // the latest conversation (where you sent the last message) will be visible at the top
    final query = widget.searchController.text.trim().toLowerCase();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final hint = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.45);
    final iconColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: widget.searchController,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: iconColor),
                  hintText: 'Search',
                  hintStyle: TextStyle(color: hint),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (sorted.isEmpty)
          const Expanded(child: Center(child: Text('No conversations yet')))
        else
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              cacheExtent: 500,
              padding: EdgeInsets.zero,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                final chatDoc = sorted[index];
                final chatId = chatDoc.id;
                final data = chatDoc.data();
                final users = (data['users'] as List?)?.cast<String>() ?? [];
                final peerId = users.firstWhere((u) => u != widget.uid, orElse: () => '');
                final last = (data['lastMessage'] as String?)?.trim() ?? '';
                final ts = (data['updatedAt'] as Timestamp?);
                final timeStr = ts == null
                    ? ''
                    : TimeOfDay.fromDateTime(ts.toDate().toLocal()).format(context);
                final lastViewedAt = (data['lastViewedAt_${widget.uid}'] as Timestamp?);

                // Get stored peer info from chat document, with fallback to users collection
                final storedName = (data['peerName_$peerId'] as String?)?.trim();
                final storedAvatar = (data['peerAvatar_$peerId'] as String?)?.trim();
                
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, lastMsgSnap) {
                    // Get the last message to check sender
                    String lastMessageSender = '';
                    Timestamp? lastMessageTime;
                    if (lastMsgSnap.hasData && lastMsgSnap.data!.docs.isNotEmpty) {
                      final lastMsg = lastMsgSnap.data!.docs.first.data();
                      lastMessageSender = (lastMsg['senderId'] as String?) ?? '';
                      lastMessageTime = lastMsg['createdAt'] as Timestamp?;
                    }
                    
                    final isLastMessageFromMe = lastMessageSender == widget.uid;
                    
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: lastViewedAt != null && lastMessageTime != null
                          ? FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .collection('messages')
                              .where('createdAt', isGreaterThan: lastViewedAt)
                              .snapshots()
                          : FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .collection('messages')
                              .snapshots(),
                      builder: (context, unreadSnap) {
                        // Count unread messages from others (not from current user)
                        int unreadCount = 0;
                        if (unreadSnap.hasData) {
                          unreadCount = unreadSnap.data!.docs.where((doc) {
                            final msgData = doc.data();
                            final senderId = msgData['senderId'] as String?;
                            // Only count messages from other users (not from current user)
                            return senderId != null && senderId != widget.uid;
                          }).length;
                        }
                        
                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(peerId).snapshots(),
                          builder: (context, userSnap) {
                            // Use stored values first, then fallback to user document, then to defaults
                            final u = userSnap.data?.data() ?? const {};
                            String name;
                            String avatar;
                            
                            if (storedName != null && storedName.isNotEmpty) {
                              name = storedName;
                            } else {
                              final rawName = (u['name'] as String?)?.trim() ?? '';
                              name = rawName.isNotEmpty ? rawName : ((u['fullName'] as String?)?.trim() ?? 'User');
                            }
                            
                            if (storedAvatar != null && storedAvatar.isNotEmpty) {
                              avatar = storedAvatar;
                            } else {
                              avatar = (u['profileImageUrl'] as String?)?.trim() ?? '';
                            }
                            
                            if (query.isNotEmpty && !name.toLowerCase().contains(query)) {
                              return const SizedBox.shrink();
                            }
                            if (peerId.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            // Determine subtitle text and styling based on seen/unseen status
                            String subtitleText;
                            TextStyle subtitleStyle;
                            bool hasUnread = unreadCount > 0;
                            bool isSeen = false;
                            
                            // Check if message has been seen (only for messages sent by current user)
                            if (isLastMessageFromMe && lastMessageTime != null) {
                              final peerViewedAt = (data['lastViewedAt_$peerId'] as Timestamp?);
                              isSeen = peerViewedAt != null && 
                                  peerViewedAt.toDate().isAfter(lastMessageTime.toDate());
                            }
                            
                            if (isLastMessageFromMe) {
                              // Message sent by current user
                              if (last.contains('[photo]')) {
                                subtitleText = 'You sent a photo.';
                              } else if (last.contains('[video]')) {
                                subtitleText = 'You sent a video.';
                              } else if (last.isNotEmpty) {
                                subtitleText = 'You: $last';
                              } else {
                                subtitleText = 'Say hi 👋';
                              }
                              // Seen messages: normal/faded style
                              subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.normal,
                              ) ?? TextStyle(color: Colors.grey.shade600);
                            } else {
                              // Message received from peer
                              if (hasUnread) {
                                // Unread: show count and bold text
                                subtitleText = unreadCount == 1 
                                    ? (last.isNotEmpty ? last : 'Say hi 👋')
                                    : '$unreadCount new messages';
                                subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ) ?? TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                );
                              } else {
                                // Read: normal text
                                subtitleText = last.isNotEmpty ? last : 'Say hi 👋';
                                subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.normal,
                                ) ?? TextStyle(color: Colors.grey.shade600);
                              }
                            }
                            
                            return RepaintBoundary(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                dense: true,
                                minVerticalPadding: 0,
                                visualDensity: VisualDensity.compact,
                                leading: ProfileAvatar(
                                  radius: 20,
                                  imageUrl: avatar.isNotEmpty ? avatar : null,
                                  displayName: null,
                                  userId: peerId,
                                ),
                              title: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                  color: hasUnread 
                                      ? Theme.of(context).colorScheme.onSurface 
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                                  height: 1.2,
                                ),
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.zero,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subtitleText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: subtitleStyle.copyWith(fontSize: 12, height: 1.2),
                                      ),
                                    ),
                                    // Show "seen" indicator for messages sent by current user
                                    if (isLastMessageFromMe && isSeen)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          'seen',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              trailing: Text(
                                timeStr, 
                                style: TextStyle(
                                  fontSize: 10,
                                  color: hasUnread 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Colors.grey.shade600,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                  height: 1.2,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MessagesScreen(
                                      peerUserId: peerId,
                                      initialName: name,
                                      initialAvatarUrl: avatar,
                                    ),
                                  ),
                                );
                              },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}


