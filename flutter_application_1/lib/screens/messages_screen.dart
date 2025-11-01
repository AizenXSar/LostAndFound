import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

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
  final ImagePicker _picker = ImagePicker();

  static const List<String> _weekdayNames = [
    'mon.', 'tue.', 'wed.', 'thu.', 'fri.', 'sat.', 'sun.'
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
      await _firestore.collection('chats').doc(chatId).set({
        'users': [_currentUid, widget.peerUserId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': type == 'image' ? '[photo]' : '[video]',
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
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
      // Ensure chat document exists with both users
      await _firestore.collection('chats').doc(chatId).set({
        'users': [_currentUid, widget.peerUserId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
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
      
      // Scroll to bottom after message is sent
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _chatId;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (widget.peerUserId?.isNotEmpty ?? false)
              ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.peerUserId)
                  .snapshots()
              : const Stream.empty(),
          builder: (context, snap) {
            final u = snap.data?.data();
            final name = (u?['name'] as String?) ?? (widget.initialName ?? 'User');
            final avatar = (u?['profileImageUrl'] as String?) ?? (widget.initialAvatarUrl ?? '');
            final email = (u?['email'] as String?) ?? '';
            return InkWell(
              onTap: () {
                if (u == null) return;
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty ? const Icon(Icons.person, size: 36) : null,
                          ),
                          const SizedBox(height: 12),
                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(email, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty ? const Icon(Icons.person, size: 16) : null,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.active) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final m = docs[index].data();
                          final isMine = m['senderId'] == _currentUid;
                          final text = (m['text'] as String?) ?? '';
                          final imageUrl = (m['imageUrl'] as String?) ?? '';
                          final videoUrl = (m['videoUrl'] as String?) ?? '';
                          final bubbleColor = isMine ? const Color(0xFF1877F2) : Colors.grey.shade200;
                          final textColor = isMine ? Colors.white : Colors.black;
                          final dt = (m['createdAt'] as Timestamp?)?.toDate().toLocal();
                          final prevDt = index > 0
                              ? (docs[index - 1].data()['createdAt'] as Timestamp?)?.toDate().toLocal()
                              : null;
                          final showDayHeader = dt != null && (prevDt == null ||
                              dt.year != prevDt.year || dt.month != prevDt.month || dt.day != prevDt.day);
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
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bubbleColor,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(isMine ? 14 : 6),
                                        topRight: Radius.circular(isMine ? 6 : 14),
                                        bottomLeft: const Radius.circular(14),
                                        bottomRight: const Radius.circular(14),
                                      ),
                                    ),
                                    child: Builder(builder: (context) {
                                      if (imageUrl.isNotEmpty) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(imageUrl, fit: BoxFit.cover),
                                        );
                                      }
                                      if (videoUrl.isNotEmpty) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.videocam, size: 16, color: textColor),
                                            const SizedBox(width: 4),
                                            Flexible(child: Text('[video]', style: TextStyle(color: textColor))),
                                          ],
                                        );
                                      }
                                      return Text(text, style: TextStyle(color: textColor));
                                    }),
                                  ),
                                ),
                              ],
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon group (left side)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Plus icon (blue circle with white plus)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1877F2),
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickAndSendMedia,
                              child: const Icon(Icons.add, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Camera icon
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
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1877F2), size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Gallery icon
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
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: const Icon(Icons.photo_library_outlined, color: Color(0xFF1877F2), size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Microphone icon
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
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: const Icon(Icons.mic_outlined, color: Color(0xFF1877F2), size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Text input field (light gray rounded)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                fontSize: 15,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey.shade900.withOpacity(0.5)
                                  : Colors.grey.shade200,
                              isCollapsed: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    child: const Icon(Icons.mood_outlined, color: Color(0xFF1877F2), size: 22),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Thumbs-up icon
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          _textController.text = '👍';
                          _sendMessage();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: const Icon(Icons.thumb_up, color: Color(0xFF1877F2), size: 22),
                        ),
                      ),
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


