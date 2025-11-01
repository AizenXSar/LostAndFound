import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/messages_screen.dart';

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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final data = sorted[index].data();
                final users = (data['users'] as List?)?.cast<String>() ?? [];
                final peerId = users.firstWhere((u) => u != widget.uid, orElse: () => '');
                final last = (data['lastMessage'] as String?)?.trim() ?? '';
                final ts = (data['updatedAt'] as Timestamp?);
                final timeStr = ts == null
                    ? ''
                    : TimeOfDay.fromDateTime(ts.toDate().toLocal()).format(context);

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: widget.firestore.collection('users').doc(peerId).snapshots(),
                  builder: (context, userSnap) {
                    final u = userSnap.data?.data() ?? const {};
                    final rawName = (u['name'] as String?)?.trim() ?? '';
                    final name = rawName.isNotEmpty ? rawName : ((u['fullName'] as String?)?.trim() ?? 'User');
                    final avatar = (u['profileImageUrl'] as String?)?.trim() ?? '';
                    if (query.isNotEmpty && !name.toLowerCase().contains(query)) {
                      return const SizedBox.shrink();
                    }
                    if (peerId.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        last.isNotEmpty ? last : 'Say hi 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
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
            ),
          ),
      ],
    );
  }
}

