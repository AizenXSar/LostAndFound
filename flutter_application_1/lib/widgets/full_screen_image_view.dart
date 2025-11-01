import 'package:flutter/material.dart';

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageView({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
