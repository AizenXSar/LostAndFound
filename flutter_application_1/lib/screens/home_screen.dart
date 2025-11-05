import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chats_screen.dart';
import '../widgets/notifications_icon_button.dart';
import '../widgets/post_card.dart';
import '../widgets/unread_messages_badge.dart';
// Home screen; bottom nav is handled by MainNav

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance.collection('items').snapshots();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final bg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final hint = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.45);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: _isSearching
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/logo/logo2.png'
                        : 'assets/logo/logo1-Photoroom.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
        leadingWidth: _isSearching ? 56 : 140,
        title: _isSearching
            ? ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                      color: iconColor,
                      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: iconColor),
                      hintText: 'Search items…',
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
              )
            : null,
        centerTitle: false,
        actions: [
          _isSearching
              ? IconButton(
                  tooltip: 'Close search',
                  onPressed: () {
                    setState(() => _isSearching = false);
                  },
                  icon: Icon(Icons.close, color: iconColor),
                )
              : IconButton(
                  tooltip: 'Search',
                  onPressed: () {
                    setState(() => _isSearching = true);
                  },
                  icon: Icon(Icons.search, color: iconColor),
                ),
          // Notifications icon with unread badge
          const NotificationsIconButton(),
          UnreadMessagesBadge(
            iconPath: 'assets/icons/messenger.svg',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatsScreen()),
              );
            },
            iconSize: 24,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          // Filter out claimed items - they should only appear in transactions history
          final unclaimedDocs = docs.where((d) {
            final status = (d.data()['status'] as String?) ?? '';
            return status != 'claimed';
          }).toList();
          
          final filtered = unclaimedDocs.where((d) {
            if (_query.isEmpty) return true;
            final data = d.data();
            final queryLower = _query.toLowerCase();
            final title = (data['title'] as String?) ?? '';
            final authorName = (data['authorName'] as String?) ?? '';
            final description = (data['description'] as String?) ?? '';
            final location = (data['location'] as String?) ?? '';
            return title.toLowerCase().contains(queryLower) ||
                   authorName.toLowerCase().contains(queryLower) ||
                   description.toLowerCase().contains(queryLower) ||
                   location.toLowerCase().contains(queryLower);
          }).toList();
          filtered.sort((a, b) {
            final av = (a.data()['createdAt'] as dynamic)?.seconds as int? ?? 0;
            final bv = (b.data()['createdAt'] as dynamic)?.seconds as int? ?? 0;
            return bv.compareTo(av);
          });
          if (filtered.isEmpty) {
            return const Center(child: Text('No items match your search'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final data = filtered[index].data();
              final title = (data['title'] as String?) ?? '';
              final imageUrl = (data['imageUrl'] as String?) ?? '';
              final description = (data['description'] as String?) ?? '';
              final status = (data['status'] as String?) ?? '';
              final rawDate = data['createdAt'] ?? data['date'];
              final String dateStr = _formatRelativeDate(rawDate);
              return PostCard(
                id: filtered[index].id,
                imageUrl: imageUrl,
                title: (data['authorName'] as String?) ?? '',
                description: description,
                subtitle: status.isEmpty
                    ? 'Suggested for you'
                    : 'Status: $status',
                timeAgo: dateStr,
                avatarUrl: (data['authorAvatar'] as String?) ?? '',
                postedByUserId: (data['postedBy'] as String?) ?? '',
                itemTitle: title,
              );
            },
          );
        },
      ),
    );
  }
}

// NotificationsIconButton moved to widgets/notifications_icon_button.dart

String _formatRelativeDate(dynamic raw) {
  if (raw == null) return '';
  DateTime? dt;
  try {
    if (raw is DateTime) dt = raw;
    if (dt == null && raw is Timestamp) dt = raw.toDate();
    if (dt == null && raw is String) dt = DateTime.tryParse(raw);
  } catch (_) {}
  if (dt == null) return '';
  final d = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(d);
  String hmm(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h12:$mm $ampm';
  }
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday at ${hmm(d)}';
  if (diff.inDays < 7) return '${diff.inDays} days ago at ${hmm(d)}';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (diff.inDays / 365).floor();
  return '${years}y ago';
}

// removed unused _openItemDialog

