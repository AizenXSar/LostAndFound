import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'lost_items_screen.dart';
import 'found_items_screen.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    LostItemsScreen(),
    FoundItemsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
                // Home
                _NavItem(
                  icon: Icons.home_outlined,
                  filledIcon: Icons.home,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                // Lost (Shop equivalent)
                // Lost with new items badge
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data();
                    final lastViewed = (userData?['lastViewedLostItems'] as Timestamp?);
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('items')
                          .where('type', isEqualTo: 'lost')
                          .snapshots(),
                      builder: (context, itemsSnap) {
                        int newCount = 0;
                        if (itemsSnap.hasData) {
                          final docs = itemsSnap.data!.docs;
                          final lv = lastViewed?.toDate();
                          if (lv == null) {
                            // First time: do not show a total badge
                            newCount = 0;
                          } else {
                            for (final d in docs) {
                              final data = d.data();
                              if ((data['status'] as String?) == 'claimed') continue;
                              final ts = data['createdAt'];
                              DateTime? dt;
                              if (ts is Timestamp) dt = ts.toDate();
                              if (dt != null && dt.isAfter(lv)) newCount++;
                            }
                          }
                        }
                        return _NavItem(
                          icon: Icons.search,
                          filledIcon: Icons.search,
                          label: 'Lost',
                          isSelected: _currentIndex == 1,
                          onTap: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .set({'lastViewedLostItems': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                              } catch (_) {}
                            }
                            setState(() => _currentIndex = 1);
                          },
                          badgeCount: newCount > 0 ? (newCount > 99 ? '99+' : newCount.toString()) : null,
                        );
                      },
                    );
                  },
                ),
                // Found with new items badge
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data();
                    final lastViewed = (userData?['lastViewedFoundItems'] as Timestamp?);
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('items')
                          .where('type', isEqualTo: 'found')
                          .snapshots(),
                      builder: (context, itemsSnap) {
                        int newCount = 0;
                        if (itemsSnap.hasData) {
                          final docs = itemsSnap.data!.docs;
                          final lv = lastViewed?.toDate();
                          if (lv == null) {
                            // First time: do not show a total badge
                            newCount = 0;
                          } else {
                            for (final d in docs) {
                              final data = d.data();
                              if ((data['status'] as String?) == 'claimed') continue;
                              final ts = data['createdAt'];
                              DateTime? dt;
                              if (ts is Timestamp) dt = ts.toDate();
                              if (dt != null && dt.isAfter(lv)) newCount++;
                            }
                          }
                        }
                        return _NavItem(
                          icon: Icons.inbox_outlined,
                          filledIcon: Icons.inbox,
                          label: 'Found',
                          isSelected: _currentIndex == 2,
                          onTap: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .set({'lastViewedFoundItems': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                              } catch (_) {}
                            }
                            setState(() => _currentIndex = 2);
                          },
                          badgeCount: newCount > 0 ? (newCount > 99 ? '99+' : newCount.toString()) : null,
                        );
                      },
                    );
                  },
                ),
                // Profile
                _NavItem(
                  icon: Icons.person_outline,
                  filledIcon: Icons.person,
                  label: 'Profile',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                  showBadge: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData? filledIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeCount;
  final bool showBadge;

  const _NavItem({
    required this.icon,
    this.filledIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
    this.showBadge = true,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
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
    
    // Use filled icon if selected and filledIcon is provided, otherwise use regular icon
    final iconToShow = widget.isSelected && widget.filledIcon != null 
        ? widget.filledIcon! 
        : widget.icon;
    
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
                        iconToShow,
                        color: isDark 
                            ? (widget.isSelected ? Colors.white : Colors.white.withOpacity(0.5))
                            : (widget.isSelected ? Colors.black : Colors.black.withOpacity(0.5)),
                        size: 24,
                      ),
                    ),
                    if (widget.showBadge && widget.badgeCount != null)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            widget.badgeCount!,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
