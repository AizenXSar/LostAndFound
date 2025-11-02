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
          'assets/logo/logo1-Photoroom.png',
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search),
            label: 'Posts',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CreatePostPage(
                      firestore: _firestore,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.post_add),
              label: const Text('New post'),
            )
          : _selectedIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: _openNewTransaction ?? () {},
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('New Transaction'),
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

