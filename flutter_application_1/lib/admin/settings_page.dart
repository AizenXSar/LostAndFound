import 'package:flutter/material.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('App info'),
          subtitle: Text('Lost and Found admin panel'),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.announcement_outlined),
          title: Text('Announcements'),
          subtitle: Text('Coming soon'),
        ),
      ],
    );
  }
}
