import "dart:convert";
import "dart:typed_data";
import "package:flutter/material.dart";

void showFoodPhotoViewer(BuildContext context, String photoBase64) {
  final bytes = base64Decode(photoBase64);
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: animation,
        child: _PhotoViewerScreen(imageBytes: bytes),
      ),
    ),
  );
}

class _PhotoViewerScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const _PhotoViewerScreen({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.memory(imageBytes),
              ),
            ),
            SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
