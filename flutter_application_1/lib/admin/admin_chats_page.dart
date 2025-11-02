import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/messages_screen.dart';
import '../widgets/profile_avatar.dart';

class AdminChatsPage extends StatefulWidget {
  final FirebaseFirestore firestore;
  const AdminChatsPage({super.key, required this.firestore});

  @override
  State<AdminChatsPage> createState() => _AdminChatsPageState();
}

class _AdminChatsPageState extends State<AdminChatsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }
    final chatsQuery = widget.firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatsQuery,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          return _ChatsList(
            docs: docs,
            uid: uid,
            searchController: _searchController,
            firestore: widget.firestore,
          );
        },
      ),
    );
  }
}

class _ChatsList extends StatefulWidget {
  const _ChatsList({
    required this.docs,
    required this.uid,
    required this.searchController,
    required this.firestore,
  });
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String uid;
  final TextEditingController searchController;
  final FirebaseFirestore firestore;

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
    // Sort by updatedAt desc on client
    final sorted = [...widget.docs];
    sorted.sort((a, b) {
      final ta = (a.data()['updatedAt'] as Timestamp?);
      final tb = (b.data()['updatedAt'] as Timestamp?);
      final da = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                  hintText: 'Search by name',
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
            child: ListView.builder(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight,
              ),
              itemCount: sorted.length,
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
                  stream: widget.firestore
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
                          ? widget.firestore
                              .collection('chats')
                              .doc(chatId)
                              .collection('messages')
                              .where('createdAt', isGreaterThan: lastViewedAt)
                              .snapshots()
                          : widget.firestore
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
                          stream: widget.firestore.collection('users').doc(peerId).snapshots(),
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
                            
                            if (isLastMessageFromMe) {
                              // Message sent by current user (admin)
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
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: ProfileAvatar(
                                radius: 24,
                                imageUrl: avatar.isNotEmpty ? avatar : null,
                                displayName: null,
                                userId: peerId.isNotEmpty ? peerId : null,
                              ),
                              title: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                  color: hasUnread 
                                      ? Theme.of(context).colorScheme.onSurface 
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                                ),
                              ),
                              subtitle: Text(
                                subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    timeStr, 
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasUnread 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Colors.grey.shade600,
                                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
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

