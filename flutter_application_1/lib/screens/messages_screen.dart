import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../widgets/profile_avatar.dart';

class MessagesScreen extends StatefulWidget {
  final String? peerUserId;
  final String? initialName;
  final String? initialAvatarUrl;
  const MessagesScreen({super.key, this.peerUserId, this.initialName, this.initialAvatarUrl});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ValueNotifier<bool> _isFocusedNotifier = ValueNotifier<bool>(false);
  final ImagePicker _picker = ImagePicker();
  int _previousMessageCount = 0;
  bool _isInitialLoad = true;
  
  @override
  void initState() {
    super.initState();
    // Ensure chat document exists when opening screen
    _ensureChatExists();
    // Mark chat as read when opening the messages screen
    _markChatAsRead();
    // Reset initial load flag when opening chat
    _isInitialLoad = true;
    // Listen to focus changes
    _messageFocusNode.addListener(() {
      _isFocusedNotifier.value = _messageFocusNode.hasFocus;
    });
  }
  
  Future<void> _ensureChatExists() async {
    final chatId = _chatId;
    if (chatId == null || _currentUid == null || widget.peerUserId == null || widget.peerUserId!.isEmpty) return;
    
    try {
      // Check if chat document exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      // If chat doesn't exist, create it with minimal data
      if (!chatDoc.exists) {
        // Get peer user info to store permanently in chat - check both users and admins
        String? peerName;
        String? peerAvatar;
        try {
          // Try users collection first
          final peerDoc = await _firestore.collection('users').doc(widget.peerUserId).get();
          final peerData = peerDoc.data();
          if (peerData != null) {
            final rawName = (peerData['name'] as String?)?.trim() ?? '';
            peerName = rawName.isNotEmpty ? rawName : ((peerData['fullName'] as String?)?.trim() ?? '');
            peerAvatar = (peerData['profileImageUrl'] as String?)?.trim() ?? '';
          }
          
          // If not found in users, try admins collection
          if (peerAvatar == null || peerAvatar.isEmpty) {
            try {
              final adminDoc = await _firestore.collection('admins').doc(widget.peerUserId).get();
              final adminData = adminDoc.data();
              if (adminData != null) {
                if (peerName == null || peerName.isEmpty) {
                  final rawName = (adminData['name'] as String?)?.trim() ?? '';
                  peerName = rawName.isNotEmpty ? rawName : ((adminData['fullName'] as String?)?.trim() ?? '');
                }
                if (peerAvatar == null || peerAvatar.isEmpty) {
                  peerAvatar = (adminData['profileImageUrl'] as String?)?.trim() ?? '';
                }
              }
            } catch (_) {}
          }
        } catch (_) {}
        
        // Use initial values as fallback
        peerName ??= widget.initialName ?? 'User';
        peerAvatar ??= widget.initialAvatarUrl ?? '';
        
        // Create chat document
        await _firestore.collection('chats').doc(chatId).set({
          'users': [_currentUid, widget.peerUserId],
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          // Store peer user info permanently
          'peerName_${widget.peerUserId}': peerName,
          'peerAvatar_${widget.peerUserId}': peerAvatar,
        }, SetOptions(merge: false));
      }
    } catch (e) {
      print('Error ensuring chat exists: $e');
    }
  }

  static const List<String> _weekdayNames = [
    'Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'
  ];

  String _formatDayTime(DateTime d) {
    final wd = _weekdayNames[(d.weekday - 1) % 7];
    int hour = d.hour;
    final am = hour < 12;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$wd ${hour12.toString().padLeft(2, '0')}:$minute ${am ? 'AM' : 'PM'}';
  }

  String? get _currentUid => _auth.currentUser?.uid;

