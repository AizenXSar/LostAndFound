import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_transaction_page.dart';

String _formatDate(DateTime date) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  final year = date.year;
  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = date.hour >= 12 ? 'PM' : 'AM';
  return '$month $day, $year • $hour:$minute $ampm';
}

String _formatShortDate(DateTime date) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  final year = date.year;
  return '$month $day, $year';
}

class AdminTransactionsPage extends StatefulWidget {
  const AdminTransactionsPage({
    super.key,
    required this.firestore,
    this.onCreateTransaction,
  });
  final FirebaseFirestore firestore;
  final void Function(VoidCallback)? onCreateTransaction;

  @override
  State<AdminTransactionsPage> createState() => _AdminTransactionsPageState();
}

class _AdminTransactionsPageState extends State<AdminTransactionsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void openNewTransactionModal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTransactionPage(
          firestore: widget.firestore,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCreateTransaction?.call(openNewTransactionModal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Header with search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildSearchBar(context),
              ),
            ],
          ),
        ),
        // Transactions List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.firestore
                .collection('transactions')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                );
              }
              
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Claimed items will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Filter out unclaimed transactions
              final claimedTransactions = snap.data!.docs.where((doc) {
                final status = (doc.data()['status'] as String?) ?? '';
                return status != 'unclaimed';
              }).toList();

              if (claimedTransactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active transactions',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All items have been marked as unclaimed',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final filtered = _searchQuery.isEmpty
                  ? claimedTransactions
                  : claimedTransactions.where((doc) {
                      final data = doc.data();
                      final title = ((data['itemTitle'] as String?) ?? '').toLowerCase();
                      final description = ((data['itemDescription'] as String?) ?? '').toLowerCase();
                      final location = ((data['itemLocation'] as String?) ?? '').toLowerCase();
                      final authorName = ((data['authorName'] as String?) ?? '').toLowerCase();
                      final claimerName = ((data['claimerName'] as String?) ?? '').toLowerCase();
                      final query = _searchQuery.toLowerCase();
                      return title.contains(query) ||
                          description.contains(query) ||
                          location.contains(query) ||
                          authorName.contains(query) ||
                          claimerName.contains(query);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No matches found',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data();
                  return _TransactionCard(
                    transactionId: doc.id,
                    itemId: (data['itemId'] as String?) ?? '',
                    data: data,
                    firestore: widget.firestore,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final hint = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.45);
    final iconColor = isDark ? Colors.white : Colors.black;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) {
            setState(() {
              _searchQuery = v.trim();
            });
          },
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, color: iconColor),
            hintText: 'Search transactions...',
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
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transactionId,
    required this.itemId,
    required this.data,
    required this.firestore,
  });
  final String transactionId;
  final String itemId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark 
        ? theme.colorScheme.outline.withOpacity(0.3)
        : Colors.grey[300]!;
    final title = (data['itemTitle'] as String?) ?? (data['title'] as String?) ?? 'Untitled';
    final location = (data['itemLocation'] as String?) ?? (data['location'] as String?) ?? '';
    final imageUrl = (data['itemImageUrl'] as String?) ?? (data['imageUrl'] as String?) ?? '';
    final postedBy = (data['postedBy'] as String?) ?? '';
    final claimerName = (data['claimerName'] as String?) ?? '';
    final claimedAt = data['claimedAt'];
    
    // Format claimed date
    String claimedDateText = '';
    if (claimedAt != null) {
      if (claimedAt is Timestamp) {
        final date = claimedAt.toDate();
        claimedDateText = _formatShortDate(date);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTransactionDetails(context),
          borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Image - Compact thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 70,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image,
                            size: 24,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Item Info - Compact
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Location
                    if (location.isNotEmpty)
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
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    // Posted By - Compact
                    _CompactPosterInfo(uid: postedBy),
                    // Claimer Name - Compact
                    if (claimerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Claimed by: $claimerName',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Claimed Date
                    if (claimedDateText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        claimedDateText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Claim Badge - Small
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 12,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Claimed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _TransactionDetailsPage(
          transactionId: transactionId,
          itemId: itemId,
          data: data,
          firestore: firestore,
        ),
      ),
    );
  }
}

