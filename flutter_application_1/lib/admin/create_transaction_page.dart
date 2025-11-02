import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../utils/sweet_alert.dart';

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({
    super.key,
    required this.firestore,
  });
  final FirebaseFirestore firestore;

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  // Claim form state
  final _claimFormKey = GlobalKey<FormState>();
  final ValueNotifier<String?> _selectedItemIdNotifier = ValueNotifier<String?>(null);
  bool _showClaimForm = false; // Track if claim form is shown
  final TextEditingController _claimerNameController = TextEditingController();
  final TextEditingController _claimerEmailController = TextEditingController();
  final TextEditingController _claimMessageController = TextEditingController();
  final TextEditingController _itemSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  File? _proofImageFile;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  
  String? get _selectedItemId => _selectedItemIdNotifier.value;

  @override
  void initState() {
    super.initState();
    _proofImageFile = null;
    _selectedItemIdNotifier.value = null;
    _showClaimForm = false;
    _searchQueryNotifier.value = '';
    _itemSearchController.clear();
    _claimerNameController.clear();
    _claimerEmailController.clear();
    _claimMessageController.clear();
  }

  @override
  void dispose() {
    _selectedItemIdNotifier.dispose();
    _searchQueryNotifier.dispose();
    _searchFocusNode.dispose();
    _itemSearchController.dispose();
    _claimerNameController.dispose();
    _claimerEmailController.dispose();
    _claimMessageController.dispose();
    super.dispose();
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        toolbarHeight: 40,
        title: Text(_showClaimForm ? 'New Transaction - Claim Item' : 'Select Item to Claim'),
        elevation: 0,
        leading: _showClaimForm
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showClaimForm = false;
                  });
                },
                tooltip: 'Back to item selection',
              )
            : null, // Use default back button when not in claim form
        automaticallyImplyLeading: !_showClaimForm, // Only auto-imply leading when not in claim form
        actions: [
          // Show "Claim" button when item is selected but form is not shown yet
          ValueListenableBuilder<String?>(
            valueListenable: _selectedItemIdNotifier,
            builder: (context, selectedItemId, _) {
              if (selectedItemId != null && !_showClaimForm) {
                return TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showClaimForm = true;
                    });
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Claim'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Form(
        key: _claimFormKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Show item selection/search based on _showClaimForm
                  if (!_showClaimForm) ...[
                    // Item Selection Field
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: widget.firestore
                          .collection('items')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, itemsSnap) {
                        if (itemsSnap.connectionState != ConnectionState.active) {
                          return const CircularProgressIndicator();
                        }
                        final allItems = itemsSnap.data?.docs ?? [];
                        // Filter out claimed items and sort by createdAt desc
                        final items = allItems
                            .where((doc) {
                              final data = doc.data();
                              final status = (data['status'] as String?) ?? '';
                              return status != 'claimed';
                            })
                            .toList();
                        
                        // Sort by createdAt descending
                        items.sort((a, b) {
                          final aTime = (a.data()['createdAt'] as Timestamp?);
                          final bTime = (b.data()['createdAt'] as Timestamp?);
                          final aDate = aTime?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final bDate = bTime?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                          return bDate.compareTo(aDate);
                        });
                        
                        final theme = Theme.of(context);
                        final isDark = theme.brightness == Brightness.dark;
                        final bg = isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06);
                        final hint = isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.45);
                        final iconColor = isDark ? Colors.white : Colors.black;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search bar - always visible
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: TextField(
                                  controller: _itemSearchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: (v) {
                                    // Update search query using ValueNotifier - doesn't rebuild TextField
                                    final trimmed = v.trim();
                                    _searchQueryNotifier.value = trimmed;
                                    
                                    // Clear selection if user starts typing again
                                    if (trimmed.isNotEmpty && _selectedItemIdNotifier.value != null) {
                                      _selectedItemIdNotifier.value = null;
                                      setState(() {
                                        _showClaimForm = false;
                                      });
                                    }
                                  },
                                  style: theme.textTheme.bodyMedium,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.search, color: iconColor),
                                    hintText: 'Search items...',
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
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  ],
                ),
              ),
            // Show items list outside the Padding - uses full screen height
            if (!_showClaimForm)
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.firestore
                      .collection('items')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, itemsSnap) {
                    if (itemsSnap.connectionState != ConnectionState.active) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allItems = itemsSnap.data?.docs ?? [];
                    final items = allItems
                        .where((doc) {
                          final data = doc.data();
                          final status = (data['status'] as String?) ?? '';
                          return status != 'claimed';
                        })
                        .toList();
                    
                    items.sort((a, b) {
                      final aTime = (a.data()['createdAt'] as Timestamp?);
                      final bTime = (b.data()['createdAt'] as Timestamp?);
                      final aDate = aTime?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = bTime?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    });
                    
                    return ValueListenableBuilder<String>(
                      valueListenable: _searchQueryNotifier,
                      builder: (context, searchQuery, _) {
                        final filteredItems = searchQuery.isEmpty
                            ? items
                            : items.where((doc) {
                                final data = doc.data();
                                final title = ((data['title'] as String?) ?? '').toLowerCase();
                                final description = ((data['description'] as String?) ?? '').toLowerCase();
                                final location = ((data['location'] as String?) ?? '').toLowerCase();
                                final query = searchQuery.toLowerCase();
                                return title.contains(query) ||
                                    description.contains(query) ||
                                    location.contains(query);
                              }).toList();
                        
                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                items.isEmpty
                                    ? 'No unclaimed items available'
                                    : 'No items match your search',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final doc = filteredItems[index];
                            final data = doc.data();
                            final itemId = doc.id;
                            final title = (data['title'] as String?) ?? 'Untitled';
                            final description = (data['description'] as String?) ?? '';
                            final location = (data['location'] as String?) ?? '';
                            final imageUrl = (data['imageUrl'] as String?) ?? '';
                            final theme = Theme.of(context);

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 0.5,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  // Update selection without setState - only the radio button will rebuild
                                  if (_selectedItemIdNotifier.value == itemId) {
                                    _selectedItemIdNotifier.value = null;
                                  } else {
                                    _selectedItemIdNotifier.value = itemId;
                                  }
                                  _showClaimForm = false;
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                  children: [
                                    // Use ValueListenableBuilder to only rebuild the radio button
                                    ValueListenableBuilder<String?>(
                                      valueListenable: _selectedItemIdNotifier,
                                      builder: (context, selectedId, _) {
                                        final isSelected = selectedId == itemId;
                                        return Icon(
                                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurfaceVariant,
                                          size: 20,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 50,
                                                height: 50,
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                child: Icon(
                                                  Icons.image,
                                                  size: 20,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.image,
                                                size: 20,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (description.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              description,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (location.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  size: 12,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    location,
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                          color: theme.colorScheme.onSurfaceVariant,
                                                        ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
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
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Claim Form Fields - shown only after clicking "Claim" button
                      // Selected Item Info (read-only)
                      ValueListenableBuilder<String?>(
                        valueListenable: _selectedItemIdNotifier,
                        builder: (context, selectedItemId, _) {
                          if (selectedItemId == null) {
                            return const SizedBox.shrink();
                          }
                          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: widget.firestore
                                .collection('items')
                                .doc(selectedItemId)
                                .snapshots(),
                            builder: (context, itemSnap) {
                              if (!itemSnap.hasData) {
                                return const SizedBox.shrink();
                              }
                              final data = itemSnap.data!.data() ?? {};
                              final title = (data['title'] as String?) ?? 'Untitled';
                              final location = (data['location'] as String?) ?? '';
                              final imageUrl = (data['imageUrl'] as String?) ?? '';

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 40,
                                                height: 40,
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: Icon(
                                                  Icons.image,
                                                  size: 16,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.image,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (location.isNotEmpty)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  size: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    location,
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
              // Claimer Name
              Text(
                'Claimer Name *',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _claimerNameController,
                decoration: _buildInputDecoration(context),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Claimer name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              // Claimer Email
              Text(
                'Claimer Email *',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _claimerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(context),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!v.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Claim Message
              Text(
                'Claim Message',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _claimMessageController,
                maxLines: 3,
                decoration: _buildInputDecoration(context),
              ),
              const SizedBox(height: 16),
              // Proof Image Upload (moved to bottom)
              Text(
                'Proof Image *',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _showProofImageSourceOptions,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      image: _proofImageFile != null
                          ? DecorationImage(
                              image: FileImage(_proofImageFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _proofImageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 32,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload Proof',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _proofImageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                  onPressed: () {
                                    setState(() => _proofImageFile = null);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Submit Button
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitClaim,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Create Transaction'),
              ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProofImageSourceOptions() async {
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
                    setState(() => _proofImageFile = File(x.path));
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
                    setState(() => _proofImageFile = File(x.path));
                  }
                },
              ),
              if (_proofImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _proofImageFile = null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitClaim() async {
    if (!_claimFormKey.currentState!.validate()) return;
    if (_proofImageFile == null) {
      await SweetAlert.warning(
        context: context,
        title: 'Proof image required',
        message: 'Please upload a proof image for this claim.',
      );
      return;
    }

    // Validate item is selected
    if (_selectedItemId == null || _selectedItemId!.isEmpty) {
      await SweetAlert.warning(
        context: context,
        title: 'Item required',
        message: 'Please select an item to claim.',
      );
      return;
    }

    final itemId = _selectedItemId!;
    try {
      final itemDoc = await widget.firestore.collection('items').doc(itemId).get();
      if (!itemDoc.exists) {
        await SweetAlert.error(
          context: context,
          title: 'Item not found',
          message: 'The item ID you entered does not exist.',
        );
        return;
      }

      final itemData = itemDoc.data();
      if (itemData?['status'] == 'claimed') {
        await SweetAlert.warning(
          context: context,
          title: 'Already claimed',
          message: 'This item has already been claimed.',
        );
        return;
      }
    } catch (e) {
      await SweetAlert.error(
        context: context,
        title: 'Error',
        message: 'Failed to verify item: ${e.toString()}',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    // Upload proof image
    final uploadedUrl = await AuthService.uploadImageToCloudinary(
      _proofImageFile!.path,
    );
    
    if (uploadedUrl == null) {
      setState(() => _isSubmitting = false);
      await SweetAlert.error(
        context: context,
        title: 'Upload failed',
        message: AuthService.lastCloudinaryError?.isNotEmpty == true
            ? AuthService.lastCloudinaryError!
            : 'Unable to upload the proof image. Please try again.',
      );
      return;
    }

    // Get claimer user ID (if exists) or create a placeholder
    String? claimerUserId;
    
    // Try to find user by email
    try {
      final usersQuery = await widget.firestore
          .collection('users')
          .where('email', isEqualTo: _claimerEmailController.text.trim())
          .limit(1)
          .get();
      
      if (usersQuery.docs.isNotEmpty) {
        claimerUserId = usersQuery.docs.first.id;
      }
    } catch (_) {}

    // Verify user is admin before proceeding
    final isAdmin = await AuthService.currentUserIsAdmin();
    if (!isAdmin) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await SweetAlert.error(
        context: context,
        title: 'Permission Denied',
        message: 'Only administrators can create transactions.',
      );
      return;
    }

    try {
      // Get item data for transaction record
      final itemDoc = await widget.firestore.collection('items').doc(itemId).get();
      final itemData = itemDoc.data() ?? {};
      
      // Get current user ID for transaction record
      final currentUser = AuthService.currentUser;
      final adminUserId = currentUser?.uid ?? 'unknown';
      
      // Create transaction document in Firestore
      final transactionData = {
        'itemId': itemId,
        'itemTitle': (itemData['title'] as String?) ?? 'Untitled',
        'itemDescription': (itemData['description'] as String?) ?? '',
        'itemLocation': (itemData['location'] as String?) ?? '',
        'itemImageUrl': (itemData['imageUrl'] as String?) ?? '',
        'itemType': (itemData['type'] as String?) ?? 'lost',
        'postedBy': (itemData['postedBy'] as String?) ?? '',
        'authorName': (itemData['authorName'] as String?) ?? '',
        'authorAvatar': (itemData['authorAvatar'] as String?) ?? '',
        'itemCreatedAt': itemData['createdAt'],
        // Claim information
        'status': 'claimed',
        'claimedBy': claimerUserId ?? 'unknown',
        'claimedAt': FieldValue.serverTimestamp(),
        'claimProof': uploadedUrl,
        'claimMessage': _claimMessageController.text.trim(),
        'claimerName': _claimerNameController.text.trim(),
        'claimerEmail': _claimerEmailController.text.trim(),
        // Transaction metadata
        'createdAt': FieldValue.serverTimestamp(),
        'transactionType': 'claim',
        'createdBy': adminUserId, // Admin who created the transaction
      };
      
      // Save transaction to Firestore
      await widget.firestore.collection('transactions').add(transactionData);
      
      // Also update item with claim information (for backward compatibility)
      await widget.firestore.collection('items').doc(itemId).update({
        'status': 'claimed',
        'claimedBy': claimerUserId ?? 'unknown',
        'claimedAt': FieldValue.serverTimestamp(),
        'claimProof': uploadedUrl,
        'claimMessage': _claimMessageController.text.trim(),
        'claimerName': _claimerNameController.text.trim(),
        'claimerEmail': _claimerEmailController.text.trim(),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      await SweetAlert.success(
        context: context,
        title: 'Transaction created',
        message: 'Item has been successfully claimed.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await SweetAlert.error(
        context: context,
        title: 'Error',
        message: 'Failed to create transaction: ${e.toString()}',
      );
    }
  }
}

