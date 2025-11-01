import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sweet_alert.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.firestore,
    this.searchQueryListenable,
  });
  final FirebaseFirestore firestore;
  final ValueListenable<String>? searchQueryListenable;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _localQuery = ValueNotifier<String>('');
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editAvatarController = TextEditingController();

  ValueListenable<String> get _queryListenable =>
      widget.searchQueryListenable ?? _localQuery;

  @override
  void dispose() {
    _searchController.dispose();
    _localQuery.dispose();
    _editNameController.dispose();
    _editAvatarController.dispose();
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
                .collection('users')
                .orderBy('name', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.active) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load users: ${snap.error}'),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No users yet'));
              }
              return ValueListenableBuilder<String>(
                valueListenable: _queryListenable,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? docs
                      : docs.where((d) {
                          final data = d.data();
                          final name =
                              (data['name'] as String?)?.toLowerCase() ?? '';
                          final email =
                              (data['email'] as String?)?.toLowerCase() ?? '';
                          return name.contains(q) || email.contains(q);
                        }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No matches'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final data = filtered[index].data();
                      final id = filtered[index].id;
                      final role = (data['role'] as String?) ?? 'user';
                      final email = (data['email'] as String?) ?? '';
                      final name = (data['name'] as String?) ?? 'Unnamed';
                      final uid = id;
                      final avatar = (data['profileImageUrl'] as String?) ?? '';
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              uid,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoleChip(role: role),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Edit user',
                              iconSize: 18,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openEditUser(context, id, data),
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

  Future<void> _openEditUser(BuildContext context, String userId, Map<String, dynamic> data) async {
    _editNameController.text = (data['name'] as String?) ?? '';
    _editAvatarController.text = (data['profileImageUrl'] as String?) ?? '';
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        String role = (data['role'] as String?) ?? 'user';
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.person, size: 18),
                  SizedBox(width: 8),
                  Text('Edit User', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editAvatarController,
                readOnly: true,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  labelText: 'Profile image URL',
                  prefixIcon: Icon(Icons.link),
                  suffixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Role', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: role,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                      dropdownColor: Theme.of(ctx).colorScheme.surface,
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          role = v;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        final payload = <String, dynamic>{
                          'name': _editNameController.text.trim(),
                          'role': role,
                          'isAdmin': role == 'admin',
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        final avatar = _editAvatarController.text.trim();
                        if (avatar.isNotEmpty) payload['profileImageUrl'] = avatar;
                        await widget.firestore.collection('users').doc(userId).update(payload);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          await SweetAlert.success(
                            context: context,
                            title: 'Saved',
                            message: 'User details updated successfully.',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          await SweetAlert.error(
                            context: context,
                            title: 'Update failed',
                            message: e.toString(),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase() == 'admin';
    final color = isAdmin ? Colors.blue : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      ),
    );
  }
}
