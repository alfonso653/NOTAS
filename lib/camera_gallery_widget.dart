import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CameraGalleryWidget extends StatefulWidget {
  const CameraGalleryWidget({Key? key}) : super(key: key);

  @override
  State<CameraGalleryWidget> createState() => _CameraGalleryWidgetState();
}

class _CameraGalleryWidgetState extends State<CameraGalleryWidget> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      _image = File(picked.path);
      // Devolvemos la imagen seleccionada y cerramos el modal
      Navigator.of(context).pop(_image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconTextButton(
              icon: Icons.camera_alt,
              label: 'Tomar foto',
              onTap: () => _pickImage(ImageSource.camera),
              color: theme.primaryColor,
            ),
            const SizedBox(height: 14),
            _IconTextButton(
              icon: Icons.photo_library,
              label: 'Elegir de galería',
              onTap: () => _pickImage(ImageSource.gallery),
              color: theme.primaryColor,
            ),
            const SizedBox(height: 8),
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
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
