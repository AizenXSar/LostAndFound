import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../theme/theme_controller.dart';
import '../utils/sweet_alert.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false; // kept for potential future inline save indicators
  bool _isEditing = false;
  File? _newProfileImage;
  String? _currentProfileImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    final data = await AuthService.getUserData(user.uid);
    _nameController.text = (data?["name"] as String?) ?? '';
    _emailController.text = user.email ?? '';
    _currentProfileImageUrl = (data?["profileImageUrl"] as String?) ?? '';

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickNewImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    String? profileImageUrl = _currentProfileImageUrl;
    if (_newProfileImage != null) {
      final uploaded = await AuthService.uploadImageToCloudinary(
        _newProfileImage!.path,
      );
      if (uploaded != null) {
        profileImageUrl = uploaded;
      } else {
        if (!mounted) return;
        final err = AuthService.lastCloudinaryError;
        await SweetAlert.error(
          context: context,
          title: 'Upload failed',
          message: err == null || err.isEmpty
              ? 'Could not upload the new profile image.'
              : 'Could not upload the new profile image.\n\n$err',
        );
      }
    }

    final success = await AuthService.updateUserData(user.uid, {
      'name': _nameController.text.trim(),
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    });

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (success) {
        _currentProfileImageUrl = profileImageUrl;
        _newProfileImage = null;
      }
    });

    await SweetAlert.fire(
      context: context,
      title: success ? 'Saved' : 'Error',
      message: success
          ? 'Your changes have been saved.'
          : 'Could not save your changes.',
      icon: success ? SweetAlertType.success : SweetAlertType.error,
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: _isEditing ? 'Save' : 'Edit',
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () async {
                if (_isEditing) {
                  await _save();
                  if (!mounted) return;
                  setState(() {
                    _isEditing = false;
                  });
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
          IconButton(
            tooltip: ThemeController.instance.isDark
                ? 'Light mode'
                : 'Dark mode',
            icon: Icon(
              ThemeController.instance.isDark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => ThemeController.instance.toggle(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          const SizedBox(height: 8),
                          Center(
                            child: Stack(
                              children: [
                                // Avatar with white outline circle
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.1),
                                    backgroundImage: _newProfileImage != null
                                        ? FileImage(_newProfileImage!)
                                        : (_currentProfileImageUrl != null &&
                                              _currentProfileImageUrl!
                                                  .isNotEmpty)
                                        ? NetworkImage(_currentProfileImageUrl!)
                                              as ImageProvider
                                        : null,
                                    child:
                                        (_newProfileImage == null &&
                                            (_currentProfileImageUrl == null ||
                                                _currentProfileImageUrl!
                                                    .isEmpty))
                                        ? Icon(
                                            Icons.person,
                                            size: 36,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                          )
                                        : null,
                                  ),
                                ),
                                if (_isEditing)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        onPressed: _pickNewImage,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isEditing) ...[
                            Align(
                              alignment: Alignment.center,
                              child: TextButton.icon(
                                onPressed: _pickNewImage,
                                icon: const Icon(Icons.image_outlined, size: 18),
                                label: const Text('Change Photo', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // Name (editable)
                          TextFormField(
                            controller: _nameController,
                            enabled: _isEditing,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: const TextStyle(fontSize: 14),
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).inputDecorationTheme.fillColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Please enter your name';
                              if (v.trim().length < 2)
                                return 'Name must be at least 2 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          // Email (read-only)
                          TextFormField(
                            controller: _emailController,
                            enabled: false,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: const TextStyle(fontSize: 14),
                              prefixIcon: const Icon(Icons.email_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).inputDecorationTheme.fillColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Saved Posts Section
                          const Divider(height: 24),
                          const Text(
                            'Saved Posts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SavedPostsList(uid: AuthService.currentUser?.uid ?? ''),
                          const SizedBox(height: 100), // Space for floating button
                        ],
                      ),
                    ),
                  ),
                // Floating logout button - positioned at very edge of footer
                Positioned(
                  bottom: -MediaQuery.of(context).padding.bottom,
                  right: 16,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.black,
                    child: InkWell(
                      onTap: () => _logout(context),
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.black,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.logout,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Log out',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SavedPostsList extends StatelessWidget {
  const _SavedPostsList({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('Please sign in to see saved posts'));
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final savedPosts = (userData?['savedPosts'] as List?)?.cast<String>() ?? [];
        
        if (savedPosts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'No saved posts yet.\nSave posts by tapping the bookmark icon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Firestore whereIn has a limit of 10 items, so we'll fetch all and filter client-side
        // Or we can fetch them individually if the list is small
        if (savedPosts.length > 10) {
          // For large lists, fetch all items and filter client-side
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, itemsSnap) {
              if (itemsSnap.connectionState != ConnectionState.active) {
                return const Center(child: CircularProgressIndicator());
              }
              final allDocs = itemsSnap.data?.docs ?? [];
              final docs = allDocs.where((doc) => savedPosts.contains(doc.id)).toList();
              return _buildPostList(docs);
            },
          );
        } else {
          // For small lists, use whereIn (max 10 items)
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('items')
                .where(FieldPath.documentId, whereIn: savedPosts)
                .snapshots(),
            builder: (context, itemsSnap) {
              if (itemsSnap.connectionState != ConnectionState.active) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = itemsSnap.data?.docs ?? [];
              return _buildPostList(docs);
            },
          );
        }
      },
    );
  }

  Widget _buildPostList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No saved posts found.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data();
        final id = docs[index].id;
        final imageUrl = (data['imageUrl'] as String?) ?? '';
        final title = (data['title'] as String?) ?? '';
        
        return _CompactPostCard(
          id: id,
          imageUrl: imageUrl,
          title: title,
        );
      },
    );
  }
}

class _CompactPostCard extends StatelessWidget {
  const _CompactPostCard({
    required this.id,
    required this.imageUrl,
    required this.title,
  });
  final String id;
  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to full post view or show details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title.isEmpty ? 'Post' : title)),
              body: Center(
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : const Text('No image available'),
              ),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : Container(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                          child: const Center(child: Icon(Icons.broken_image, size: 24)),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                        child: const Center(child: Icon(Icons.image, size: 24)),
                      ),
              ),
              if (title.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
