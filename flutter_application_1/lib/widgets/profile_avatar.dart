import 'package:flutter/material.dart';

/// A reusable profile avatar widget with a green online indicator
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? displayName;
  final Widget? child;
  final ImageProvider? backgroundImage;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.radius = 18,
    this.displayName,
    this.child,
    this.backgroundImage,
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
          onBackgroundImageError: (_, __) {},
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
        // Green indicator - larger size similar to profile screen
        Positioned(
          right: -1, // Slightly outside for better visibility
          bottom: -1,
          child: Container(
            // For larger avatars (radius >= 30), use ~18px like profile screen
            // For smaller avatars, use proportionally larger indicator
            width: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
            height: radius >= 30 ? 18.0 : (radius * 0.55).clamp(12.0, 18.0),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

