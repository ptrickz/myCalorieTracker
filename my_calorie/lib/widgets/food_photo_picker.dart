import "dart:convert";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "../screens/crop_photo_screen.dart";
import "../theme.dart";

class FoodPhotoPicker extends StatelessWidget {
  final String? photoBase64;
  final ValueChanged<String?> onChanged;

  const FoodPhotoPicker({super.key, required this.photoBase64, required this.onChanged});

  Future<void> _pickPhoto(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;

    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropPhotoScreen(imageBytes: bytes)),
    );
    if (cropped == null) return;

    onChanged(base64Encode(cropped));
  }

  @override
  Widget build(BuildContext context) {
    final bytes = photoBase64 == null ? null : base64Decode(photoBase64!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _pickPhoto(context),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              image: bytes != null ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover) : null,
            ),
            child: bytes == null
                ? const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => _pickPhoto(context),
                child: Text(bytes == null ? "Add photo" : "Change photo"),
              ),
              if (bytes != null)
                TextButton(
                  onPressed: () => onChanged(null),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text("Remove"),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
