import 'package:flutter/material.dart';
import '../widgets/full_screen_image_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/messages_screen.dart';
import 'profile_avatar.dart';
// messages icon removed from PostCard

class PostCard extends StatelessWidget {
  final String id;
  final String imageUrl;
  final String title; // fallback author name
  final String description;
  final String subtitle; // e.g., suggested for you or status
  final String timeAgo;
  final String avatarUrl;
  final String postedByUserId;
  final String itemTitle; // original item title

  const PostCard({
    super.key,
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.timeAgo,
    required this.avatarUrl,
    required this.postedByUserId,
    required this.itemTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: (title.isNotEmpty || avatarUrl.isNotEmpty || postedByUserId.isEmpty)
              ? _buildImmediateUserRow(context)
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(postedByUserId)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _buildFallbackUserRow(context, 'Loading...');
                    }
                    if (snap.hasError) {
                      return _buildFallbackUserRow(context, title);
                    }
                    final exists = snap.data?.exists ?? false;
                    if (!exists) {
                      return _buildFallbackUserRow(context, title);
                    }
                    final userData = snap.data!.data() ?? {};
                    final rawName = (userData['name'] as String?)?.trim() ?? '';
                    final displayName = rawName.isNotEmpty
                        ? rawName
                        : ((userData['fullName'] as String?)?.trim() ?? '');
                    final avatar = ((userData['profileImageUrl'] as String?) ?? '').trim();
                    
                    return Row(
                      children: [
                        ProfileAvatar(
                          radius: 18,
                          imageUrl: avatar.isNotEmpty ? avatar : null,
                          displayName: displayName.isNotEmpty ? displayName : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isNotEmpty ? displayName : 'User',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color?.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                  IconButton(
                    onPressed: () {
                      if (postedByUserId.isEmpty) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MessagesScreen(
                            peerUserId: postedByUserId,
                          ),
                        ),
                      );
                    },
                    icon: SvgPicture.asset(
                      'assets/icons/messenger.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).iconTheme.color ?? Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty)
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '$itemTitle ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: description),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FullScreenImageView(imageUrl: imageUrl, tag: 'image_${id}_${imageUrl.hashCode}'),
              ),
            );
          },
          child: Hero(
            tag: 'image_${id}_${imageUrl.hashCode}',
            child: Image.network(
              imageUrl,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 220,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.06),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.06),
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: _LikeBar(itemId: id, postedByUserId: postedByUserId),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFallbackUserRow(BuildContext context, String fallbackName) {
    return Row(
      children: [
        ProfileAvatar(
          radius: 18,
          displayName: null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fallbackName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            if (postedByUserId.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessagesScreen(
                  peerUserId: postedByUserId,
                  initialName: title.trim().isNotEmpty ? title.trim() : null,
                  initialAvatarUrl: avatarUrl.trim().isNotEmpty ? avatarUrl.trim() : null,
                ),
              ),
            );
          },
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }

  Widget _buildImmediateUserRow(BuildContext context) {
    final displayName = title.trim();
    final avatar = avatarUrl.trim();
    return Row(
      children: [
        ProfileAvatar(
          radius: 18,
          imageUrl: avatar.isNotEmpty ? avatar : null,
          displayName: displayName.isNotEmpty ? displayName : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isNotEmpty ? displayName : 'User',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            if (postedByUserId.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessagesScreen(
                  peerUserId: postedByUserId,
                  initialName: displayName.isNotEmpty ? displayName : null,
                  initialAvatarUrl: avatar.isNotEmpty ? avatar : null,
                ),
              ),
            );
          },
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }
}

String _formatCommentCount(int count) {
  return (count < 0 ? 0 : count).toString();
}

void _showCommentsSheet(BuildContext context, String itemId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _CommentsSheet(itemId: itemId),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.itemId});
  final String itemId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  ScrollController? _listScrollController;

  @override
  void dispose() {
    _commentController.dispose();
    // Don't dispose _listScrollController as it's managed by DraggableScrollableSheet
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    final itemRef = FirebaseFirestore.instance.collection('items').doc(widget.itemId);
    try {
      // Get user info for denormalization
      String authorName = 'User';
      String authorAvatar = '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final u = userDoc.data() ?? <String, dynamic>{};
        final name = (u['name'] as String?)?.trim() ?? '';
        authorName = name.isNotEmpty ? name : ((u['fullName'] as String?)?.trim() ?? 'User');
        authorAvatar = ((u['profileImageUrl'] as String?) ?? '').trim();
      } catch (_) {}

      // Add comment to subcollection with initial like data
      await itemRef.collection('comments').add({
        'text': text,
        'authorId': uid,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        // Initialize like fields for comments (heart react)
        'likedBy': <String>[],
        'likeCount': 0,
      });

      // Increment comment count
      // FieldValue.increment works even if the field doesn't exist (initializes to the increment value)
      try {
        await itemRef.update({'commentCount': FieldValue.increment(1)});
      } catch (updateError) {
        // If increment fails, try to get current count and set it directly
        print('Error updating comment count: $updateError');
        try {
          final currentDoc = await itemRef.get();
          final currentData = currentDoc.data() ?? {};
          final currentCount = (currentData['commentCount'] as int?) ?? 0;
          // Set the new count directly
          await itemRef.update({'commentCount': currentCount + 1});
          print('Comment count updated to ${currentCount + 1}');
        } catch (fallbackError) {
          print('Failed to update comment count: $fallbackError');
          // Show error to user so they know something went wrong
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Comment added but count may not update. Error: $fallbackError'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      _commentController.clear();
      // Scroll to bottom after a delay to allow comment to appear
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _listScrollController != null && _listScrollController!.hasClients) {
        _listScrollController!.animateTo(
          _listScrollController!.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
      print('Error adding comment: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final itemRef = FirebaseFirestore.instance.collection('items').doc(widget.itemId);
    try {
      // Delete the comment
      await itemRef.collection('comments').doc(commentId).delete();

      // Decrement comment count (but never go below 0)
      try {
        // Get current count first to ensure we don't go negative
        final currentDoc = await itemRef.get();
        final currentCount = (currentDoc.data()?['commentCount'] as int?) ?? 0;
        
        // Only decrement if count is greater than 0, otherwise set to 0
        if (currentCount > 0) {
          await itemRef.update({'commentCount': FieldValue.increment(-1)});
        } else {
          // Ensure it's 0 if it's already 0 or negative
          await itemRef.update({'commentCount': 0});
        }
      } catch (updateError) {
        // If comment count update fails, try to set it directly
        print('Warning: Failed to update comment count: $updateError');
        try {
          final currentDoc = await itemRef.get();
          final currentCount = (currentDoc.data()?['commentCount'] as int?) ?? 0;
          // Ensure count never goes below 0
          final newCount = currentCount > 0 ? currentCount - 1 : 0;
          await itemRef.update({'commentCount': newCount});
        } catch (_) {
          print('Warning: Failed to set comment count directly');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
      print('Error deleting comment: $e');
    }
  }

  void _showDeleteCommentDialog(String commentId, String commentText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: Text(
          'Are you sure you want to delete this comment?\n\n"${commentText.length > 50 ? "${commentText.substring(0, 50)}..." : commentText}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteComment(commentId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('items')
                    .doc(widget.itemId)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.active) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No comments yet. Be the first to comment!'),
                      ),
                    );
                  }
                  _listScrollController ??= scrollController;
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final commentDoc = docs[index];
                      final commentId = commentDoc.id;
                      final data = commentDoc.data();
                      final text = (data['text'] as String?) ?? '';
                      final authorName = (data['authorName'] as String?) ?? 'User';
                      final authorAvatar = (data['authorAvatar'] as String?) ?? '';
                      final authorId = (data['authorId'] as String?) ?? '';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final currentUserId = AuthService.currentUser?.uid;
                      final canDelete = currentUserId != null && currentUserId == authorId;
                      
                      return GestureDetector(
                        onLongPress: canDelete
                            ? () {
                                final state = context.findAncestorStateOfType<_CommentsSheetState>();
                                if (state != null) {
                                  state._showDeleteCommentDialog(commentId, text);
                                }
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProfileAvatar(
                                radius: 18,
                                imageUrl: authorAvatar.isNotEmpty ? authorAvatar : null,
                                displayName: null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(text, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(height: 4),
                                    // Like button and count for comments
                                    Row(
                                      children: [
                                        if (createdAt != null)
                                          Text(
                                            _formatTimeAgo(createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        _CommentLikeButton(
                                          itemId: widget.itemId,
                                          commentId: commentId,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Show delete icon if user can delete
                              if (canDelete)
                                Builder(
                                  builder: (builderContext) {
                                    return IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      color: Colors.red.withOpacity(0.7),
                                      onPressed: () {
                                        final state = builderContext.findAncestorStateOfType<_CommentsSheetState>();
                                        if (state != null) {
                                          state._showDeleteCommentDialog(commentId, text);
                                        }
                                      },
                                      tooltip: 'Delete comment',
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (uid != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  8 + MediaQuery.of(context).viewInsets.bottom,
                ),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
  }
}

class _SavedButton extends StatelessWidget {
  const _SavedButton({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      return const Icon(Icons.bookmark_border, size: 26);
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final savedPosts = (data?['savedPosts'] as List?)?.cast<String>() ?? const <String>[];
        final isSaved = savedPosts.contains(itemId);
        
        return IconButton(
          icon: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 26,
            color: isSaved ? Colors.blue : null,
          ),
          onPressed: () async {
            try {
              if (isSaved) {
                await userRef.update({
                  'savedPosts': FieldValue.arrayRemove([itemId]),
                });
              } else {
                await userRef.update({
                  'savedPosts': FieldValue.arrayUnion([itemId]),
                });
              }
            } catch (_) {}
          },
        );
      },
    );
  }
}

class _CommentLikeButton extends StatelessWidget {
  const _CommentLikeButton({
    required this.itemId,
    required this.commentId,
  });
  final String itemId;
  final String commentId;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    final commentRef = FirebaseFirestore.instance
        .collection('items')
        .doc(itemId)
        .collection('comments')
        .doc(commentId);
    
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: commentRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final likedBy = (data['likedBy'] as List?)?.cast<String>() ?? const <String>[];
        final isLiked = uid != null && likedBy.contains(uid);
        // Use stored likeCount if available, otherwise use likedBy array length
        final storedLikeCount = (data['likeCount'] as int?);
        final likeCount = storedLikeCount ?? likedBy.length;
        
        return InkWell(
          onTap: uid == null
              ? null
              : () async {
                  try {
                    if (isLiked) {
                      // Remove from likedBy array and decrement count
                      await commentRef.update({
                        'likedBy': FieldValue.arrayRemove([uid]),
                        'likeCount': FieldValue.increment(-1),
                      });
                    } else {
                      // Add to likedBy array and increment count
                      await commentRef.update({
                        'likedBy': FieldValue.arrayUnion([uid]),
                        'likeCount': FieldValue.increment(1),
                      });
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to like comment: $e')),
                      );
                    }
                  }
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: isLiked ? Colors.red : Theme.of(context).iconTheme.color,
              ),
              const SizedBox(width: 4),
              Text(
                likeCount.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LikeBar extends StatelessWidget {
  const _LikeBar({required this.itemId, required this.postedByUserId});
  final String itemId;
  final String postedByUserId;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    final docRef = FirebaseFirestore.instance.collection('items').doc(itemId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final likedBy = (data?['likedBy'] as List?)?.cast<String>() ?? const <String>[];
        final isLiked = uid != null && likedBy.contains(uid);
        // Use stored likeCount if available, otherwise use likedBy array length
        final storedLikeCount = (data?['likeCount'] as int?);
        final likeCount = storedLikeCount ?? likedBy.length;
        return Row(
          children: [
            IconButton(
              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 26, color: isLiked ? Colors.red : null),
              onPressed: uid == null
                  ? null
                  : () async {
                      try {
                        if (isLiked) {
                          // Remove from likedBy array and decrement count
                          await docRef.update({
                            'likedBy': FieldValue.arrayRemove([uid]),
                            'likeCount': FieldValue.increment(-1),
                          });
                        } else {
                          // Add to likedBy array and increment count
                          await docRef.update({
                            'likedBy': FieldValue.arrayUnion([uid]),
                            'likeCount': FieldValue.increment(1),
                          });
                        }
                      } catch (_) {}
                    },
            ),
            Text(((data?['likeCount'] as int?) ?? likeCount).toString()),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 26),
              onPressed: () => _showCommentsSheet(context, itemId),
            ),
            Text(_formatCommentCount((data?['commentCount'] as int?) ?? 0)),
            // Messenger icon removed per request
            const Spacer(),
            _SavedButton(itemId: itemId),
          ],
        );
      },
    );
  }
}
