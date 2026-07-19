import "dart:typed_data";
import "package:crop_your_image/crop_your_image.dart";
import "package:flutter/material.dart";

class CropPhotoScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const CropPhotoScreen({super.key, required this.imageBytes});

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop photo"),
        actions: [
          IconButton(
            onPressed: _isCropping ? null : () {
              setState(() => _isCropping = true);
              _controller.crop();
            },
            icon: const Icon(Icons.check),
            tooltip: "Done",
          ),
        ],
      ),
      body: Crop(
        controller: _controller,
        image: widget.imageBytes,
        // Circular guide only — matches how the photo will actually be
        // displayed (CircleAvatar), but the saved crop stays a square image
        // so it also looks right in non-circular previews.
        withCircleUi: true,
        baseColor: Colors.black,
        maskColor: Colors.black.withValues(alpha: 0.6),
        onCropped: (croppedData) {
          if (!mounted) return;
          Navigator.of(context).pop(croppedData);
        },
      ),
    );
  }
}
