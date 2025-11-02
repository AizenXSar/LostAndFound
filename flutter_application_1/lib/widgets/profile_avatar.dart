import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A reusable profile avatar widget with a green online indicator
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? displayName;
  final Widget? child;
  final ImageProvider? backgroundImage;
  final bool showOnlineIndicator;
  final String? userId; // User ID to check online status from Firestore

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.radius = 18,
    this.displayName,
    this.child,
    this.backgroundImage,
    this.showOnlineIndicator = true,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundImage: backgroundImage ?? 
              (imageUrl != null && imageUrl!.isNotEmpty
                  ? NetworkImage(imageUrl!)
                  : null),
          onBackgroundImageError: backgroundImage != null || (imageUrl != null && imageUrl!.isNotEmpty)
              ? (_, __) {}
              : null,
          child: child ??
              (imageUrl == null || imageUrl!.isEmpty
                  ? (displayName != null && displayName!.isNotEmpty
                      ? Text(
                          displayName![0].toUpperCase(),
                          style: TextStyle(
                            fontSize: radius * 0.9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Icon(Icons.person, size: radius))
                  : null),
        ),
        // Green indicator - only show if user is online
        if (showOnlineIndicator)
          _OnlineIndicator(
            userId: userId,
            radius: radius,
          ),
      ],
    );
  }
}

/// Widget that checks online status from Firestore and shows green indicator
class _OnlineIndicator extends StatelessWidget {
  final String? userId;
  final double radius;

  const _OnlineIndicator({
    this.userId,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // If no userId provided, show gray indicator (offline by default)
    if (userId == null || userId!.isEmpty) {
      return Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
          height: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, // Lighter gray in dark mode for visibility
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.scaffoldBackgroundColor,
              width: 2.5,
            ),
            boxShadow: isDark ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ] : null,
          ),
        ),
      );
    }

    // Stream builder to listen to user's online status from Firestore
    // Check both users and admins collections
    final usersStream = FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
    final adminsStream = FirebaseFirestore.instance.collection('admins').doc(userId).snapshots();
    
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, userSnap) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        // Determine colors based on theme (declare early so both branches can use them)
        final onlineColor = isDark ? Colors.green.shade400 : Colors.green;
        final offlineColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
        
        bool isOnline = false;
        bool foundInUsers = false;
        
        if (userSnap.hasData && userSnap.data!.exists) {
          foundInUsers = true;
          final userData = userSnap.data!.data();
          // Default to false (offline/gray) if isOnline field doesn't exist
          isOnline = (userData?['isOnline'] as bool?) ?? false;
        } else {
          // If document doesn't exist, default to offline (gray)
          isOnline = false;
        }
        
        // If not found in users, check admins collection
        if (!foundInUsers) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: adminsStream,
            builder: (context, adminSnap) {
              if (adminSnap.hasData && adminSnap.data!.exists) {
                final adminData = adminSnap.data!.data();
                // Default to false (offline/gray) if isOnline field doesn't exist
                isOnline = (adminData?['isOnline'] as bool?) ?? false;
              } else {
                // If document doesn't exist, default to offline (gray)
                isOnline = false;
              }
              
              // Always show indicator - green if online, gray if offline
              return Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
                  height: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
                  decoration: BoxDecoration(
                    color: isOnline ? onlineColor : offlineColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                    boxShadow: isDark ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
              );
            },
          );
        }
        
        // Always show indicator - green if online, gray if offline
        return Positioned(
          right: -1, // Slightly outside for better visibility
          bottom: -1,
          child: Container(
            // For larger avatars (radius >= 30), use ~18px like profile screen
            // For smaller avatars, use proportionally larger indicator
            width: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
            height: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
            decoration: BoxDecoration(
              color: isOnline ? onlineColor : offlineColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.scaffoldBackgroundColor,
                width: 2.5,
              ),
              boxShadow: isDark ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
        );
      },
    );
  }
}

