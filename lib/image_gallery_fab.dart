import 'dart:async';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_io/io.dart' show File, Directory;

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

/// Modelo de imagen
class _ImageInfo {
  final File file;
  final DateTime date;
  final String originalName;

  _ImageInfo({
    required this.file,
    required this.date,
    required this.originalName,
  });
}

class ImageButton extends StatefulWidget {
  final String noteId;
  const ImageButton({Key? key, required this.noteId}) : super(key: key);

  @override
  State<ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  final ImagePicker _picker = ImagePicker();

  List<_ImageInfo> _imageFiles = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadImageFiles();
  }

  Future<void> _loadImageFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final noteDir = Directory('${dir.path}/images_${widget.noteId}');
    final List<_ImageInfo> images = [];

    if (await noteDir.exists()) {
      for (final file in noteDir.listSync().whereType<File>()) {
        if (file.path.toLowerCase().endsWith('.jpg') ||
            file.path.toLowerCase().endsWith('.jpeg') ||
            file.path.toLowerCase().endsWith('.png')) {
          // Intentar leer metadatos
          final metaFile = File(file.path + '.json');
          String originalName = 'Imagen';
          DateTime date = file.lastModifiedSync();

          if (await metaFile.exists()) {
            try {
              final meta = await metaFile.readAsString();
              final parts = meta.split('|');
              date = DateTime.tryParse(parts[0]) ?? date;
              originalName = parts.length > 1 ? parts[1] : originalName;
            } catch (e) {
              // Si falla la lectura de metadatos, usar valores por defecto
            }
          }

          images.add(
            _ImageInfo(file: file, date: date, originalName: originalName),
          );
        }
      }
    }

    // Ordenar por fecha (más reciente primero)
    images.sort((a, b) => b.date.compareTo(a.date));
    setState(() => _imageFiles = images);
  }

  Future<void> _takePhotoOrGallery() async {
    // Mostrar opciones de cámara o galería
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                _OptionButton(
                  icon: Icons.camera_alt,
                  label: 'Tomar foto',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                  color: Colors.blue,
                ),
                const SizedBox(height: 14),
                _OptionButton(
                  icon: Icons.photo_library,
                  label: 'Elegir de galería',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _saveImage(File(pickedFile.path), pickedFile.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al obtener imagen: $e')));
      }
    }
  }

  Future<void> _saveImage(File sourceFile, String originalName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final noteDir = Directory('${dir.path}/images_${widget.noteId}');

      if (!await noteDir.exists()) {
        await noteDir.create(recursive: true);
      }

      // Crear nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalName.split('.').last.toLowerCase();
      final newFileName = '$timestamp.$extension';
      final destinationFile = File('${noteDir.path}/$newFileName');

      // Copiar archivo
      await sourceFile.copy(destinationFile.path);

      // Guardar metadatos
      final metaFile = File('${destinationFile.path}.json');
      await metaFile.writeAsString(
        '${DateTime.now().toIso8601String()}|$originalName',
      );

      // Recargar lista de imágenes
      await _loadImageFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Imagen guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar imagen: $e')));
      }
    }
  }

  Future<void> _deleteImage(_ImageInfo image) async {
    try {
      if (await image.file.exists()) await image.file.delete();
      final metaFile = File(image.file.path + '.json');
      if (await metaFile.exists()) await metaFile.delete();
      await _loadImageFiles();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error eliminando imagen: $e')));
      }
    }
  }

  void _showImageGallery() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              color: const Color(0xFFF8F3E8),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Text(
                          'Galería Personal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_imageFiles.length} imágenes',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de imágenes
                  Expanded(
                    child: _imageFiles.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay imágenes guardadas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Usa el botón de cámara para agregar imágenes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _imageFiles.length,
                            itemBuilder: (context, index) {
                              final image = _imageFiles[index];
                              return _buildImageCard(image, setModalState);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageCard(_ImageInfo image, StateSetter setModalState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.file(
                image.file,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Información y botones
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image.originalName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(image.date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botón ver
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showFullImage(image),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 14,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Ver',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón eliminar
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: const Text("¿Eliminar imagen?"),
                            content: const Text(
                              "Esta acción no se puede deshacer.",
                            ),
                            actions: [
                              TextButton(
                                child: const Text("Cancelar"),
                                onPressed: () => Navigator.of(ctx).pop(false),
                              ),
                              TextButton(
                                child: const Text(
                                  "Eliminar",
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _deleteImage(image);
                          setModalState(() {}); // refresca
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(_ImageInfo image) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Fondo negro semitransparente
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  color: Colors.black87,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              // Imagen centrada
              Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(image.file, fit: BoxFit.contain),
                  ),
                ),
              ),
              // Botón cerrar
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón superior: Tomar foto/Galería
        FloatingActionButton(
          heroTag: "camera_btn_${widget.noteId}",
          backgroundColor: Colors.white,
          onPressed: _takePhotoOrGallery,
          child: const Text('📸', style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(height: 12),
        // Botón inferior: Galería personal
        FloatingActionButton(
          heroTag: "gallery_btn_${widget.noteId}",
          backgroundColor: Colors.white,
          onPressed: _showImageGallery,
          child: const Text(
            '🖼️',
            style: TextStyle(fontSize: 24, color: Colors.blueAccent),
          ),
        ),
      ],
    );
  }
}

// Widget auxiliar para botones de opciones
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

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
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
