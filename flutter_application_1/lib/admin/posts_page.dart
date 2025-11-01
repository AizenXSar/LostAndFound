import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sweet_alert.dart';

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({
    super.key,
    required this.firestore,
    this.searchQueryListenable,
  });
  final FirebaseFirestore firestore;
  final ValueListenable<String>? searchQueryListenable;

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

class _AdminPostsPageState extends State<AdminPostsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _localQuery = ValueNotifier<String>('');

  ValueListenable<String> get _queryListenable =>
      widget.searchQueryListenable ?? _localQuery;

  @override
  void dispose() {
    _searchController.dispose();
    _localQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildSearchBar(context),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.firestore
                .collection('items')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.active) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No posts yet'));
              }
              return ValueListenableBuilder<String>(
                valueListenable: _queryListenable,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? docs
                      : docs.where((d) {
                          final data = d.data();
                          final title =
                              (data['title'] as String?)?.toLowerCase() ?? '';
                          final desc =
                              (data['description'] as String?)?.toLowerCase() ??
                              '';
                          final loc =
                              (data['location'] as String?)?.toLowerCase() ??
                              '';
                          return title.contains(q) ||
                              desc.contains(q) ||
                              loc.contains(q);
                        }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No matches'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final data = filtered[index].data();
                      final id = filtered[index].id;
                      final postedBy = (data['postedBy'] as String?) ?? '';
                      final title = (data['title'] as String?) ?? 'Untitled';
                      final status = (data['status'] as String?) ?? 'unclaimed';
                      final imageUrl = (data['imageUrl'] as String?) ?? '';
                      final location = (data['location'] as String?) ?? '';
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image, size: 20),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: postedBy.isNotEmpty
                                  ? _PostAuthor(uid: postedBy)
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (location.isNotEmpty)
                              Text(
                                location,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusChip(status: status),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                            try {
                              if (value == 'claimed' || value == 'unclaimed') {
                                await widget.firestore
                                    .collection('items')
                                    .doc(id)
                                    .update({'status': value});
                                if (context.mounted) {
                                  await SweetAlert.success(
                                    context: context,
                                    title: 'Status updated',
                                    message: 'Post marked as $value.',
                                  );
                                }
                              } else if (value == 'delete') {
                                await widget.firestore
                                    .collection('items')
                                    .doc(id)
                                    .delete();
                                if (context.mounted) {
                                  await SweetAlert.success(
                                    context: context,
                                    title: 'Deleted',
                                    message: 'Post has been removed.',
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                await SweetAlert.error(
                                  context: context,
                                  title: 'Action failed',
                                  message: e.toString(),
                                );
                              }
                            }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'claimed',
                                  child: Text('Mark as Claimed'),
                                ),
                                PopupMenuItem(
                                  value: 'unclaimed',
                                  child: Text('Mark as Unclaimed'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: filtered.length,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final hint = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.45);
    final iconColor = isDark ? Colors.white : Colors.black;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) {
            if (widget.searchQueryListenable is ValueNotifier<String>) {
              (widget.searchQueryListenable as ValueNotifier<String>).value = v
                  .trim()
                  .toLowerCase();
            } else {
              _localQuery.value = v.trim().toLowerCase();
            }
          },
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
    );
  }
}

class _PostAuthor extends StatelessWidget {
  const _PostAuthor({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.active) {
          return const SizedBox.shrink();
        }
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() ?? <String, dynamic>{};
        final rawName = (data['name'] as String?)?.trim() ?? '';
        final name = rawName.isNotEmpty ? rawName : (data['fullName'] as String?)?.trim() ?? '';
        final imageUrl = (data['profileImageUrl'] as String?)?.trim() ?? '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            ),
            if (name.isNotEmpty)
              Flexible(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isClaimed = status.toLowerCase() == 'claimed';
    final color = isClaimed ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
