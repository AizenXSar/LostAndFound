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
                .limit(500) // Limit for better performance
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.active) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No posts yet'));
              }
              // Filter out claimed items - they should only appear in transactions history
              final unclaimedDocs = docs.where((d) {
                final status = (d.data()['status'] as String?) ?? '';
                return status != 'claimed';
              }).toList();
              
              if (unclaimedDocs.isEmpty) {
                return const Center(child: Text('No posts yet'));
              }
              
              return ValueListenableBuilder<String>(
                valueListenable: _queryListenable,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? unclaimedDocs
                      : unclaimedDocs.where((d) {
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
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index].data();
                      final id = filtered[index].id;
                      final postedBy = (data['postedBy'] as String?) ?? '';
                      final title = (data['title'] as String?) ?? 'Untitled';
                      final status = (data['status'] as String?) ?? 'unclaimed';
                      final imageUrl = (data['imageUrl'] as String?) ?? '';
                      final location = (data['location'] as String?) ?? '';
                      final theme = Theme.of(context);
                      final isDark = theme.brightness == Brightness.dark;
                      final borderColor = isDark 
                          ? theme.colorScheme.outline.withOpacity(0.3)
                          : Colors.grey[300]!;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: borderColor,
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => _PostDetailsPage(
                                    postId: id,
                                    firestore: widget.firestore,
                                  ),
                                ),
                              );
                            },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  cacheWidth: 112, // 2x for retina
                                  cacheHeight: 112,
                                  loadingBuilder: (context, child, progress) => progress == null
                                      ? child
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 56,
                                    height: 56,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.image, size: 20),
                                  ),
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
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  await widget.firestore
                                      .collection('items')
                                      .doc(id)
                                      .update({'status': 'archived'});
                                  if (context.mounted) {
                                    await SweetAlert.success(
                                      context: context,
                                      title: 'Archived',
                                      message: 'Post has been archived.',
                                    );
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
                              icon: const Icon(Icons.archive, size: 18),
                              label: const Text('Archive'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
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

class _PostDetailsPage extends StatelessWidget {
  const _PostDetailsPage({
    required this.postId,
    required this.firestore,
  });
  final String postId;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('items').doc(postId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snap.hasData || !(snap.data?.exists ?? false)) {
            return const Center(child: Text('Post not found'));
          }
          
          final data = snap.data!.data() ?? {};
          final title = (data['title'] as String?) ?? 'Untitled';
          final description = (data['description'] as String?) ?? '';
          final location = (data['location'] as String?) ?? '';
          final imageUrl = (data['imageUrl'] as String?) ?? '';
          final postedBy = (data['postedBy'] as String?) ?? '';
          final status = (data['status'] as String?) ?? 'unclaimed';
          final createdAt = data['createdAt'] as Timestamp?;
          
          DateTime? createdDate;
          if (createdAt != null) {
            createdDate = createdAt.toDate();
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 800, // Limit cache size for better performance
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Item Title
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                ],
                // Location & Date
                if (location.isNotEmpty || createdDate != null) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (location.isNotEmpty)
                        _PostInfoChip(
                          icon: Icons.location_on_outlined,
                          label: location,
                        ),
                      if (createdDate != null)
                        _PostInfoChip(
                          icon: Icons.access_time_outlined,
                          label: _formatShortDate(createdDate),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                // Posted By
                _PostSectionHeader(title: 'Posted By'),
                const SizedBox(height: 8),
                if (postedBy.isNotEmpty)
                  _PostAuthorFull(uid: postedBy)
                else
                  Text(
                    'Unknown',
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 24),
                // Status
                _PostSectionHeader(title: 'Status'),
                const SizedBox(height: 8),
                _StatusChip(status: status),
                const SizedBox(height: 24),
                // Actions
                _PostSectionHeader(title: 'Actions'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final newStatus = status == 'claimed' ? 'unclaimed' : 'claimed';
                            await firestore
                                .collection('items')
                                .doc(postId)
                                .update({'status': newStatus});
                            if (context.mounted) {
                              SweetAlert.success(
                                context: context,
                                title: 'Status Updated',
                                message: 'Post marked as $newStatus.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SweetAlert.error(
                                context: context,
                                title: 'Error',
                                message: e.toString(),
                              );
                            }
                          }
                        },
                        icon: Icon(status == 'claimed' ? Icons.undo : Icons.check),
                        label: Text(status == 'claimed' ? 'Mark Unclaimed' : 'Mark Claimed'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await firestore.collection('items').doc(postId).delete();
                            if (context.mounted) {
                              Navigator.pop(context);
                              SweetAlert.success(
                                context: context,
                                title: 'Deleted',
                                message: 'Post has been removed.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SweetAlert.error(
                                context: context,
                                title: 'Error',
                                message: e.toString(),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  String _formatShortDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    return '$month $day, $year';
  }
}

class _PostSectionHeader extends StatelessWidget {
  const _PostSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _PostInfoChip extends StatelessWidget {
  const _PostInfoChip({
    required this.icon,
    required this.label,
  });
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAuthorFull extends StatelessWidget {
  const _PostAuthorFull({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return Text(
            'Unknown',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        final userData = snap.data!.data() ?? {};
        final rawName = (userData['name'] as String?)?.trim() ?? '';
        final name = rawName.isNotEmpty 
            ? rawName 
            : ((userData['fullName'] as String?)?.trim() ?? 'Unknown');
        final email = (userData['email'] as String?)?.trim() ?? '';
        final imageUrl = (userData['profileImageUrl'] as String?)?.trim() ?? '';
        
        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
