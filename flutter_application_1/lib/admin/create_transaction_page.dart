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
  final TextEditingController _claimerPhoneController = TextEditingController();
  final TextEditingController _claimMessageController = TextEditingController();
  final TextEditingController _itemSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _emailQueryNotifier = ValueNotifier<String>('');
  File? _proofImageFile;
  File? _idFrontImageFile;
  File? _idBackImageFile;
  String? _retrievedIdFrontUrl;
  String? _retrievedIdBackUrl;
  bool _isSubmitting = false;
  bool _showEmailDropdown = false;
  bool _emailFound = false; // Track if email has been found/searched
  final ImagePicker _picker = ImagePicker();
  
  String? get _selectedItemId => _selectedItemIdNotifier.value;

  @override
  void initState() {
    super.initState();
    _proofImageFile = null;
    _idFrontImageFile = null;
    _idBackImageFile = null;
    _retrievedIdFrontUrl = null;
    _retrievedIdBackUrl = null;
    _selectedItemIdNotifier.value = null;
    _showClaimForm = false;
    _emailFound = false;
    _searchQueryNotifier.value = '';
    _itemSearchController.clear();
    _claimerNameController.clear();
    _claimerEmailController.clear();
    _claimerPhoneController.clear();
    _claimMessageController.clear();
    
    // Close dropdown when email field loses focus
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        setState(() {
          _showEmailDropdown = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _selectedItemIdNotifier.dispose();
    _searchQueryNotifier.dispose();
    _emailQueryNotifier.dispose();
    _searchFocusNode.dispose();
    _emailFocusNode.dispose();
    _itemSearchController.dispose();
    _claimerNameController.dispose();
    _claimerEmailController.dispose();
    _claimerPhoneController.dispose();
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
        title: Text(
          _showClaimForm ? 'New Transaction - Claim Item' : 'Select Item to Claim',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
                          return const SizedBox.shrink();
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
                      return const SizedBox.shrink();
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
                            final isDark = theme.brightness == Brightness.dark;
                            final borderColor = isDark 
                                ? theme.colorScheme.outline.withOpacity(0.3)
                                : Colors.grey[300]!;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: borderColor,
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
                                              cacheWidth: 100, // 2x for retina
                                              cacheHeight: 100,
                                              loadingBuilder: (context, child, progress) => child,
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
                      // Note: Selected Item Info is now shown after Claim Message (moved below)
              // SECTION 1: Email Search (First - to auto-fill user data)
              Text(
                'Step 1: Search Claimer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the claimer\'s email to auto-fill their information',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              // Claimer Email
              Text(
                'Claimer Email *',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              // Email Autocomplete Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _claimerEmailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration(context).copyWith(
                      hintText: 'example@umindanao.edu.ph',
                      helperText: 'Only @umindanao.edu.ph emails are allowed',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchUserByEmail,
                        tooltip: 'Search user by email',
                      ),
                    ),
                    onChanged: (value) {
                      _emailQueryNotifier.value = value.trim();
                      // Show dropdown if user types at least 1 character
                      if (value.trim().length >= 1) {
                        setState(() {
                          _showEmailDropdown = true;
                        });
                      } else {
                        setState(() {
                          _showEmailDropdown = false;
                        });
                      }
                      // Auto-search when email is complete
                      if (value.contains('@') && value.contains('.')) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_claimerEmailController.text == value && value.trim().isNotEmpty) {
                            _searchUserByEmail();
                            setState(() {
                              _showEmailDropdown = false;
                            });
                          }
                        });
                      }
                    },
                    onTap: () {
                      if (_claimerEmailController.text.trim().length >= 1) {
                        setState(() {
                          _showEmailDropdown = true;
                        });
                      }
                    },
                    onEditingComplete: () {
                      setState(() {
                        _showEmailDropdown = false;
                      });
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      final email = v.trim().toLowerCase();
                      if (!email.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      if (!email.endsWith('@umindanao.edu.ph')) {
                        return 'Only @umindanao.edu.ph email addresses are allowed';
                      }
                      // Validate email format
                      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@umindanao\.edu\.ph$').hasMatch(email)) {
                        return 'Please enter a valid University of Mindanao email';
                      }
                      return null;
                    },
                  ),
                  // Email Dropdown Suggestions (placed below the field)
                  if (_showEmailDropdown)
                    ValueListenableBuilder<String>(
                      valueListenable: _emailQueryNotifier,
                      builder: (context, query, _) {
                        if (query.trim().isEmpty || query.trim().length < 1) {
                          return const SizedBox.shrink();
                        }
                        
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: widget.firestore
                              .collection('users')
                              .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
                              .where('email', isLessThan: query.toLowerCase() + '\uf8ff')
                              .limit(10)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData || snap.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            final users = snap.data!.docs.where((doc) {
                              final email = (doc.data()['email'] as String?) ?? '';
                              final emailLower = email.toLowerCase();
                              final queryLower = query.toLowerCase();
                              // Match emails that start with the query and end with @umindanao.edu.ph
                              return emailLower.startsWith(queryLower) &&
                                     emailLower.endsWith('@umindanao.edu.ph');
                            }).toList();
                            
                            if (users.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            final theme = Theme.of(context);
                            final isDark = theme.brightness == Brightness.dark;
                            final bgColor = isDark
                                ? theme.colorScheme.surface
                                : Colors.white;
                            
                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? theme.colorScheme.outline.withOpacity(0.3)
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                color: bgColor,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final userDoc = users[index];
                                    final userData = userDoc.data();
                                    final email = (userData['email'] as String?) ?? '';
                                    final name = (userData['name'] as String?) ?? '';
                                    
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _showEmailDropdown = false;
                                        });
                                        _claimerEmailController.text = email;
                                        _emailQueryNotifier.value = email;
                                        // Keep focus briefly to prevent auto-close, then unfocus
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          _emailFocusNode.unfocus();
                                        });
                                        _searchUserByEmail();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.email_outlined,
                                              size: 18,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    email,
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (name.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      name,
                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
              // SECTION 2 & 3: Hidden until email is found
              if (_emailFound) ...[
                const SizedBox(height: 24),
                // SECTION 2: User Information (Auto-filled from email search)
                Text(
                  'Step 2: Claimer Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Review the auto-filled information. These fields are read-only.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Claimer Name (Read-only)
                Text(
                  'Claimer Name *',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _claimerNameController,
                  readOnly: true,
                  enabled: false,
                  decoration: _buildInputDecoration(context).copyWith(
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Claimer name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                // Claimer Phone Number (Read-only)
                Text(
                  'Phone Number *',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _claimerPhoneController,
                  keyboardType: TextInputType.phone,
                  readOnly: true,
                  enabled: false,
                  decoration: _buildInputDecoration(context).copyWith(
                    hintText: '+63 9XX XXX XXXX',
                    helperText: 'Include country code (e.g., +63)',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final phone = v.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                    if (phone.length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
                      return 'Please enter a valid phone number format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Claim Message (Editable, optional)
                Text(
                  'Claim Message',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _claimMessageController,
                  maxLines: 3,
                  decoration: _buildInputDecoration(context).copyWith(
                    hintText: 'Additional message or notes about the claim... (optional)',
                    helperText: 'Optional',
                  ),
                ),
                const SizedBox(height: 24),
                // Selected Item Display (read-only - item was already selected before entering form)
                      ValueListenableBuilder<String?>(
                        valueListenable: _selectedItemIdNotifier,
                        builder: (context, selectedItemId, _) {
                          if (selectedItemId == null) {
                            return const SizedBox.shrink();
                          }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lost and Found Item',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                            width: 50,
                                            height: 50,
                                              fit: BoxFit.cover,
                                            cacheWidth: 100,
                                            cacheHeight: 100,
                                              loadingBuilder: (context, child, progress) => child,
                                              errorBuilder: (_, __, ___) => Container(
                                              width: 50,
                                              height: 50,
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: Icon(
                                                  Icons.image,
                                                size: 20,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          : Container(
                                            width: 50,
                                            height: 50,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.image,
                                              size: 20,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (location.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                size: 14,
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
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                        ),
                      ],
                          );
                        },
                      ),
                const SizedBox(height: 24),
                // SECTION 3: Verification Documents
                Text(
                  'Step 3: Verification Documents',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      ),
                      const SizedBox(height: 8),
              Text(
                  'Upload Student ID documents and proof of claim',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(height: 16),
                // Student ID Upload (Front)
              Text(
                  'Student ID (Front) *',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'University of Mindanao Student ID - Required for verification',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    // Check if user has ID on file
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: widget.firestore
                          .collection('users')
                          .where('email', isEqualTo: _claimerEmailController.text.trim().toLowerCase())
                          .limit(1)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data!.docs.isNotEmpty) {
                          final userData = snap.data!.docs.first.data();
                          final hasIdFront = ((userData['idFrontUrl'] as String?) ?? '').isNotEmpty;
                          final hasIdBack = ((userData['idBackUrl'] as String?) ?? '').isNotEmpty;
                          if (hasIdFront && hasIdBack && _claimerEmailController.text.trim().isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '✓ User has Student ID documents on file - will be used automatically',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => _showIdImageSourceOptions(true),
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
                      ),
                      child: _idFrontImageFile != null
                          ? Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _idFrontImageFile!,
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
                                      setState(() {
                                        _idFrontImageFile = null;
                                        // Restore retrieved URL if it exists
                                        if (_retrievedIdFrontUrl != null) {
                                          _idFrontImageFile = null;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            )
                          : _retrievedIdFrontUrl != null && _retrievedIdFrontUrl!.isNotEmpty
                              ? Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _retrievedIdFrontUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) => child,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.badge_outlined,
                                                  size: 32,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Failed to load',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 32,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload Student ID Front',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
              ),
              const SizedBox(height: 16),
                // Student ID Upload (Back)
              Text(
                  'Student ID (Back) *',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => _showIdImageSourceOptions(false),
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
                        image: _idBackImageFile != null
                            ? DecorationImage(
                                image: FileImage(_idBackImageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _idBackImageFile != null
                          ? Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _idBackImageFile!,
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
                                      setState(() {
                                        _idBackImageFile = null;
                                        // Restore retrieved URL if it exists
                                        if (_retrievedIdBackUrl != null) {
                                          _idBackImageFile = null;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            )
                          : _retrievedIdBackUrl != null && _retrievedIdBackUrl!.isNotEmpty
                              ? Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _retrievedIdBackUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) => child,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.badge_outlined,
                                                  size: 32,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Failed to load',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 32,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload Student ID Back',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
              ),
              const SizedBox(height: 16),
                // Proof Image Upload
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

  Future<void> _showIdImageSourceOptions(bool isFront) async {
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
                    setState(() {
                      if (isFront) {
                        _idFrontImageFile = File(x.path);
                        _retrievedIdFrontUrl = null; // Clear retrieved URL when new image is uploaded
                      } else {
                        _idBackImageFile = File(x.path);
                        _retrievedIdBackUrl = null; // Clear retrieved URL when new image is uploaded
                      }
                    });
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
                    setState(() {
                      if (isFront) {
                        _idFrontImageFile = File(x.path);
                        _retrievedIdFrontUrl = null; // Clear retrieved URL when new image is uploaded
                      } else {
                        _idBackImageFile = File(x.path);
                        _retrievedIdBackUrl = null; // Clear retrieved URL when new image is uploaded
                      }
                    });
                  }
                },
              ),
              if ((isFront && _idFrontImageFile != null) || (!isFront && _idBackImageFile != null))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isFront) {
                        _idFrontImageFile = null;
                      } else {
                        _idBackImageFile = null;
                      }
                    });
                  },
                ),
            ],
          ),
        );
      },
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

  Future<void> _searchUserByEmail() async {
    final email = _claimerEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      return;
    }

    try {
      final usersQuery = await widget.firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        final userData = usersQuery.docs.first.data();
        final userName = (userData['name'] as String?) ?? '';
        final userPhone = (userData['phone'] as String?) ?? '';
        final idFrontUrl = (userData['idFrontUrl'] as String?) ?? '';
        final idBackUrl = (userData['idBackUrl'] as String?) ?? '';

        // Auto-fill name
        if (userName.isNotEmpty) {
          _claimerNameController.text = userName;
        }

        // Auto-fill phone if available
        if (userPhone.isNotEmpty) {
          _claimerPhoneController.text = userPhone;
        }

        // Store retrieved ID URLs for display
        setState(() {
          _emailFound = true; // Show Step 2 and Step 3
          _retrievedIdFrontUrl = idFrontUrl.isNotEmpty ? idFrontUrl : null;
          _retrievedIdBackUrl = idBackUrl.isNotEmpty ? idBackUrl : null;
          // Clear file uploads if we have stored URLs
          if (_retrievedIdFrontUrl != null) {
            _idFrontImageFile = null;
          }
          if (_retrievedIdBackUrl != null) {
            _idBackImageFile = null;
          }
        });

        // If ID documents exist, they will be used automatically
        // No notification needed - user can see the auto-filled fields
      } else {
        // User not found - clear auto-filled fields and retrieved IDs
        setState(() {
          _emailFound = false; // Hide Step 2 and Step 3
          _retrievedIdFrontUrl = null;
          _retrievedIdBackUrl = null;
        });
        // No notification needed
      }
    } catch (e) {
      // Silently handle errors - don't show error for search
      print('Error searching user: $e');
    }
  }

  Future<void> _submitClaim() async {
    if (!_claimFormKey.currentState!.validate()) return;
    
    // Check if user has ID documents on file
    String? storedIdFrontUrl;
    String? storedIdBackUrl;
    
    try {
      final email = _claimerEmailController.text.trim();
      if (email.isNotEmpty) {
        final usersQuery = await widget.firestore
            .collection('users')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();
        
        if (usersQuery.docs.isNotEmpty) {
          final userData = usersQuery.docs.first.data();
          storedIdFrontUrl = (userData['idFrontUrl'] as String?) ?? '';
          storedIdBackUrl = (userData['idBackUrl'] as String?) ?? '';
        }
      }
    } catch (_) {}
    
    // Validate Student ID documents - use stored ones if available, otherwise require upload
    String? idFrontUrl = storedIdFrontUrl;
    String? idBackUrl = storedIdBackUrl;
    
    if ((idFrontUrl == null || idFrontUrl.isEmpty) && _idFrontImageFile == null) {
      await SweetAlert.warning(
        context: context,
        title: 'Student ID required',
        message: 'Please upload the front of the Student ID or ensure the user has Student ID on file.',
      );
      return;
    }
    
    if ((idBackUrl == null || idBackUrl.isEmpty) && _idBackImageFile == null) {
      await SweetAlert.warning(
        context: context,
        title: 'Student ID required',
        message: 'Please upload the back of the Student ID or ensure the user has Student ID on file.',
      );
      return;
    }
    
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
    
    // Upload ID documents if new ones were uploaded (otherwise use stored ones)
    if (idFrontUrl == null || idFrontUrl.isEmpty) {
      if (_idFrontImageFile != null) {
        idFrontUrl = await AuthService.uploadImageToCloudinary(
          _idFrontImageFile!.path,
        );
        
        if (idFrontUrl == null) {
          setState(() => _isSubmitting = false);
          await SweetAlert.error(
            context: context,
            title: 'Upload failed',
            message: AuthService.lastCloudinaryError?.isNotEmpty == true
                ? AuthService.lastCloudinaryError!
                : 'Unable to upload Student ID front image. Please try again.',
          );
          return;
        }
      }
    }
    
    if (idBackUrl == null || idBackUrl.isEmpty) {
      if (_idBackImageFile != null) {
        idBackUrl = await AuthService.uploadImageToCloudinary(
          _idBackImageFile!.path,
        );
        
        if (idBackUrl == null) {
          setState(() => _isSubmitting = false);
          await SweetAlert.error(
            context: context,
            title: 'Upload failed',
            message: AuthService.lastCloudinaryError?.isNotEmpty == true
                ? AuthService.lastCloudinaryError!
                : 'Unable to upload Student ID back image. Please try again.',
          );
          return;
        }
      }
    }
    
    // Upload proof image
    String? proofUrl;
    
    // Upload proof image
    proofUrl = await AuthService.uploadImageToCloudinary(
      _proofImageFile!.path,
    );
    
    if (proofUrl == null) {
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
        'claimProof': proofUrl,
        'idFrontUrl': idFrontUrl,
        'idBackUrl': idBackUrl,
        'claimerPhone': _claimerPhoneController.text.trim(),
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
        'claimProof': proofUrl,
        'idFrontUrl': idFrontUrl,
        'idBackUrl': idBackUrl,
        'claimerPhone': _claimerPhoneController.text.trim(),
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

