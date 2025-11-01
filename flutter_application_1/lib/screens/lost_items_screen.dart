import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'chats_screen.dart';
import '../widgets/post_card.dart';

class LostItemsScreen extends StatefulWidget {
  const LostItemsScreen({super.key});

  @override
  State<LostItemsScreen> createState() => _LostItemsScreenState();
}

class _LostItemsScreenState extends State<LostItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore
      .instance
      .collection('items')
      .where('type', isEqualTo: 'lost')
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final hint = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.45);
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: iconColor),
                hintText: 'Search lost items…',
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
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatsScreen()),
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
          final filtered = docs.where((d) {
            final title = (d.data()['title'] as String?) ?? '';
            return title.toLowerCase().contains(_query.toLowerCase());
          }).toList();
          // Sort by createdAt desc if present
          filtered.sort((a, b) {
            final av = (a.data()['createdAt'] as dynamic)?.seconds as int? ?? 0;
            final bv = (b.data()['createdAt'] as dynamic)?.seconds as int? ?? 0;
            return bv.compareTo(av);
          });
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final data = filtered[index].data();
              final title = (data['title'] as String?) ?? '';
              final imageUrl = (data['imageUrl'] as String?) ?? '';
              final description = (data['description'] as String?) ?? '';
              final location = (data['location'] as String?) ?? '';
              final status = (data['status'] as String?) ?? '';
              final rawDate = data['date'];
              final String dateStr = _formatDate(rawDate);
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

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  DateTime? dt;
  try {
    if (raw is DateTime) dt = raw;
    final seconds = (raw as dynamic).seconds as int?;
    if (dt == null && seconds != null) {
      dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (dt == null && raw is String) dt = DateTime.tryParse(raw);
  } catch (_) {}
  if (dt == null) return '';
  dt = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final hasTime = !(dt.hour == 0 && dt.minute == 0 && dt.second == 0);
  if (!hasTime) {
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(hour12)}:${two(dt.minute)}$ampm';
}

void _openItemDialog(
  BuildContext context, {
  required String title,
  required String imageUrl,
  String? description,
  String? location,
  String? status,
  String? date,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Item',
    barrierColor: Colors.black54,
    pageBuilder: (context, _, __) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6 * anim.value,
          sigmaY: 6 * anim.value,
        ),
        child: Opacity(
          opacity: anim.value,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(imageUrl, fit: BoxFit.contain),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((description ?? '').isNotEmpty)
                            Text(description!),
                          if ((location ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Location: $location'),
                            ),
                          if ((status ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Status: $status'),
                            ),
                          if ((date ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Date: $date'),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
