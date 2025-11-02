import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard_page.dart';
import 'posts_page.dart';
import 'users_page.dart';
import 'settings_page.dart';
import 'admin_chats_page.dart';
import 'transactions_page.dart';
import 'create_post_page.dart';
import '../screens/profile_screen.dart';
import '../widgets/unread_messages_badge.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;
  VoidCallback? _openNewTransaction;
  
  void _setOpenNewTransactionCallback(VoidCallback callback) {
    setState(() {
      _openNewTransaction = callback;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/logo/logo2.png'
              : 'assets/logo/logo1-Photoroom.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          // Messages Icon with Unread Badge
          UnreadMessagesBadge(
            iconPath: 'assets/icons/messenger.svg',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AdminChatsPage(firestore: _firestore),
                ),
              );
            },
            iconSize: 24,
          ),
          const SizedBox(width: 4),
          // Profile Icon
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data();
              final imageUrl = (data?['profileImageUrl'] as String?) ?? '';
              return IconButton(
                tooltip: 'Profile',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          // Pages render their own Firestore instances internally where needed
          _DashboardHost(),
          _PostsHost(),
          _TransactionsHost(),
          _UsersHost(),
          _SettingsHost(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.black 
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dashboard
                _AdminNavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                // Posts
                _AdminNavItem(
                  icon: Icons.manage_search,
                  label: 'Posts',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                // Transactions
                _AdminNavItem(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                // Users with badge - only count unviewed new users
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('users')
                      .snapshots(),
                  builder: (context, snap) {
                    int newUserCount = 0;
                    if (snap.hasData && snap.data != null) {
                      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
                      newUserCount = snap.data!.docs.where((doc) {
                        try {
                          final data = doc.data();
                          final createdAt = data['createdAt'];
                          final lastViewedAt = data['lastViewedAt'];
                          
                          // Parse createdAt
                          DateTime? createdDate;
                          if (createdAt != null) {
                            if (createdAt is Timestamp) {
                              createdDate = createdAt.toDate();
                            } else if (createdAt is DateTime) {
                              createdDate = createdAt;
                            } else if (createdAt is Map && createdAt['_seconds'] != null) {
                              // Handle Firestore Timestamp map format
                              final seconds = createdAt['_seconds'] as int;
                              createdDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
                            }
                          }
                          
                          // Parse lastViewedAt
                          DateTime? viewedDate;
                          if (lastViewedAt != null) {
                            if (lastViewedAt is Timestamp) {
                              viewedDate = lastViewedAt.toDate();
                            } else if (lastViewedAt is DateTime) {
                              viewedDate = lastViewedAt;
                            } else if (lastViewedAt is Map && lastViewedAt['_seconds'] != null) {
                              // Handle Firestore Timestamp map format
                              final seconds = lastViewedAt['_seconds'] as int;
                              viewedDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
                            }
                          }
                          
                          // Count only if created in last 7 days AND not viewed yet
                          if (createdDate == null) {
                            return false; // No created date, skip
                          }
                          
                          final isNew = createdDate.isAfter(sevenDaysAgo);
                          final isUnviewed = viewedDate == null || 
                                            viewedDate.isBefore(createdDate);
                          
                          return isNew && isUnviewed;
                        } catch (e) {
                          // If there's any error parsing, skip this user
                          print('Error parsing user data for badge counter: $e');
                          return false;
                        }
                      }).length;
                    }
                    return _AdminNavItem(
                      icon: Icons.people,
                      label: 'Users',
                      isSelected: _selectedIndex == 3,
                      onTap: () => setState(() => _selectedIndex = 3),
                      badgeCount: newUserCount > 0 
                          ? (newUserCount > 99 ? '99+' : newUserCount.toString()) 
                          : null,
                    );
                  },
                ),
                // Settings
                _AdminNavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isSelected: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? Transform.scale(
              scale: 0.75,
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CreatePostPage(
                        firestore: _firestore,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.post_add, size: 20),
                label: const Text(
                  'New post',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : _selectedIndex == 2
              ? Transform.scale(
                  scale: 0.75,
                  child: FloatingActionButton.extended(
                    onPressed: _openNewTransaction ?? () {},
                    icon: const Icon(Icons.receipt_long, size: 20),
                    label: const Text(
                      'New Transaction',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : null,
    );
  }
}

class _DashboardHost extends StatelessWidget {
  const _DashboardHost();
  @override
  Widget build(BuildContext context) {
    return AdminDashboardPage(firestore: FirebaseFirestore.instance);
  }
}

class _PostsHost extends StatelessWidget {
  const _PostsHost();
  @override
  Widget build(BuildContext context) {
    return AdminPostsPage(firestore: FirebaseFirestore.instance);
  }
}

class _TransactionsHost extends StatefulWidget {
  const _TransactionsHost();
  @override
  State<_TransactionsHost> createState() => _TransactionsHostState();
}

class _TransactionsHostState extends State<_TransactionsHost> {
  VoidCallback? _openModal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final adminHomeState = context.findAncestorStateOfType<_AdminHomePageState>();
        if (adminHomeState != null && _openModal != null) {
          adminHomeState._setOpenNewTransactionCallback(_openModal!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminTransactionsPage(
      firestore: FirebaseFirestore.instance,
      onCreateTransaction: (callback) {
        _openModal = callback;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final adminHomeState = context.findAncestorStateOfType<_AdminHomePageState>();
            if (adminHomeState != null) {
              adminHomeState._setOpenNewTransactionCallback(callback);
            }
          }
        });
      },
    );
  }
}

class _UsersHost extends StatelessWidget {
  const _UsersHost();
  @override
  Widget build(BuildContext context) {
    return AdminUsersPage(firestore: FirebaseFirestore.instance);
  }
}

class _SettingsHost extends StatelessWidget {
  const _SettingsHost();
  @override
  Widget build(BuildContext context) {
    return AdminSettingsPage(firestore: FirebaseFirestore.instance);
  }
}

class _AdminNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeCount;

  const _AdminNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  @override
  State<_AdminNavItem> createState() => _AdminNavItemState();
}

class _AdminNavItemState extends State<_AdminNavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Icon(
                        widget.icon,
                        color: isDark 
                            ? (widget.isSelected ? Colors.white : Colors.white.withOpacity(0.5))
                            : (widget.isSelected ? Colors.black : Colors.black.withOpacity(0.5)),
                        size: 24,
                      ),
                    ),
                    if (widget.badgeCount != null)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            widget.badgeCount!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    color: isDark 
                        ? (widget.isSelected ? Colors.white : Colors.white.withOpacity(0.5))
                        : (widget.isSelected ? Colors.black : Colors.black.withOpacity(0.5)),
                    fontSize: 12,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