  String? get _chatId {
    if (_currentUid == null || widget.peerUserId == null || widget.peerUserId!.isEmpty) return null;
    final a = _currentUid!;
    final b = widget.peerUserId!;
    // Deterministic chat id (lexicographical order)
    return (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';
  }

  Future<void> _pickAndSendMedia() async {
    final chatId = _chatId;
    if (chatId == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Send Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
                  if (x == null) return;
                  final url = await AuthService.uploadImageToCloudinary(x.path);
                  if (url == null) return;
                  await _sendMediaMessage(url, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Send Video'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final v = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
                  if (v == null) return;
                  final url = await AuthService.uploadImageToCloudinary(v.path);
                  if (url == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Video upload failed or not supported.')),
                      );
                    }
                    return;
                  }
                  await _sendMediaMessage(url, 'video');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMediaMessage(String url, String type) async {
    final chatId = _chatId;
    if (chatId == null || _currentUid == null || widget.peerUserId == null) return;
    try {
      // Get peer user info to store permanently in chat - check both users and admins
      String? peerName;
      String? peerAvatar;
      try {
        // Try users collection first
        final peerDoc = await _firestore.collection('users').doc(widget.peerUserId).get();
        final peerData = peerDoc.data();
        if (peerData != null) {
          final rawName = (peerData['name'] as String?)?.trim() ?? '';
          peerName = rawName.isNotEmpty ? rawName : ((peerData['fullName'] as String?)?.trim() ?? '');
          peerAvatar = (peerData['profileImageUrl'] as String?)?.trim() ?? '';
        }
        
        // If not found in users, try admins collection
        if (peerAvatar == null || peerAvatar.isEmpty) {
          try {
            final adminDoc = await _firestore.collection('admins').doc(widget.peerUserId).get();
            final adminData = adminDoc.data();
            if (adminData != null) {
              if (peerName == null || peerName.isEmpty) {
                final rawName = (adminData['name'] as String?)?.trim() ?? '';
                peerName = rawName.isNotEmpty ? rawName : ((adminData['fullName'] as String?)?.trim() ?? '');
              }
              if (peerAvatar == null || peerAvatar.isEmpty) {
                peerAvatar = (adminData['profileImageUrl'] as String?)?.trim() ?? '';
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
      
      // Use initial values as fallback
      peerName ??= widget.initialName ?? 'User';
      peerAvatar ??= widget.initialAvatarUrl ?? '';
      
      await _firestore.collection('chats').doc(chatId).set({
        'users': [_currentUid, widget.peerUserId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': type == 'image' ? '[photo]' : '[video]',
        // Store peer user info permanently (for the other user viewing this chat)
        'peerName_${widget.peerUserId}': peerName,
        'peerAvatar_${widget.peerUserId}': peerAvatar,
      }, SetOptions(merge: true));
      final payload = <String, dynamic>{
        'senderId': _currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (type == 'image') {
        payload['imageUrl'] = url;
        payload['type'] = 'image';
      } else {
        payload['videoUrl'] = url;
        payload['type'] = 'video';
      }
      await _firestore.collection('chats').doc(chatId).collection('messages').add(payload);
      // Don't auto-scroll - let messages appear naturally at the bottom
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final chatId = _chatId;
    final text = _textController.text.trim();
    if (chatId == null || text.isEmpty || _currentUid == null || widget.peerUserId == null) return;
    
    _textController.clear();
    
    try {
      // Get peer user info to store permanently in chat - check both users and admins
      String? peerName;
      String? peerAvatar;
      try {
        // Try users collection first
        final peerDoc = await _firestore.collection('users').doc(widget.peerUserId).get();
        final peerData = peerDoc.data();
        if (peerData != null) {
          final rawName = (peerData['name'] as String?)?.trim() ?? '';
          peerName = rawName.isNotEmpty ? rawName : ((peerData['fullName'] as String?)?.trim() ?? '');
          peerAvatar = (peerData['profileImageUrl'] as String?)?.trim() ?? '';
        }
        
        // If not found in users, try admins collection
        if (peerAvatar == null || peerAvatar.isEmpty) {
          try {
            final adminDoc = await _firestore.collection('admins').doc(widget.peerUserId).get();
            final adminData = adminDoc.data();
            if (adminData != null) {
              if (peerName == null || peerName.isEmpty) {
                final rawName = (adminData['name'] as String?)?.trim() ?? '';
                peerName = rawName.isNotEmpty ? rawName : ((adminData['fullName'] as String?)?.trim() ?? '');
              }
              if (peerAvatar == null || peerAvatar.isEmpty) {
                peerAvatar = (adminData['profileImageUrl'] as String?)?.trim() ?? '';
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
      
      // Use initial values as fallback
      peerName ??= widget.initialName ?? 'User';
      peerAvatar ??= widget.initialAvatarUrl ?? '';
      
      // Ensure chat document exists with both users and permanent peer info
      await _firestore.collection('chats').doc(chatId).set({
        'users': [_currentUid, widget.peerUserId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
        // Store peer user info permanently (for the other user viewing this chat)
        'peerName_${widget.peerUserId}': peerName,
        'peerAvatar_${widget.peerUserId}': peerAvatar,
      }, SetOptions(merge: true));
      
      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': _currentUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Don't force scroll - let the StreamBuilder naturally add the message
      // This prevents reload/refresh when sending messages
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
      // Restore text if sending failed
      _textController.text = text;
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final chatId = _chatId;
    if (chatId == null || _currentUid == null) return;
    
    try {
      // Get message data to check if user can delete it
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();
      
      if (!messageDoc.exists) return;
      
      final messageData = messageDoc.data();
      final senderId = messageData?['senderId'] as String?;
      
      // Only allow deletion if user sent the message or is admin
      // (Firestore rules will also enforce this)
      if (senderId != _currentUid) {
        // Check if user is admin
        try {
          final adminDoc = await _firestore.collection('admins').doc(_currentUid).get();
          if (!adminDoc.exists) {
            // Silently fail - no notification
            return;
          }
        } catch (_) {
          // Silently fail - no notification
          return;
        }
      }
      
      // Delete the message silently - no notifications
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      // No success notification
    } catch (e) {
      // Silently handle errors - no error notification
    }
  }


  Future<void> _markChatAsRead() async {
    final chatId = _chatId;
    final currentUid = _currentUid;
    if (chatId == null || currentUid == null) return;
    
    try {
      // Update the lastViewedAt timestamp for the current user
      await _firestore.collection('chats').doc(chatId).set({
        'lastViewedAt_$currentUid': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently handle errors - not critical if this fails
      print('Error marking chat as read: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _isFocusedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _chatId;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.blue,
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
            title: widget.peerUserId != null && widget.peerUserId!.isNotEmpty
                ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.peerUserId)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final u = userSnap.data?.data();
                      final name = (u?['name'] as String?)?.trim() ?? 
                                   widget.initialName ?? 
                                   'User';
                      final avatar = (u?['profileImageUrl'] as String?)?.trim() ?? 
                                     widget.initialAvatarUrl ?? 
                                     '';
                      // Determine last active time from common fields if available
                      final ts = (u?['lastActiveAt'] as Timestamp?)
                          ?? (u?['lastSeenAt'] as Timestamp?)
                          ?? (u?['updatedAt'] as Timestamp?);
                      String activeText = '';
                      if (ts != null) {
                        final d = ts.toDate().toLocal();
                        final now = DateTime.now();
                        final diff = now.difference(d);
                        String rel;
                        if (diff.inSeconds < 5) {
                          rel = 'now';
                        } else if (diff.inSeconds < 60) {
                          rel = '${diff.inSeconds}s ago';
                        } else if (diff.inMinutes < 60) {
                          rel = '${diff.inMinutes}m ago';
                        } else if (diff.inHours < 24) {
                          rel = '${diff.inHours}h ago';
                        } else if (diff.inDays == 1) {
                          final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
                          final mm = d.minute.toString().padLeft(2, '0');
                          final ampm = d.hour >= 12 ? 'PM' : 'AM';
                          rel = 'Yesterday at $h12:$mm $ampm';
                        } else if (diff.inDays < 7) {
                          final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
                          final mm = d.minute.toString().padLeft(2, '0');
                          final ampm = d.hour >= 12 ? 'PM' : 'AM';
                          rel = '${diff.inDays} days ago at $h12:$mm $ampm';
                        } else {
                          final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
                          final mm = d.minute.toString().padLeft(2, '0');
                          final ampm = d.hour >= 12 ? 'PM' : 'AM';
                          rel = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} $h12:$mm $ampm';
                        }
                        activeText = 'Active $rel';
                      }
                      
                      return Row(
                        children: [
                          const SizedBox(width: 8),
                          ProfileAvatar(
                            radius: 18,
                            imageUrl: avatar.isNotEmpty ? avatar : null,
                            displayName: name,
                            userId: widget.peerUserId,
                            showOnlineIndicator: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                if (activeText.isNotEmpty)
                                  Text(
                                    activeText,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : const SizedBox.shrink(),
        actions: [
          if (widget.peerUserId != null && widget.peerUserId!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.call),
              color: Colors.blue,
              tooltip: 'Call',
              onPressed: () {
                // TODO: Implement call functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.videocam),
              color: Colors.blue,
              tooltip: 'Video Call',
              onPressed: () {
                // TODO: Implement video call functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              color: Colors.blue,
              tooltip: 'User Information',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _UserInfoPage(
                      peerUserId: widget.peerUserId!,
                      initialName: widget.initialName,
                      initialAvatarUrl: widget.initialAvatarUrl,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatId == null
                ? const Center(child: Text('No recipient selected'))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snap) {
                      // Handle errors
                      if (snap.hasError) {
                        print('Error loading messages: ${snap.error}');
                        // If error is due to missing index or permissions, show empty state
                        return Center(
                          child: Text(
                            'Unable to load messages. Error: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      }
                      
                      // Show loading only if we're truly waiting and have no data
                      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final docs = snap.data?.docs ?? [];
                      final currentMessageCount = docs.length;
                      
                      // Update message count when new messages arrive
                      if (currentMessageCount != _previousMessageCount) {
                        _previousMessageCount = currentMessageCount;
                        // Reset initial load flag when we get messages
                        if (docs.isNotEmpty && _isInitialLoad) {
                          _isInitialLoad = false;
                        }
                      }
                      
                      // Reset flag when we have data
                      if (docs.isNotEmpty && _isInitialLoad) {
                        _isInitialLoad = false;
                      }
                      
                      // Use reverse: true so ListView naturally starts at the bottom (latest messages visible)
                      // This eliminates scrolling on load - chat opens directly at the bottom without any scroll animation
                      return ListView.builder(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        cacheExtent: 500,
                        padding: EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: MediaQuery.of(context).padding.bottom + 20, // Top padding for bottom-aligned messages
                          bottom: 6,
                        ),
                        reverse: true,
                        itemCount: docs.length + ((widget.peerUserId != null && widget.peerUserId!.isNotEmpty) ? 1 : 0),
                        itemBuilder: (context, index) {
                          // With reverse: true, the top-most index equals docs.length (header position)
                          final bool hasHeader = widget.peerUserId != null && widget.peerUserId!.isNotEmpty;
                          final int headerIndex = docs.length;
                          if (hasHeader && index == headerIndex) {
                            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _firestore
                                  .collection('users')
                                  .doc(widget.peerUserId)
                                  .snapshots(),
                              builder: (context, userSnap) {
                                final u = userSnap.data?.data();
                                final name = (u?['name'] as String?)?.trim() ?? widget.initialName ?? 'User';
                                final avatar = (u?['profileImageUrl'] as String?)?.trim() ?? widget.initialAvatarUrl ?? '';
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ProfileAvatar(
                                        radius: 42,
                                        imageUrl: avatar.isNotEmpty ? avatar : null,
                                        displayName: name,
                                        showOnlineIndicator: false,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                          // With reverse: true, ListView builds from bottom to top
                          // So index 0 is the latest message, index length-1 is the oldest
                          // We need to reverse the index to get messages in chronological order
                          final reversedIndex = docs.length - 1 - index;
                          final messageDoc = docs[reversedIndex];
                          final m = messageDoc.data();
                          final messageId = messageDoc.id;
                          final isMine = m['senderId'] == _currentUid;
                          final text = (m['text'] as String?) ?? '';
                          final imageUrl = (m['imageUrl'] as String?) ?? '';
                          final videoUrl = (m['videoUrl'] as String?) ?? '';
                          final dt = (m['createdAt'] as Timestamp?)?.toDate().toLocal();
                          final prevDt = reversedIndex > 0
                              ? (docs[reversedIndex - 1].data()['createdAt'] as Timestamp?)?.toDate().toLocal()
                              : null;
                          final showDayHeader = dt != null && (prevDt == null ||
                              dt.year != prevDt.year || dt.month != prevDt.month || dt.day != prevDt.day);
                          
                          // Check if this message has been seen by the recipient
                          // For messages sent by current user, check if peer has viewed after message was sent
                          // For messages received, check if current user has viewed after message was sent
                          return RepaintBoundary(
                            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _chatId != null
                                  ? _firestore.collection('chats').doc(_chatId!).snapshots()
                                  : const Stream.empty(),
                              builder: (context, chatSnap) {
                              final chatData = chatSnap.data?.data() ?? {};
                              final messageTimestamp = m['createdAt'] as Timestamp?;
                              
                              // Get peer avatar from chat document (stored permanently)
                              // Also fetch from users/admins collections if not found
                              final storedPeerAvatar = (chatData['peerAvatar_${widget.peerUserId}'] as String?)?.trim();
                              String peerAvatar = storedPeerAvatar ?? widget.initialAvatarUrl ?? '';
                              
                              // If not found, fetch from users or admins collection for seen indicator
                              if (peerAvatar.isEmpty) {
                                // This will be handled dynamically in the seen indicator
                              }
                              
                              bool isSeen = false;
                              Color bubbleColor;
                              Color textColor;
                              final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
                              
                              if (isMine) {
                                // Message sent by current user - check if peer has seen it
                                final peerViewedAt = chatData['lastViewedAt_${widget.peerUserId}'] as Timestamp?;
                                if (peerViewedAt != null && messageTimestamp != null) {
                                  final viewedDate = peerViewedAt.toDate();
                                  final msgDate = messageTimestamp.toDate();
                                  // Message is seen if peer viewed it after the message was sent (with small tolerance)
                                  isSeen = viewedDate.isAfter(msgDate.subtract(const Duration(milliseconds: 1000))) || 
                                          viewedDate.isAtSameMomentAs(msgDate);
                                  
                                  // Debug: Print seen status
                                  print('DEBUG: Message at ${msgDate.toString()}, Peer viewed at ${viewedDate.toString()}, isSeen=$isSeen');
                                } else {
                                  isSeen = false;
                                }
                                
                                // Sent messages: Blue/White theme
                                bubbleColor = Colors.blue.shade400;
                                textColor = Colors.white;
                              } else {
                                // Message received from peer - check if current user has seen it
                                final currentUserViewedAt = chatData['lastViewedAt_$_currentUid'] as Timestamp?;
                                isSeen = currentUserViewedAt != null && 
                                    messageTimestamp != null &&
                                    currentUserViewedAt.toDate().isAfter(messageTimestamp.toDate());
                                
                                // Received messages
                                if (isDarkMode) {
                                  bubbleColor = Colors.white;
                                  textColor = Colors.black;
                                } else {
                                  bubbleColor = Colors.grey.shade200; // subtle contrast on white background
                                  textColor = Colors.black;
                                }
                              }
                              
                              return Align(
                                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (showDayHeader)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Center(
                                          child: Text(
                                            _formatDayTime(dt),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    // Row for message with avatar (if not mine) or just message (if mine)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      textDirection: isMine ? TextDirection.rtl : TextDirection.ltr,
                                      children: [
                                        // Show peer avatar next to their messages (left side)
                                        if (!isMine)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8, bottom: 4),
                                            child: ProfileAvatar(
                                              radius: 14,
                                              imageUrl: peerAvatar.isNotEmpty ? peerAvatar : null,
                                              displayName: null,
                                              userId: widget.peerUserId,
                                            showOnlineIndicator: false,
                                            ),
                                          ),
                                        Builder(
                                          builder: (builderContext) {
                                            return GestureDetector(
                                              onLongPress: () {
                                                // Show modern context menu with blurry background for deleting message
                                                final RenderBox? renderBox = builderContext.findRenderObject() as RenderBox?;
                                                if (renderBox == null) return;
                                                
                                                final Offset position = renderBox.localToGlobal(Offset.zero);
                                                final Size size = renderBox.size;
                                                
                                                showDialog(
                                                  context: context,
                                                  barrierColor: Colors.transparent,
                                                  barrierDismissible: true,
                                                  builder: (dialogContext) {
                                                    return BackdropFilter(
                                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                                      child: Stack(
                                                        children: [
                                                          Positioned(
                                                            left: isMine 
                                                                ? position.dx + size.width / 2 - 60
                                                                : position.dx + size.width / 2 - 60,
                                                            top: position.dy - 50,
                                                            child: Material(
                                                              color: Colors.transparent,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  Navigator.pop(dialogContext);
                                                                  _deleteMessage(messageId);
                                                                },
                                                                borderRadius: BorderRadius.circular(12),
                                                                child: Container(
                                                                  constraints: const BoxConstraints(
                                                                    minWidth: 85,
                                                                    maxWidth: 110,
                                                                  ),
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 10,
                                                                    vertical: 8,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: Theme.of(context).brightness == Brightness.dark
                                                                        ? Colors.white.withOpacity(0.1)
                                                                        : Colors.white.withOpacity(0.9),
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors.black.withOpacity(0.15),
                                                                        blurRadius: 10,
                                                                        spreadRadius: 1,
                                                                        offset: const Offset(0, 4),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                                    children: [
                                                                      Icon(
                                                                        Icons.delete_outline,
                                                                        color: Colors.red,
                                                                        size: 16,
                                                                      ),
                                                                      const SizedBox(width: 6),
                                                                      Text(
                                                                        'Delete',
                                                                        style: TextStyle(
                                                                          color: Theme.of(context).brightness == Brightness.dark
                                                                              ? Colors.white
                                                                              : Colors.black87,
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                              child: Builder(builder: (context) {
                                                // For images, show without container/border - plain image
                                                if (imageUrl.isNotEmpty) {
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                                    constraints: BoxConstraints(
                                                      // Different maxWidth for sent vs received messages
                                                      maxWidth: isMine 
                                                          ? MediaQuery.of(context).size.width * 0.72
                                                          : MediaQuery.of(context).size.width * 0.65,
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: Image.network(imageUrl, fit: BoxFit.cover),
                                                    ),
                                                  );
                                                }
                                                
                                                // For text/video messages, use the container with background
                                                return Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                                  padding: EdgeInsets.zero,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    constraints: BoxConstraints(
                                                      // Different maxWidth for sent vs received messages
                                                      maxWidth: isMine 
                                                          ? MediaQuery.of(context).size.width * 0.72
                                                          : MediaQuery.of(context).size.width * 0.65,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: bubbleColor,
                                                      borderRadius: BorderRadius.only(
                                                        topLeft: Radius.circular(isMine ? 14 : 6),
                                                        topRight: Radius.circular(isMine ? 6 : 14),
                                                        bottomLeft: const Radius.circular(14),
                                                        bottomRight: const Radius.circular(14),
                                                      ),
                                                      // Shadow effect for sent messages (black theme)
                                                      boxShadow: isMine
                                                          ? [
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.2),
                                                                blurRadius: 4,
                                                                spreadRadius: 0.5,
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: videoUrl.isNotEmpty
                                                        ? Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.videocam, size: 16, color: textColor),
                                                              const SizedBox(width: 4),
                                                              Flexible(child: Text('[video]', style: TextStyle(color: textColor))),
                                                            ],
                                                          )
                                                        : Text(text, style: TextStyle(color: textColor)),
                                                  ),
                                                );
                                              }),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    // Show peer's profile image as "seen" indicator on the latest SEEN message from current user
                                    // If the latest message hasn't been seen yet, show on the previous latest seen message
                                    Builder(
                                      builder: (context) {
                                        // Find the latest SEEN message from current user
                                        int latestSeenMessageIndex = -1;
                                        if (isMine) {
                                          // Search backwards from the end to find the latest seen message
                                          for (int i = docs.length - 1; i >= 0; i--) {
                                            final docData = docs[i].data();
                                            final senderId = docData['senderId'] as String?;
                                            if (senderId == _currentUid) {
                                              // Check if this message would be seen
                                              final msgTimestamp = docData['createdAt'] as Timestamp?;
                                              final chatDataMap = chatData;
                                              final peerViewedAt = chatDataMap['lastViewedAt_${widget.peerUserId}'] as Timestamp?;
                                              bool msgIsSeen = false;
                                              if (peerViewedAt != null && msgTimestamp != null) {
                                                final viewedDate = peerViewedAt.toDate();
                                                final msgDate = msgTimestamp.toDate();
                                                msgIsSeen = viewedDate.isAfter(msgDate.subtract(const Duration(milliseconds: 1000))) || 
                                                          viewedDate.isAtSameMomentAs(msgDate);
                                              }
                                              
                                              if (msgIsSeen) {
                                                latestSeenMessageIndex = i;
                                                break;
                                              }
                                            }
                                          }
                                        }
                                        
                                        // Show indicator if this is the latest seen message
                                        // Note: index here is the reversed index, so we need to check against reversedIndex
                                        final reversedIndex = docs.length - 1 - index;
                                        bool showIndicator = isMine && 
                                                           (latestSeenMessageIndex == reversedIndex) && 
                                                           isSeen;
                                        
                                        if (!showIndicator) {
                                          return const SizedBox.shrink();
                                        }
                                        
                                        // Fetch peer avatar from users or admins collection for seen indicator
                                        // Use StreamBuilder to fetch dynamically
                                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                          stream: widget.peerUserId != null && widget.peerUserId!.isNotEmpty
                                              ? _firestore.collection('users').doc(widget.peerUserId).snapshots()
                                              : const Stream.empty(),
                                          builder: (context, userSnap) {
                                            final userData = userSnap.data?.data();
                                            String? seenAvatar = (userData?['profileImageUrl'] as String?)?.trim();
                                            
                                            // If not found in users, try admins collection
                                            if (seenAvatar == null || seenAvatar.isEmpty) {
                                              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                                stream: widget.peerUserId != null && widget.peerUserId!.isNotEmpty
                                                    ? _firestore.collection('admins').doc(widget.peerUserId).snapshots()
                                                    : const Stream.empty(),
                                                builder: (context, adminSnap) {
                                                  final adminData = adminSnap.data?.data();
                                                  final adminAvatar = (adminData?['profileImageUrl'] as String?)?.trim() ?? '';
                                                  final finalAvatar = adminAvatar.isNotEmpty
                                                      ? adminAvatar
                                                      : (storedPeerAvatar ?? widget.initialAvatarUrl ?? '');
                                                  
                                                  if (finalAvatar.isNotEmpty) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 2, right: 8),
                                                      child: CircleAvatar(
                                                        radius: 8,
                                                        backgroundImage: NetworkImage(finalAvatar),
                                                        onBackgroundImageError: (_, __) {},
                                                      ),
                                                    );
                                                  }
                                                  
                                                  return const SizedBox.shrink();
                                                },
                                              );
                                            }
                                            
                                            // Use stored or initial avatar as fallback
                                            final finalAvatar = seenAvatar.isNotEmpty
                                                ? seenAvatar
                                                : (storedPeerAvatar ?? widget.initialAvatarUrl ?? '');
                                            
                                            if (finalAvatar.isNotEmpty) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 2, right: 8),
                                                child: CircleAvatar(
                                                  radius: 8,
                                                  backgroundImage: NetworkImage(finalAvatar),
                                                  onBackgroundImageError: (_, __) {},
                                                ),
                                              );
                                            }
                                            
                                            return const SizedBox.shrink();
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Icon group (left side) - transforms when focused or typing
                    ValueListenableBuilder<bool>(
                      valueListenable: _isFocusedNotifier,
                      builder: (context, isFocused, _) {
                        return ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textController,
                          builder: (context, value, child) {
                            const blueColor = Colors.blue; // Blue color for all icons
                            const iconSize = 32.0; // Container size for icons (+, camera, gallery, mic, arrow)
                            const iconInnerSize = 22.0; // Match like icon size (22) for all icon contents
                            final hasText = value.text.isNotEmpty; // Check for any text, even spaces
                            // Transform when field is focused OR has text
                            final shouldTransform = isFocused || hasText;
                        
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            // Plus/Arrow icon - transforms from + to > when typing
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              child: Container(
                                key: ValueKey(shouldTransform ? 'arrow' : 'plus'),
                                width: iconSize,
                                height: iconSize,
                                decoration: const BoxDecoration(
                                  color: blueColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: shouldTransform 
                                        ? () {
                                            // When arrow is clicked, unfocus field and restore original form
                                            _messageFocusNode.unfocus();
                                            // Optionally clear text to fully reset
                                            _textController.clear();
                                          }
                                        : _pickAndSendMedia,
                                    child: Icon(
                                      shouldTransform ? Icons.arrow_forward : Icons.add,
                                      color: Colors.white,
                                      size: iconInnerSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Camera, Gallery, Mic icons - hide when focused or typing with smooth animation
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              child: shouldTransform
                                  ? const SizedBox.shrink(key: ValueKey('hidden'))
                                  : Row(
                                      key: const ValueKey('visible'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                          const SizedBox(width: 4),
                                          // Camera icon (blue)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder: const CircleBorder(),
                                              onTap: () async {
                                                final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
                                                if (x == null) return;
                                                final url = await AuthService.uploadImageToCloudinary(x.path);
                                                if (url == null) return;
                                                await _sendMediaMessage(url, 'image');
                                              },
                                              child: Container(
                                                width: iconSize,
                                                height: iconSize,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.camera_alt_outlined,
                                                  color: blueColor,
                                                  size: iconInnerSize,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // Gallery icon (blue)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder: const CircleBorder(),
                                              onTap: () async {
                                                final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
                                                if (x == null) return;
                                                final url = await AuthService.uploadImageToCloudinary(x.path);
                                                if (url == null) return;
                                                await _sendMediaMessage(url, 'image');
                                              },
                                              child: Container(
                                                width: iconSize,
                                                height: iconSize,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.photo_library_outlined,
                                                  color: blueColor,
                                                  size: iconInnerSize,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // Microphone icon (blue)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder: const CircleBorder(),
                                              onTap: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Voice messages coming soon')),
                                                );
                                              },
                                              child: Container(
                                                width: iconSize,
                                                height: iconSize,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.mic_outlined,
                                                  color: blueColor,
                                                  size: iconInnerSize,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    // Text input field (light gray rounded) - expands when typing
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _textController,
                        builder: (context, value, child) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final hasText = value.text.isNotEmpty;
                          // Allow expansion when user is typing
                          final maxLines = hasText ? 6 : 1;
                          
                          return TextField(
                            controller: _textController,
                            focusNode: _messageFocusNode,
                            minLines: 1,
                            maxLines: maxLines,
                            textAlignVertical: TextAlignVertical.center,
                            textInputAction: hasText ? TextInputAction.newline : TextInputAction.send,
                            onSubmitted: (_) {
                              // Only send on enter if text is short or empty, otherwise allow new lines when typing
                              if (!hasText || _textController.text.trim().length < 50) {
                                _sendMessage();
                              }
                            },
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                fontSize: 15,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              isDense: true,
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              suffixIcon: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Emoji picker coming soon')),
                                    );
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.mood_outlined,
                                      color: Colors.blue,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Like/Send button - changes based on text input
                    // Use ValueListenableBuilder to update only the button, not the entire screen
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: hasText
                                ? () => _sendMessage() // Send message if text exists
                                : () {
                                    // Send thumbs-up emoji if no text
                                    _textController.text = '👍';
                                    _sendMessage();
                                  },
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: Icon(
                                hasText ? Icons.send : Icons.thumb_up,
                                color: Colors.blue,
                                size: 22,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoPage extends StatelessWidget {
  const _UserInfoPage({
    required this.peerUserId,
    this.initialName,
    this.initialAvatarUrl,
  });
  final String peerUserId;
  final String? initialName;
  final String? initialAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Information',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(peerUserId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snap.hasData || !(snap.data?.exists ?? false)) {
            return const Center(child: Text('User not found'));
          }
          
          final userData = snap.data!.data() ?? {};
          final rawName = (userData['name'] as String?)?.trim() ?? '';
          final name = rawName.isNotEmpty 
              ? rawName 
              : ((userData['fullName'] as String?)?.trim() ?? initialName ?? 'Unknown User');
          final email = (userData['email'] as String?)?.trim() ?? '';
          final imageUrl = (userData['profileImageUrl'] as String?)?.trim() ?? (initialAvatarUrl ?? '');
          final createdAt = userData['createdAt'] as Timestamp?;
          
          DateTime? joinedDate;
          if (createdAt != null) {
            joinedDate = createdAt.toDate();
          }
          
          String formatDate(DateTime date) {
            final months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final month = months[date.month - 1];
            final day = date.day.toString().padLeft(2, '0');
            final year = date.year;
            return '$month $day, $year';
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Profile Avatar with outline circle
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black.withOpacity(0.2),
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : null,
                        onBackgroundImageError: (_, __) {},
                        child: imageUrl.isEmpty
                            ? (name.isNotEmpty
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 45,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Icon(Icons.person, size: 50))
                            : null,
                      ),
                      // Green online indicator - properly positioned at bottom-right
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Name
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 32),
                // Email
                if (email.isNotEmpty) ...[
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  if (joinedDate != null) const SizedBox(height: 16),
                ],
                // Joined Date
                if (joinedDate != null)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Joined',
                    value: formatDate(joinedDate),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


