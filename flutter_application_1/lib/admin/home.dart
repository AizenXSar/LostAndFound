import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'dashboard_page.dart';
import 'posts_page.dart';
import 'users_page.dart';
import 'settings_page.dart';
import 'admin_chats_page.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../utils/sweet_alert.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;
  // New post form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  String _status = 'unclaimed';
  String _type = 'lost';
  File? _imageFile;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
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
          _UsersHost(),
          _ChatsHost(),
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
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
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
              onPressed: _openCreatePost,
              icon: const Icon(Icons.post_add),
              label: const Text('New post'),
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

class _UsersHost extends StatelessWidget {
  const _UsersHost();
  @override
  Widget build(BuildContext context) {
    return AdminUsersPage(firestore: FirebaseFirestore.instance);
  }
}

class _ChatsHost extends StatelessWidget {
  const _ChatsHost();
  @override
  Widget build(BuildContext context) {
    return AdminChatsPage(firestore: FirebaseFirestore.instance);
  }
}

class _SettingsHost extends StatelessWidget {
  const _SettingsHost();
  @override
  Widget build(BuildContext context) {
    return const AdminSettingsPage();
  }
}

// Create post bottom sheet and submission
extension _CreatePost on _AdminHomePageState {
  String _formatTime(TimeOfDay t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(hour12)}:${two(t.minute)}$ampm';
  }

  String? _combineDateTimeIso(DateTime? date, TimeOfDay? time) {
    if (date == null && time == null) return null;
    if (date == null) {
      final now = DateTime.now();
      date = DateTime(now.year, now.month, now.day);
    }
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    return combined.toIso8601String();
  }

  Future<void> _openCreatePost() async {
    _imageFile = null;
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _date = null;
    _time = null;
    _status = 'unclaimed';
    _type = 'lost';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final x = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1200,
                          maxHeight: 1200,
                          imageQuality: 85,
                        );
                        if (x != null)
                          setState(() => _imageFile = File(x.path));
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.06),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageFile == null
                            ? const Icon(Icons.add_a_photo, size: 28)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title required'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.place_outlined, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date ?? now,
                              firstDate: DateTime(now.year - 2),
                              lastDate: DateTime(now.year + 2),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            _date == null
                                ? 'Date'
                                : _date!.toLocal().toString().split(' ').first,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'unclaimed',
                              child: Text('Unclaimed', style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: 'claimed',
                              child: Text('Claimed', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'unclaimed'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _time ?? TimeOfDay.now(),
                            );
                            if (picked != null) setState(() => _time = picked);
                          },
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(_time == null ? 'Time' : _formatTime(_time!)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            prefixIcon: const Icon(Icons.category_outlined, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'lost', child: Text('Lost', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'found', child: Text('Found', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'lost'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitPost,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Post item'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      await SweetAlert.warning(
        context: context,
        title: 'Image required',
        message: 'Please attach an image of the item.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final uploadedUrl = await AuthService.uploadImageToCloudinary(
      _imageFile!.path,
    );
    if (uploadedUrl == null) {
      setState(() => _isSubmitting = false);
      await SweetAlert.error(
        context: context,
        title: 'Upload failed',
        message: AuthService.lastCloudinaryError?.isNotEmpty == true
            ? AuthService.lastCloudinaryError!
            : 'Unable to upload the image. Please try again.',
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;
    // Read author's public profile to denormalize on the item
    String authorName = '';
    String authorAvatar = '';
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final u = userDoc.data() ?? <String, dynamic>{};
      final name = (u['name'] as String?)?.trim() ?? '';
      authorName = name.isNotEmpty ? name : ((u['fullName'] as String?)?.trim() ?? '');
      authorAvatar = ((u['profileImageUrl'] as String?) ?? '').trim();
    } catch (_) {}
    final payload = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'date': _combineDateTimeIso(_date, _time),
      'status': _status,
      'type': _type,
      'imageUrl': uploadedUrl,
      'postedBy': user.uid,
      // denormalized author fields for quick display
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'createdAt': FieldValue.serverTimestamp(),
      // Initialize like fields
      'likedBy': <String>[],
      'likeCount': 0,
      // Initialize comment count
      'commentCount': 0,
    };
    try {
      await _firestore.collection('items').add(payload);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      await SweetAlert.success(
        context: context,
        title: 'Post created',
        message: 'Your item has been posted successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await SweetAlert.error(
        context: context,
        title: 'Error',
        message: 'Failed to post item: ${e.toString()}',
      );
    }
  }
}
