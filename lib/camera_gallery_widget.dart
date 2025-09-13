import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraGalleryWidget extends StatefulWidget {
  const CameraGalleryWidget({Key? key}) : super(key: key);

  @override
  State<CameraGalleryWidget> createState() => _CameraGalleryWidgetState();
}

class _CameraGalleryWidgetState extends State<CameraGalleryWidget> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.80),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IconTextButton(
                icon: Icons.camera_alt,
                label: 'Tomar Foto',
                onTap: () => _pickImage(ImageSource.camera),
                color: theme.primaryColor,
              ),
              const SizedBox(height: 18),
              _IconTextButton(
                icon: Icons.photo_library,
                label: 'Galería',
                onTap: () => _pickImage(ImageSource.gallery),
                color: theme.primaryColor,
              ),
              if (_image != null) ...[
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, height: 120, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
      );
  }
}

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _IconTextButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
