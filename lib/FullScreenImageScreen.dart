import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImageScreen extends StatelessWidget {
  final String imagePath;

  const FullScreenImageScreen({Key? key, required this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: PhotoView(
        imageProvider: AssetImage(imagePath),
        enableRotation: true, // Enable mouse wheel zoom
        // Add other PhotoView properties as needed
        // e.g., minScale, maxScale, initialScale, etc.
      ),
    );
  }
}