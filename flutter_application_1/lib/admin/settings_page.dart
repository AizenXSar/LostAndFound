import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'archive_page.dart';
import 'logs_page.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({
    super.key,
    required this.firestore,
  });
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('App info'),
          subtitle: Text('Lost and Found admin panel'),
        ),
        const ListTile(
          leading: Icon(Icons.announcement_outlined),
          title: Text('Announcements'),
          subtitle: Text('Coming soon'),
        ),
        ListTile(
          leading: const Icon(Icons.archive),
          title: const Text('Archive'),
          subtitle: const Text('View all archived items'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ArchivePage(
                  firestore: firestore,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Logs'),
          subtitle: const Text('View user and admin login logs'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LogsPage(
                  firestore: firestore,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
