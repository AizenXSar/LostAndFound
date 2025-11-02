import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../utils/sweet_alert.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.firestore,
  });
  final FirebaseFirestore firestore;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DateTime? _date;
  TimeOfDay? _time;
  String _status = 'unclaimed';
  String _type = 'lost';
  File? _imageFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imageFile = null;
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _date = null;
    _time = null;
    _status = 'unclaimed';
    _type = 'lost';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

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

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final x = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1200,
                    maxHeight: 1200,
                    imageQuality: 85,
                  );
                  if (x != null) {
                    setState(() => _imageFile = File(x.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final x = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1200,
                    maxHeight: 1200,
                    imageQuality: 85,
                  );
                  if (x != null) {
                    setState(() => _imageFile = File(x.path));
                  }
                },
              ),
              if (_imageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _imageFile = null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    // Prevent double-posting: check if already submitting
    if (_isSubmitting) return;
    
    // Validate form first
    if (!_formKey.currentState!.validate()) return;
    
    // Check for image
    if (_imageFile == null) {
      await SweetAlert.warning(
        context: context,
        title: 'Image required',
        message: 'Please attach an image of the item.',
      );
      return;
    }
    
    // Set submitting state immediately to prevent double-posting
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    final uploadedUrl = await AuthService.uploadImageToCloudinary(
      _imageFile!.path,
    );
    if (uploadedUrl == null) {
      if (!mounted) return;
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
    if (user == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }
    // Read author's public profile to denormalize on the item
    String authorName = '';
    String authorAvatar = '';
    try {
      final userDoc = await widget.firestore.collection('users').doc(user.uid).get();
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
      await widget.firestore.collection('items').add(payload);
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

  InputDecoration _buildInputDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark 
        ? theme.colorScheme.surfaceContainerHighest 
        : Colors.white;
    final borderColor = isDark 
        ? theme.colorScheme.outline.withOpacity(0.3)
        : Colors.grey[300]!;
    final focusedBorderColor = isDark 
        ? theme.colorScheme.primary.withOpacity(0.5)
        : Colors.grey[400]!;
    
    return InputDecoration(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: focusedBorderColor, width: 0.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red, width: 0.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red, width: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceOptions,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
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
              const SizedBox(height: 24),
              Text(
                'Title',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration(context),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title required'
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Description',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 5,
                decoration: _buildInputDecoration(context),
              ),
              const SizedBox(height: 20),
              Text(
                'Location',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: _buildInputDecoration(context),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final isDark = theme.brightness == Brightness.dark;
                            final bgColor = isDark 
                                ? theme.colorScheme.surfaceContainerHighest 
                                : Colors.white;
                            final borderColor = isDark 
                                ? theme.colorScheme.outline.withOpacity(0.3)
                                : Colors.grey[300]!;
                            final iconColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[700]!;
                            final textColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[800]!;
                            
                            return OutlinedButton(
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date ?? now,
                                  firstDate: DateTime(now.year - 2),
                                  lastDate: DateTime(now.year + 2),
                                );
                                if (picked != null) {
                                  setState(() => _date = picked);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: bgColor,
                                side: BorderSide(color: borderColor, width: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event, size: 18, color: iconColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _date == null
                                          ? 'Date'
                                          : _date!.toLocal().toString().split(' ').first,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final isDark = theme.brightness == Brightness.dark;
                            final fillColor = isDark 
                                ? theme.colorScheme.surfaceContainerHighest 
                                : Colors.white;
                            final borderColor = isDark 
                                ? theme.colorScheme.outline.withOpacity(0.3)
                                : Colors.grey[300]!;
                            final focusedBorderColor = isDark 
                                ? theme.colorScheme.primary.withOpacity(0.5)
                                : Colors.grey[400]!;
                            final iconColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[700]!;
                            final textColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[800]!;
                            final dropdownBg = isDark 
                                ? theme.colorScheme.surfaceContainerHighest 
                                : Colors.white;
                            
                            return DropdownButtonFormField<String>(
                              value: _status,
                              icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: iconColor),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textColor,
                              ),
                              dropdownColor: dropdownBg,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fillColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: borderColor, width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: borderColor, width: 0.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: focusedBorderColor, width: 0.5),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.never,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'unclaimed',
                                  child: Text('Unclaimed'),
                                ),
                                DropdownMenuItem(
                                  value: 'claimed',
                                  child: Text('Claimed'),
                                ),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? 'unclaimed'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final isDark = theme.brightness == Brightness.dark;
                            final bgColor = isDark 
                                ? theme.colorScheme.surfaceContainerHighest 
                                : Colors.white;
                            final borderColor = isDark 
                                ? theme.colorScheme.outline.withOpacity(0.3)
                                : Colors.grey[300]!;
                            final iconColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[700]!;
                            final textColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[800]!;
                            
                            return OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _time ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setState(() => _time = picked);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: bgColor,
                                side: BorderSide(color: borderColor, width: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 18, color: iconColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _time == null ? 'Time' : _formatTime(_time!),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final isDark = theme.brightness == Brightness.dark;
                            final fillColor = isDark 
                                ? theme.colorScheme.surfaceContainerHighest 
                                : Colors.white;
                            final borderColor = isDark 
                                ? theme.colorScheme.outline.withOpacity(0.3)
                                : Colors.grey[300]!;
                            final focusedBorderColor = isDark 
                                ? theme.colorScheme.primary.withOpacity(0.5)
                                : Colors.grey[400]!;
                            final iconColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[700]!;
                            final textColor = isDark 
                                ? theme.colorScheme.onSurface 
                                : Colors.grey[800]!;
                            final dropdownBg = isDark 
                                ? theme.colorScheme.surfaceContainerHighest 
                                : Colors.white;
                            
                            return DropdownButtonFormField<String>(
                              value: _type,
                              icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: iconColor),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textColor,
                              ),
                              dropdownColor: dropdownBg,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fillColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: borderColor, width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: borderColor, width: 0.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: focusedBorderColor, width: 0.5),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.never,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'lost', child: Text('Lost')),
                                DropdownMenuItem(value: 'found', child: Text('Found')),
                              ],
                              onChanged: (v) => setState(() => _type = v ?? 'lost'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
  }
}

