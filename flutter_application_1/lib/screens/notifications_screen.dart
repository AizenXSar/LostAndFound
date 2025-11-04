import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllReadSoon();
  }

  Future<void> _markAllReadSoon() async {
    // Mark as read after first frame to ensure page renders quickly
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      try {
        final qs = await FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: uid)
            .where('read', isEqualTo: false)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in qs.docs) {
          batch.update(d.reference, {'read': true});
        }
        await batch.commit();
      } catch (_) {}
    });
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
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No notifications'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final title = (data['title'] as String?)?.trim() ?? 'Notification';
                    final body = (data['body'] as String?)?.trim() ?? '';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final relative = _formatRelative(createdAt);
                    final isUnread = (data['read'] as bool?) == false;
                    return ListTile(
                      title: Text(title, style: TextStyle(fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (body.isNotEmpty) Text(body),
                          if (relative.isNotEmpty)
                            Text(relative, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        ],
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


