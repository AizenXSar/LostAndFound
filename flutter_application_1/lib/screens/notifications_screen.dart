import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _hasMarkedAsRead = false;

  @override
  void initState() {
    super.initState();
    // Don't auto-mark as read immediately - let user see notifications first
    // Mark as read only when user actually views the screen for a few seconds
    _markAsReadAfterDelay();
  }

  Future<void> _markAsReadAfterDelay() async {
    // Wait 5 seconds before marking as read - gives user time to see notifications
    // This prevents the badge from disappearing too quickly
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted || _hasMarkedAsRead) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final qs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .limit(50) // Limit to prevent too many updates
          .get();
      
      if (qs.docs.isEmpty) return;
      
      final batch = FirebaseFirestore.instance.batch();
      for (final d in qs.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
      _hasMarkedAsRead = true;
      print('[NotificationsScreen] Marked ${qs.docs.length} notifications as read');
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final qs = await FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: uid)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in qs.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing notifications: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('toUserId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snap) {
              final hasNotifications = (snap.data?.docs.length ?? 0) > 0;
              if (!hasNotifications) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear All',
                onPressed: _clearAllNotifications,
              );
            },
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('toUserId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.active) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Handle errors
                if (snap.hasError) {
                  print('[NotificationsScreen] Error: ${snap.error}');
                  // If error is about missing index, show a message
                  if (snap.error.toString().contains('index')) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.build_circle_outlined, size: 64, color: Colors.blue[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Building Index...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'The Firestore index is being created. This usually takes 1-5 minutes. Please wait a moment and refresh.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Refresh by rebuilding the widget
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snap.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 0,
                    thickness: 0.5,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = (data['title'] as String?)?.trim() ?? 'Notification';
                    final body = (data['body'] as String?)?.trim() ?? '';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final relative = _formatRelative(createdAt);
                    final isUnread = (data['read'] as bool?) == false;
                    final type = data['type'] as String?;
                    
                    // Determine icon based on notification type - matching the design
                    IconData? iconData;
                    Color? iconColor;
                    if (type == 'item_found') {
                      iconData = Icons.find_in_page;
                      iconColor = Colors.green;
                    } else if (type == 'item_claimed') {
                      iconData = Icons.check_circle;
                      iconColor = Colors.blue;
                    } else if (type == 'message') {
                      iconData = Icons.message;
                      iconColor = Colors.orange; // Orange for messages as shown in design
                    } else if (type == 'match') {
                      iconData = Icons.search;
                      iconColor = Colors.purple; // Purple for match notifications as shown
                    } else {
                      iconData = Icons.notifications;
                      iconColor = Colors.blue;
                    }
                    
                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        _deleteNotification(doc.id);
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: iconColor,
                          child: Icon(
                            iconData,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 15,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (body.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white70 
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            if (relative.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  relative,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isUnread
                            ? Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Colors.grey,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteNotification(doc.id),
                                tooltip: 'Delete',
                              ),
                        onTap: () {
                          // Mark as read when tapped
                          if (isUnread) {
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(doc.id)
                                .update({'read': true});
                          }
                          // You can add navigation logic here based on notification type
                          // For example, navigate to item details, chat, etc.
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatRelative(DateTime? date) {
    if (date == null) return '';
    final d = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) {
      final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final mm = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday at $h12:$mm $ampm';
    }
    if (diff.inDays < 7) {
      final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final mm = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '${diff.inDays} days ago at $h12:$mm $ampm';
    }
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} $h12:$mm $ampm';
  }
}


