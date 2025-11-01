import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key, required this.firestore});
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('items').snapshots(),
      builder: (context, itemsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('users').snapshots(),
          builder: (context, usersSnap) {
            final items =
                itemsSnap.data?.docs.map((e) => e.data()).toList() ?? [];
            final users = usersSnap.data?.docs ?? [];
            final lostCount = items
                .where((e) => (e['type'] ?? 'lost') == 'lost')
                .length;
            final foundCount = items
                .where((e) => (e['type'] ?? '') == 'found')
                .length;
            final claimed = items
                .where((e) => (e['status'] ?? '') == 'claimed')
                .length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 520 ? 3 : 2;
                final bottomPadding =
                    16.0 +
                    MediaQuery.of(context).padding.bottom +
                    kBottomNavigationBarHeight;
                return GridView.count(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Slightly taller tiles to avoid overflow on small screens
                  childAspectRatio: 1.2,
                  children: [
                    _StatCard(
                      title: 'Lost items',
                      value: lostCount.toString(),
                      icon: Icons.report_gmailerrorred,
                      tint: Colors.orange,
                    ),
                    _StatCard(
                      title: 'Found items',
                      value: foundCount.toString(),
                      icon: Icons.inventory_2,
                      tint: Colors.blue,
                    ),
                    _StatCard(
                      title: 'Claimed',
                      value: claimed.toString(),
                      icon: Icons.verified,
                      tint: Colors.green,
                    ),
                    _StatCard(
                      title: 'Users',
                      value: users.length.toString(),
                      icon: Icons.people,
                      tint: Colors.purple,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.tint,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Theme.of(context).colorScheme.primary;
    final bg = color.withOpacity(0.12);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