class _CompactPosterInfo extends StatelessWidget {
  const _CompactPosterInfo({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return const SizedBox.shrink();
        }
        final userData = snap.data!.data() ?? {};
        final name = (userData['name'] as String?)?.trim() ??
            (userData['fullName'] as String?)?.trim() ??
            'Unknown User';

        return Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Posted by: $name',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PosterInfo extends StatelessWidget {
  const _PosterInfo({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return const SizedBox.shrink();
        }
        final userData = snap.data!.data() ?? {};
        final name = (userData['name'] as String?)?.trim() ??
            (userData['fullName'] as String?)?.trim() ??
            'Unknown User';
        final imageUrl = (userData['profileImageUrl'] as String?)?.trim() ?? '';
        final email = (userData['email'] as String?)?.trim() ?? '';

        return Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Posted by: $name',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClaimerInfo extends StatelessWidget {
  const _ClaimerInfo({
    required this.claimerUid,
    this.claimedAt,
    this.claimProof,
    this.claimMessage,
  });
  final String claimerUid;
  final dynamic claimedAt;
  final String? claimProof;
  final String? claimMessage;

  @override
  Widget build(BuildContext context) {
    DateTime? claimedDate;
    if (claimedAt != null) {
      if (claimedAt is Timestamp) {
        claimedDate = claimedAt.toDate();
      }
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(claimerUid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return _buildClaimerInfo(context, null, null, null, claimedDate);
        }
        final userData = snap.data!.data() ?? {};
        final name = (userData['name'] as String?)?.trim() ??
            (userData['fullName'] as String?)?.trim() ??
            'Unknown User';
        final imageUrl = (userData['profileImageUrl'] as String?)?.trim() ?? '';
        final email = (userData['email'] as String?)?.trim() ?? '';

        return _buildClaimerInfo(context, name, email, imageUrl, claimedDate);
      },
    );
  }

  Widget _buildClaimerInfo(
    BuildContext context,
    String? name,
    String? email,
    String? imageUrl,
    DateTime? claimedDate,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Claimed by',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Claimer Profile
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Text(
                            name != null && name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 14),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? 'Unknown User',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Claim Date
              if (claimedDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                      Text(
                        'Claimed: ${_formatDate(claimedDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              // Claim Message
              if (claimMessage != null && claimMessage!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim Message:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claimMessage!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              // Proof
              if (claimProof != null && claimProof!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proof:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        claimProof!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Proof image unavailable',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionDetailsPage extends StatelessWidget {
  const _TransactionDetailsPage({
    required this.transactionId,
    required this.itemId,
    required this.data,
    required this.firestore,
  });
  final String transactionId;
  final String itemId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (data['itemTitle'] as String?) ?? (data['title'] as String?) ?? 'Untitled';
    final description = (data['itemDescription'] as String?) ?? (data['description'] as String?) ?? '';
    final location = (data['itemLocation'] as String?) ?? (data['location'] as String?) ?? '';
    final imageUrl = (data['itemImageUrl'] as String?) ?? (data['imageUrl'] as String?) ?? '';
    final date = data['date'] as String?;
    final createdAt = data['createdAt'] ?? data['itemCreatedAt'];
    final postedBy = (data['postedBy'] as String?) ?? '';
    final claimedBy = data['claimedBy'] as String?;
    final claimedAt = data['claimedAt'];
    final claimProof = data['claimProof'] as String?;
    final claimMessage = data['claimMessage'] as String?;

    DateTime? createdDate;
    if (createdAt != null && createdAt is Timestamp) {
      createdDate = createdAt.toDate();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      // Item Image
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Item Title
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description
                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Location & Date
                      if (location.isNotEmpty || date != null) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (location.isNotEmpty)
                              _InfoChip(
                                icon: Icons.location_on_outlined,
                                label: location,
                              ),
                            if (date != null)
                              _InfoChip(
                                icon: Icons.calendar_today_outlined,
                                label: date,
                              ),
                            if (createdDate != null)
                              _InfoChip(
                                icon: Icons.access_time_outlined,
                                label: _formatShortDate(createdDate),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Posted By
                      _SectionHeader(title: 'Posted By'),
                      const SizedBox(height: 8),
                      _PosterInfo(uid: postedBy),
                      const SizedBox(height: 24),
                      // Claimed By
                      _SectionHeader(title: 'Claimed By'),
                      const SizedBox(height: 8),
                      if (claimedBy != null)
                        _ClaimerInfo(
                          claimerUid: claimedBy,
                          claimedAt: claimedAt,
                          claimProof: claimProof,
                          claimMessage: claimMessage,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Claim information not available',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

