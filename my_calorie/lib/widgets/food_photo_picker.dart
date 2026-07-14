import "dart:convert";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "../theme.dart";

class FoodPhotoPicker extends StatelessWidget {
  final String? photoBase64;
  final ValueChanged<String?> onChanged;

  const FoodPhotoPicker({super.key, required this.photoBase64, required this.onChanged});

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 70,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    onChanged(base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final bytes = photoBase64 == null ? null : base64Decode(photoBase64!);

    return Row(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
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
        TextButton(
          onPressed: _pickPhoto,
          child: Text(bytes == null ? "Add photo" : "Change photo"),
        ),
        if (bytes != null)
          TextButton(
            onPressed: () => onChanged(null),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Remove"),
          ),
      ],
    );
  }
}
