import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({
    super.key,
    required this.firestore,
  });
  final FirebaseFirestore firestore;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  String _selectedFilter = 'all'; // 'all', 'user', 'admin'

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp, String? loginDateStr) {
    DateTime? date;
    
    // Try to get date from timestamp first
    if (timestamp != null) {
      date = timestamp.toDate();
    } else if (loginDateStr != null) {
      // Fallback to loginDate string if timestamp is missing
      try {
        date = DateTime.parse(loginDateStr);
      } catch (_) {
        return 'Unknown';
      }
    } else {
      return 'Unknown';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[date.month - 1];
      final day = date.day.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$month $day, $year at $hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Login Logs'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                _buildSearchBar(context),
                const SizedBox(height: 8),
                _buildFilterChips(),
              ],
            ),
          ),
          Expanded(
            child: _buildLogsList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.firestore
            .collection('loginLogs')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Check for errors in the snapshot
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading logs: ${snap.error}'),
                ],
              ),
            );
          }
          
          final allDocs = snap.data?.docs ?? [];
          print('Total login logs found: ${allDocs.length}');
          
          // Debug: Print all log document IDs
          if (allDocs.isNotEmpty) {
            print('Log document IDs: ${allDocs.map((d) => d.id).toList()}');
            for (var doc in allDocs.take(3)) {
              print('Sample log data: ${doc.data()}');
            }
          }
          
          if (allDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No login logs yet'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Login logs are created when you log in.\n\n'
                      'To see your login history:\n'
                      '1. Log out of the app\n'
                      '2. Log back in\n'
                      '3. Return to this page',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Sort by timestamp in memory (for reliability and to handle missing timestamps)
          final sortedDocs = [...allDocs];
          sortedDocs.sort((a, b) {
            final aTimestamp = a.data()['timestamp'];
            final bTimestamp = b.data()['timestamp'];
            final aDateStr = a.data()['loginDate'] as String?;
            final bDateStr = b.data()['loginDate'] as String?;
            
            DateTime? aDate, bDate;
            
            // Try to get date from timestamp first
            if (aTimestamp is Timestamp) {
              aDate = aTimestamp.toDate();
            } else if (aDateStr != null) {
              try {
                aDate = DateTime.parse(aDateStr);
              } catch (_) {}
            }
            
            if (bTimestamp is Timestamp) {
              bDate = bTimestamp.toDate();
            } else if (bDateStr != null) {
              try {
                bDate = DateTime.parse(bDateStr);
              } catch (_) {}
            }
            
            // Sort descending (newest first)
            if (aDate != null && bDate != null) {
              return bDate.compareTo(aDate);
            }
            // If only one has a date, prioritize it
            if (aDate != null) return -1;
            if (bDate != null) return 1;
            // If neither has a date, maintain order
            return 0;
          });
          
          return ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, query, _) {
              final q = query.trim().toLowerCase();
              
              // Filter by type (user/admin) and search query
              final filtered = sortedDocs.where((doc) {
                final data = doc.data();
                final userType = (data['userType'] as String?) ?? 'user';
                final userName = ((data['userName'] as String?) ?? '').toLowerCase();
                final userEmail = ((data['userEmail'] as String?) ?? '').toLowerCase();
                
                // Filter by type
                if (_selectedFilter == 'user' && userType != 'user') return false;
                if (_selectedFilter == 'admin' && userType != 'admin') return false;
                
                // Filter by search query
                if (q.isNotEmpty) {
                  if (!userName.contains(q) && !userEmail.contains(q)) {
                    return false;
                  }
                }
                
                return true;
              }).toList();
              
              if (filtered.isEmpty) {
                return const Center(child: Text('No matches'));
              }
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final data = filtered[index].data();
                  final userId = (data['userId'] as String?) ?? '';
                  final userType = (data['userType'] as String?) ?? 'user';
                  final userName = (data['userName'] as String?) ?? 'Unknown';
                  final userEmail = (data['userEmail'] as String?) ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final loginDateStr = data['loginDate'] as String?;
                  
                  final isAdmin = userType.toLowerCase() == 'admin';
                  
                  // Get user's profile image from users collection
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: userId.isNotEmpty
                        ? widget.firestore.collection('users').doc(userId).snapshots()
                        : const Stream.empty(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data();
                      final profileImageUrl = (userData?['profileImageUrl'] as String?)?.trim();
                      final theme = Theme.of(context);
                      final isDark = theme.brightness == Brightness.dark;
                      final borderColor = isDark 
                          ? theme.colorScheme.outline.withOpacity(0.3)
                          : Colors.grey[300]!;
                      
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
                          child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(profileImageUrl),
                                  onBackgroundImageError: (_, __) {},
                                  backgroundColor: isAdmin 
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                                  radius: 18,
                                )
                              : CircleAvatar(
                                  backgroundColor: isAdmin 
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                                  radius: 18,
                                  child: Icon(
                                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                                    color: isAdmin ? Colors.blue : Colors.grey[700],
                                    size: 16,
                                  ),
                                ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isAdmin 
                                  ? Colors.blue.withOpacity(0.12)
                                  : Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isAdmin 
                                    ? Colors.blue.withOpacity(0.4)
                                    : Colors.grey.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              isAdmin ? 'Admin' : 'User',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isAdmin ? Colors.blue : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          if (userEmail.isNotEmpty)
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(timestamp, loginDateStr),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                          isThreeLine: true,
                        ),
                      ),
                    );
                    },
                  );
                },
              );
            },
          );
        },
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
            _searchQueryNotifier.value = v.trim().toLowerCase();
          },
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, color: iconColor),
            hintText: 'Search by name or email...',
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

  Widget _buildFilterChips() {
    return Row(
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _selectedFilter == 'all',
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedFilter = 'all');
            }
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Users'),
          selected: _selectedFilter == 'user',
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedFilter = 'user');
            }
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Admins'),
          selected: _selectedFilter == 'admin',
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedFilter = 'admin');
            }
          },
        ),
      ],
    );
  }
}

