import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sweet_alert.dart';
import '../utils/app_logger.dart';

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
  
  // Track which user IDs are from the admins collection
  final Set<String> _adminCollectionIds = {};

  ValueListenable<String> get _queryListenable =>
      widget.searchQueryListenable ?? _localQuery;

  // Stream that merges users from both 'users' and 'admins' collections
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getAllUsersStream() {
    // Use simple snapshots without orderBy to include all users
    // Some users might not have createdAt field (especially older admins)
    // Remove limit to show all users
    final usersStream = widget.firestore
        .collection('users')
        .snapshots();
    
    // Use simple snapshots for admins (don't rely on createdAt field)
    final adminsStream = widget.firestore
        .collection('admins')
        .snapshots();
    
    // Combine both streams using RxDart or manual merging
    StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? controller;
    StreamSubscription? usersSub;
    StreamSubscription? adminsSub;
    
    QuerySnapshot<Map<String, dynamic>>? usersSnap;
    QuerySnapshot<Map<String, dynamic>>? adminsSnap;
    bool usersReady = false;
    bool adminsReady = false;
    
    void emitIfReady() {
      if (usersReady && adminsReady && controller != null && !controller.isClosed) {
        final usersDocs = usersSnap?.docs ?? [];
        final adminsDocs = adminsSnap?.docs ?? [];
        
        // AppLogger.debug('Merging: ${usersDocs.length} users + ${adminsDocs.length} admins');
        
        // Map to store unique users by ID - use a wrapper to preserve admin status
        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> uniqueUsers = {};
        
        // Clear and rebuild admin IDs set
        _adminCollectionIds.clear();
        
        // Create a map to store user data for easy lookup
        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> usersMap = {};
        for (var doc in usersDocs) {
          usersMap[doc.id] = doc;
        }
        
        // Add admins from admins collection
        for (var adminDoc in adminsDocs) {
          _adminCollectionIds.add(adminDoc.id);
          final userId = adminDoc.id;
          
          // If this admin also exists in users collection, prefer users collection for display
          // (users collection has name, email, profileImageUrl)
          // But keep admin doc reference for admin-specific data
          if (usersMap.containsKey(userId)) {
            // Use user document for display (has name, email, etc.)
            uniqueUsers[userId] = usersMap[userId]!;
          } else {
            // Admin not in users collection, use admin data as-is
            uniqueUsers[adminDoc.id] = adminDoc;
          }
        }
        
        // Add users from users collection - include ALL users
        for (var doc in usersDocs) {
          // Always add users - if they're also in admins collection, we already handled them above
          // But if they're not in admins collection, still show them from users collection
          if (!uniqueUsers.containsKey(doc.id)) {
            uniqueUsers[doc.id] = doc;
          }
        }
        
        final combinedList = uniqueUsers.values.toList();
        // AppLogger.debug('Combined list has ${combinedList.length} unique users');
        
        // Sort combined list by createdAt (admins without createdAt will go to end)
        combinedList.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          
          final aCreatedAt = aData['createdAt'];
          final bCreatedAt = bData['createdAt'];
          
          DateTime? aDate;
          DateTime? bDate;
          
          if (aCreatedAt is Timestamp) {
            aDate = aCreatedAt.toDate();
          } else if (aCreatedAt is DateTime) {
            aDate = aCreatedAt;
          }
          
          if (bCreatedAt is Timestamp) {
            bDate = bCreatedAt.toDate();
          } else if (bCreatedAt is DateTime) {
            bDate = bCreatedAt;
          }
          
          if (aDate != null && bDate != null) {
            return bDate.compareTo(aDate); // descending
          }
          if (aDate != null) return -1;
          if (bDate != null) return 1;
          return 0;
        });
        
        controller.add(combinedList);
      }
    }
    
    controller = StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      onCancel: () {
        usersSub?.cancel();
        adminsSub?.cancel();
      },
    );
    
    // Start listening immediately
    usersSub = usersStream.listen((snap) {
      // AppLogger.debug('Received ${snap.docs.length} users from users collection');
      usersSnap = snap;
      if (!usersReady) {
        usersReady = true;
      }
      emitIfReady();
    }, onError: (error) {
      AppLogger.error('Error loading users collection', error);
      // If users stream fails, continue with empty list for users
      usersSnap = null;
      if (!usersReady) {
        usersReady = true;
      }
      emitIfReady();
    });
    
    adminsSub = adminsStream.listen((snap) {
      // AppLogger.debug('Received ${snap.docs.length} admins from admins collection');
      adminsSnap = snap;
      if (!adminsReady) {
        adminsReady = true;
      }
      emitIfReady();
    }, onError: (error) {
      AppLogger.error('Error loading admins collection', error);
      // If admins collection doesn't exist or fails, continue without it
      adminsSnap = null;
      if (!adminsReady) {
        adminsReady = true;
      }
      emitIfReady();
    });
    
    return controller.stream;
  }

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
          child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _getAllUsersStream(),
            builder: (context, snap) {
              // Show loading only if we don't have any data yet
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              // Handle errors
              if (snap.hasError) {
                AppLogger.error('Error loading users', snap.error);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Failed to load users: ${snap.error}'),
                      ],
                    ),
                  ),
                );
              }
              
              final docs = snap.data ?? [];
              // AppLogger.debug('Loaded ${docs.length} users');
              
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
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
                  
                  // Sort: new unviewed users first, then by createdAt descending
                  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
                  filtered.sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();
                    
                    // Parse createdAt for both
                    DateTime? aCreated;
                    DateTime? bCreated;
                    final aCreatedAt = aData['createdAt'];
                    final bCreatedAt = bData['createdAt'];
                    if (aCreatedAt is Timestamp) {
                      aCreated = aCreatedAt.toDate();
                    } else if (aCreatedAt is DateTime) aCreated = aCreatedAt;
                    if (bCreatedAt is Timestamp) {
                      bCreated = bCreatedAt.toDate();
                    } else if (bCreatedAt is DateTime) bCreated = bCreatedAt;
                    
                    // Parse lastViewedAt for both
                    DateTime? aViewed;
                    DateTime? bViewed;
                    final aViewedAt = aData['lastViewedAt'];
                    final bViewedAt = bData['lastViewedAt'];
                    if (aViewedAt is Timestamp) {
                      aViewed = aViewedAt.toDate();
                    } else if (aViewedAt is DateTime) aViewed = aViewedAt;
                    if (bViewedAt is Timestamp) {
                      bViewed = bViewedAt.toDate();
                    } else if (bViewedAt is DateTime) bViewed = bViewedAt;
                    
                    // Check if new and unviewed
                    final aIsNew = aCreated != null && aCreated.isAfter(sevenDaysAgo);
                    final bIsNew = bCreated != null && bCreated.isAfter(sevenDaysAgo);
                    final aIsUnviewed = aViewed == null || (aCreated != null && aViewed.isBefore(aCreated));
                    final bIsUnviewed = bViewed == null || (bCreated != null && bViewed.isBefore(bCreated));
                    final aIsNewUser = aIsNew && aIsUnviewed;
                    final bIsNewUser = bIsNew && bIsUnviewed;
                    
                    // New unviewed users first
                    if (aIsNewUser && !bIsNewUser) return -1;
                    if (!aIsNewUser && bIsNewUser) return 1;
                    
                    // Then sort by createdAt (newest first)
                    if (aCreated != null && bCreated != null) {
                      return bCreated.compareTo(aCreated);
                    }
                    if (aCreated != null) return -1;
                    if (bCreated != null) return 1;
                    return 0;
                  });
                  
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data();
                      final id = doc.id;
                      
                      // Determine role - check if document is from admins collection first
                      // Documents from admins collection are always admins
                      // Also check if user in users collection has admin role
                      String role;
                      
                      // Check if this document ID is in the admins collection
                      if (_adminCollectionIds.contains(id)) {
                        role = 'admin';
                      } else if (data['role'] == 'admin' || data['isAdmin'] == true) {
                        role = 'admin';
                      } else {
                        role = (data['role'] as String?) ?? 'user';
                      }
                      // Get email and name - try multiple fields
                      final email = (data['email'] as String?) ?? '';
                      // Try name, fullName, or displayName
                      final name = (data['name'] as String?)?.trim() ?? 
                                   (data['fullName'] as String?)?.trim() ?? 
                                   (data['displayName'] as String?)?.trim() ?? 
                                   'Unnamed';
                      final uid = id;
                      final avatar = (data['profileImageUrl'] as String?) ?? '';
                      final theme = Theme.of(context);
                      final isDark = theme.brightness == Brightness.dark;
                      
                      // Check if user is newly registered (within 7 days and not viewed)
                      final createdAt = data['createdAt'];
                      final lastViewedAt = data['lastViewedAt'];
                      DateTime? createdDate;
                      DateTime? viewedDate;
                      
                      if (createdAt is Timestamp) {
                        createdDate = createdAt.toDate();
                      } else if (createdAt is DateTime) {
                        createdDate = createdAt;
                      }
                      
                      if (lastViewedAt is Timestamp) {
                        viewedDate = lastViewedAt.toDate();
                      } else if (lastViewedAt is DateTime) {
                        viewedDate = lastViewedAt;
                      }
                      
                      final isNew = createdDate != null && createdDate.isAfter(sevenDaysAgo);
                      final isUnviewed = viewedDate == null || 
                          (createdDate != null && viewedDate.isBefore(createdDate));
                      final isNewUser = isNew && isUnviewed;
                      
                      final borderColor = isDark 
                          ? theme.colorScheme.outline.withOpacity(0.3)
                          : Colors.grey[300]!;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isNewUser 
                              ? (isDark 
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.06))
                              : null,
                          border: Border.all(
                            color: isNewUser 
                                ? (isDark 
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.2))
                                : borderColor,
                            width: isNewUser ? 1.5 : 0.5,
                          ),
                          boxShadow: isNewUser && isDark
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            onTap: () => _showUserDetailsModal(context, id, data),
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

  Future<void> _showUserDetailsModal(BuildContext context, String userId, Map<String, dynamic> data) async {
    // Mark user as viewed when modal opens - check both collections
    final role = (data['role'] as String?) ?? '';
    final isAdmin = role.toLowerCase() == 'admin' || data['isAdmin'] == true;
    
    try {
      // If admin, try admins collection first, otherwise try users
      if (isAdmin) {
        try {
          await widget.firestore.collection('admins').doc(userId).update({
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // Fallback to users collection if admin not found in admins collection
          await widget.firestore.collection('users').doc(userId).update({
            'lastViewedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await widget.firestore.collection('users').doc(userId).update({
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Continue anyway - not critical
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        // Try name, fullName, or displayName
        final name = (data['name'] as String?)?.trim() ?? 
                     (data['fullName'] as String?)?.trim() ?? 
                     (data['displayName'] as String?)?.trim() ?? 
                     'Unnamed';
        final email = (data['email'] as String?) ?? '';
        final role = (data['role'] as String?) ?? 'user';
        final avatar = (data['profileImageUrl'] as String?) ?? '';
        final uid = userId;
        final createdAt = data['createdAt'];
        final updatedAt = data['updatedAt'];
        final isAdmin = role.toLowerCase() == 'admin';

        DateTime? createdDate;
        if (createdAt is Timestamp) {
          createdDate = createdAt.toDate();
        }

        DateTime? updatedDate;
        if (updatedAt is Timestamp) {
          updatedDate = updatedAt.toDate();
        }

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark 
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isDark
                    ? Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withOpacity(0.5)
                        : Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDark 
                                  ? theme.colorScheme.onSurface 
                                  : Colors.black87,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty 
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // User Info Section
                      _UserInfoSection(
                        title: 'User ID',
                        value: uid,
                        icon: Icons.fingerprint,
                      ),
                      const SizedBox(height: 16),
                      _UserInfoSection(
                        title: 'Role',
                        value: isAdmin ? 'Admin' : 'User',
                        icon: Icons.badge,
                        valueColor: isAdmin ? Colors.blue : Colors.grey,
                      ),
                      if (createdDate != null) ...[
                        const SizedBox(height: 16),
                        _UserInfoSection(
                          title: 'Created At',
                          value: _formatDateTime(createdDate),
                          icon: Icons.calendar_today,
                        ),
                      ],
                      if (updatedDate != null) ...[
                        const SizedBox(height: 16),
                        _UserInfoSection(
                          title: 'Last Updated',
                          value: _formatDateTime(updatedDate),
                          icon: Icons.update,
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openEditUser(context, userId, data);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                            ),
                          ),
                        ],
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

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month $day, $year at $hour:$minute';
  }

  Future<void> _openEditUser(BuildContext context, String userId, Map<String, dynamic> data) async {
    // Try name, fullName, or displayName
    final name = (data['name'] as String?)?.trim() ?? 
                 (data['fullName'] as String?)?.trim() ?? 
                 (data['displayName'] as String?)?.trim() ?? 
                 '';
    _editNameController.text = name;
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
                        
                        // Determine which collection to update based on current role
                        final currentRole = (data['role'] as String?) ?? '';
                        final currentIsAdmin = currentRole.toLowerCase() == 'admin' || data['isAdmin'] == true;
                        
                        // Always update users collection first
                        await widget.firestore.collection('users').doc(userId).update(payload);
                        
                        // If role is admin (new or existing), ensure it exists in admins collection
                        if (role == 'admin') {
                          try {
                            // Get existing data from users to preserve all fields
                            final userDoc = await widget.firestore.collection('users').doc(userId).get();
                            final userData = userDoc.data() ?? {};
                            
                            // Merge user data with admin-specific fields
                            final adminPayload = {
                              ...userData,
                              'role': 'admin',
                              'isAdmin': true,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            
                            // Create or update in admins collection
                            await widget.firestore.collection('admins').doc(userId).set(
                              adminPayload,
                              SetOptions(merge: true),
                            );
                          } catch (e) {
                            // Continue anyway - user is still updated in users collection
                          }
                        } else if (role == 'user' && currentIsAdmin) {
                          // If changing from admin to user, remove from admins collection
                          try {
                            await widget.firestore.collection('admins').doc(userId).delete();
                          } catch (e) {
                            // Continue anyway
                          }
                        }
                        
                        bool updated = true;
                        
                        if (updated && ctx.mounted) Navigator.pop(ctx);
                        if (updated && context.mounted) {
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

class _UserInfoSection extends StatelessWidget {
  const _UserInfoSection({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
