import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';

import 'text_format_panel.dart';
import 'note.dart';
import 'note_provider.dart';
import 'camera_gallery_widget.dart';

/// ===== Modelos locales =====
class FloatingText {
  String text;
  double x;
  double y;
  double width;
  bool bold;
  bool underline;
  int? underlineColor;
  bool highlight;
  int? highlightColor;
  bool isLocked;
  double fontSize;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    this.width = 200.0,
    this.bold = false,
    this.underline = false,
    this.underlineColor,
    this.highlight = false,
    this.highlightColor,
    this.isLocked = false,
    this.fontSize = 16.0,
  });
}

class FloatingImage {
  String filePath;
  double x;
  double y;
  double width;
  double height;
  bool isLocked;

  FloatingImage({
    required this.filePath,
    required this.x,
    required this.y,
    this.width = 180.0,
    this.height = 140.0,
    this.isLocked = false,
  });
}

/// ===== Rejilla elegante (mayor/menor) =====
class _ElegantGridPainter extends CustomPainter {
  final double minorStep; // tamaño cuadrito
  final int majorEvery; // cada cuántos menores hay una mayor
  final Color minorColor;
  final Color majorColor;

  _ElegantGridPainter({
    this.minorStep = 60,
    this.majorEvery = 5,
    this.minorColor = const Color(0x22000000), // ~13% opaco
    this.majorColor = const Color(0x33000000), // ~20% opaco
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = minorColor
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = majorColor
      ..strokeWidth = 1.2;

    // Verticales
    int i = 0;
    for (double x = 0; x <= size.width; x += minorStep, i++) {
      final isMajor = i % majorEvery == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          isMajor ? majorPaint : minorPaint);
    }
    // Horizontales
    int j = 0;
    for (double y = 0; y <= size.height; y += minorStep, j++) {
      final isMajor = j % majorEvery == 0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          isMajor ? majorPaint : minorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ElegantGridPainter old) =>
      old.minorStep != minorStep ||
      old.majorEvery != majorEvery ||
      old.minorColor != minorColor ||
      old.majorColor != majorColor;
}

class FreeCanvasScreen extends StatefulWidget {
  final Note note;
  const FreeCanvasScreen({Key? key, required this.note}) : super(key: key);
  @override
  State<FreeCanvasScreen> createState() => _FreeCanvasScreenState();
}

class _FreeCanvasScreenState extends State<FreeCanvasScreen>
    with TickerProviderStateMixin {
  // ===== Zoom / Pan =====
  late TransformationController _transformationController;
  double _zoom = 1.0;
  final double _minZoom = 0.3;
  final double _maxZoom = 3.0;

  // Tamaño base del tablero (se ajusta dinámicamente según viewport para cubrir pantalla aún en minZoom)
  double _canvasWidth = 4000;
  double _canvasHeight = 3000;

  // Encabezado
  final TextEditingController _titleController = TextEditingController();

  // Párrafos como nodos
  final List<TextEditingController> _paragraphControllers = [];

  // Posiciones persistentes
  final Map<String, Offset> _elementPositions = {};

  // Flotantes
  final List<FloatingImage> _floatingImages = [];
  final List<FloatingText> _floatingTexts = [];

  // UI state
  bool _hasUnsavedChanges = false;
  late AnimationController _blinkAnimationController;
  late Animation<double> _blinkAnimation;
  bool _showFormatPanel = false;

  // Color de fondo (nota)
  Color _noteColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();

    _noteColor = widget.note.color;
    _normalizeNoteParagraphs();
    _pullFromNoteToControllers();
    _loadFloatingElements();
    _loadElementPositions();

    _blinkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkAnimationController, curve: Curves.ease),
    );

    _titleController.addListener(_onTitleChanged);
    for (int i = 0; i < _paragraphControllers.length; i++) {
      _paragraphControllers[i].addListener(() => _onParagraphChanged(i));
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _titleController.dispose();
    for (final c in _paragraphControllers) {
      c.dispose();
    }
    _blinkAnimationController.dispose();
    super.dispose();
  }

  // ===== Normaliza: cada contentPart sin '\n' =====
  void _normalizeNoteParagraphs() {
    final List<Map<String, dynamic>> normalized = [];
    for (final part in widget.note.contentParts) {
      final type = part['type'] ?? 'text';
      final textRaw = (part['text'] ?? '').toString();
      if (type == 'text' && textRaw.contains('\n')) {
        final lines = textRaw.split('\n');
        for (final ln in lines) {
          normalized.add({'type': 'text', 'text': ln});
        }
      } else {
        normalized.add({'type': type, 'text': textRaw});
      }
    }
    widget.note.contentParts = normalized;
    Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
  }

  void _pullFromNoteToControllers() {
    _titleController.text = widget.note.title;
    _paragraphControllers.clear();
    for (final part in widget.note.contentParts) {
      final text = (part['text'] ?? '').toString();
      _paragraphControllers.add(TextEditingController(text: text));
    }
  }

  void _loadElementPositions() {
    final data = widget.note.freeCanvasData;
    if (data is Map<String, dynamic>) {
      if (data['canvasSize'] is Map) {
        final sz = data['canvasSize'] as Map<String, dynamic>;
        _canvasWidth = (sz['w'] ?? _canvasWidth).toDouble();
        _canvasHeight = (sz['h'] ?? _canvasHeight).toDouble();
      }
      if (data['positions'] is Map) {
        final pos = data['positions'] as Map<String, dynamic>;
        pos.forEach((k, v) {
          if (v is Map) {
            _elementPositions[k] = Offset(
              (v['x'] ?? 0).toDouble(),
              (v['y'] ?? 0).toDouble(),
            );
          }
        });
      }
    }
    // Defaults
    _elementPositions.putIfAbsent('title', () => const Offset(80, 80));
    for (int i = 0; i < _paragraphControllers.length; i++) {
      _elementPositions.putIfAbsent('p_$i', () => Offset(80, 180 + i * 80));
    }
  }

  void _saveCanvasData() {
    final positions = _elementPositions.map(
      (k, o) => MapEntry(k, {'x': o.dx, 'y': o.dy}),
    );
    widget.note.freeCanvasData = {
      'positions': positions,
      'lastModified': DateTime.now().toIso8601String(),
      'canvasSize': {'w': _canvasWidth, 'h': _canvasHeight},
    };
    Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
  }

  void _onTitleChanged() {
    widget.note.title = _titleController.text;
    _markDirtyAndPersist();
  }

  void _onParagraphChanged(int index) {
    if (index < 0 || index >= widget.note.contentParts.length) return;
    widget.note.contentParts[index]['text'] = _paragraphControllers[index].text;
    _markDirtyAndPersist();
  }

  void _markDirtyAndPersist() {
    setState(() => _hasUnsavedChanges = true);
    Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
  }

  void _loadFloatingElements() {
    _floatingImages.clear();
    for (var imgData in widget.note.floatingImages) {
      _floatingImages.add(FloatingImage(
        filePath: imgData['path'] ?? '',
        x: (imgData['x'] ?? 0).toDouble(),
        y: (imgData['y'] ?? 0).toDouble(),
        width: (imgData['width'] ?? 180).toDouble(),
        height: (imgData['height'] ?? 140).toDouble(),
        isLocked: imgData['isLocked'] ?? false,
      ));
    }
    _floatingTexts.clear();
    for (var textData in widget.note.floatingTexts) {
      _floatingTexts.add(FloatingText(
        text: textData['text'] ?? '',
        x: (textData['x'] ?? 0).toDouble(),
        y: (textData['y'] ?? 0).toDouble(),
        width: (textData['width'] ?? 220).toDouble(),
        bold: textData['bold'] ?? false,
        underline: textData['underline'] ?? false,
        underlineColor: textData['underlineColor'],
        highlight: textData['highlight'] ?? false,
        highlightColor: textData['highlightColor'],
        isLocked: textData['isLocked'] ?? false,
        fontSize: (textData['fontSize'] ?? 16.0).toDouble(),
      ));
    }
    for (int i = 0; i < _floatingImages.length; i++) {
      _elementPositions.putIfAbsent('floating_img_$i',
          () => Offset(_floatingImages[i].x, _floatingImages[i].y));
    }
    for (int i = 0; i < _floatingTexts.length; i++) {
      _elementPositions.putIfAbsent('floating_text_$i',
          () => Offset(_floatingTexts[i].x, _floatingTexts[i].y));
    }
  }

  // ===== Zoom helpers =====
  void _setZoom(double v) {
    setState(() => _zoom = v);
    _transformationController.value = Matrix4.identity()..scale(_zoom);
  }

  void _fitToScreen() {
    setState(() => _zoom = 1.0);
    _transformationController.value = Matrix4.identity()..scale(_zoom);
  }

  @override
  Widget build(BuildContext context) {
    const double _bottomBarHeight = 72.0;

    return Scaffold(
      backgroundColor: _noteColor,
      appBar: AppBar(
        backgroundColor: _noteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Text('⬅️',
              style: TextStyle(fontSize: 24, color: Colors.black)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '🎨 Modo Libre',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AnimatedBuilder(
              animation: _blinkAnimationController,
              builder: (context, child) {
                return IconButton(
                  icon: Opacity(
                    opacity: _hasUnsavedChanges ? 0.6 : 1.0,
                    child: const Text('💾', style: TextStyle(fontSize: 26)),
                  ),
                  tooltip: 'Guardar',
                  onPressed: () {
                    setState(() => _hasUnsavedChanges = false);
                    _saveCanvasData();
                  },
                );
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'share_text',
                  child: Row(children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Compartir como texto')
                  ])),
              const PopupMenuItem(
                  value: 'save_pdf',
                  child: Row(children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Guardar como PDF')
                  ])),
              const PopupMenuItem(
                  value: 'change_color',
                  child: Row(children: [
                    Icon(Icons.palette),
                    SizedBox(width: 8),
                    Text('Cambiar color')
                  ])),
            ],
          ),
        ],
      ),

      /// === El truco para que la rejilla cubra toda la pantalla incluso con zoom mínimo:
      /// usamos LayoutBuilder para conocer el viewport y forzar un canvas mínimo
      /// de (viewport / _minZoom) + margen.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double minCanvasW = constraints.maxWidth / _minZoom + 200;
          final double minCanvasH = constraints.maxHeight / _minZoom + 200;
          final double canvasW = max(_canvasWidth, minCanvasW);
          final double canvasH = max(_canvasHeight, minCanvasH);

          return Stack(
            children: [
              InteractiveViewer(
                constrained: false, // Permite que el child use su propio tamaño
                minScale: _minZoom,
                maxScale: _maxZoom,
                panEnabled: true,
                scaleEnabled: true,
                transformationController: _transformationController,
                child: SizedBox(
                  width: canvasW,
                  height: canvasH,
                  child: Stack(
                    children: [
                      // Rejilla elegante
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ElegantGridPainter(
                            minorStep: 60, // más cuadriculada
                            majorEvery: 5, // línea mayor cada 5
                            minorColor:
                                const Color(0x22000000), // +opaca pero sobria
                            majorColor: const Color(0x33000000),
                          ),
                        ),
                      ),

                      // Encabezado movible
                      _buildMovable(
                        keyId: 'title',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: TextField(
                            controller: _titleController,
                            style: TextStyle(
                              fontSize: widget.note.titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Encabezado',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),

                      // Párrafos como nodos
                      ..._buildParagraphNodes(),

                      // Flotantes
                      ..._buildFloatingImages(),
                      ..._buildFloatingTexts(),

                      // Panel ABC
                      if (_showFormatPanel) _buildFormatPanel(),
                    ],
                  ),
                ),
              ),

              // Slider de zoom + fit
              Positioned(
                top: 8,
                left: 12,
                right: 80,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: _setZoom,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ajustar',
                      icon: const Icon(Icons.fullscreen),
                      onPressed: _fitToScreen,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // Bottom bar (ABC + Cámara)
      bottomNavigationBar: SafeArea(
        child: Container(
          height: _bottomBarHeight,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _iconBox(
                icon: Image.asset('assets/abc.png', width: 32, height: 32),
                onTap: () =>
                    setState(() => _showFormatPanel = !_showFormatPanel),
              ),
              _iconBox(
                icon: Image.asset('assets/camara.png', width: 32, height: 32),
                onTap: _openGalleryImage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Párrafos (nodos movibles) =====
  List<Widget> _buildParagraphNodes() {
    final widgets = <Widget>[];
    for (int i = 0; i < _paragraphControllers.length; i++) {
      final keyId = 'p_$i';
      final pos = _elementPositions[keyId] ?? Offset(80, 180 + i * 80.0);

      widgets.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _elementPositions[keyId] = pos + details.delta;
              });
              _saveCanvasData();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: TextField(
                controller: _paragraphControllers[i],
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontSize: widget.note.contentFontSize,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // ===== Genérico movible =====
  Widget _buildMovable({required String keyId, required Widget child}) {
    final pos = _elementPositions[keyId] ?? const Offset(80, 80);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() => _elementPositions[keyId] = pos + d.delta);
          _saveCanvasData();
        },
        child: child,
      ),
    );
  }

  // ===== Menú superior =====
  void _handleMenuAction(String action) {
    switch (action) {
      case 'share_text':
        final text = [
          _titleController.text,
          ..._paragraphControllers.map((c) => c.text),
        ].join('\n\n');
        Share.share(text);
        break;
      case 'save_pdf':
        // TODO: Implementar PDF si lo necesitas
        break;
      case 'change_color':
        _pickBackgroundColor();
        break;
    }
  }

  Future<void> _pickBackgroundColor() async {
    final colors = <Color>[
      Colors.white,
      const Color(0xFFFFFBF2),
      const Color(0xFFF5F5F5),
      const Color(0xFFEFF7FF),
      const Color(0xFFFFF0F6),
    ];
    final selected = await showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Color de fondo'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in colors)
              GestureDetector(
                onTap: () => Navigator.pop(context, c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _noteColor = selected);
      widget.note.color = selected;
      Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
    }
  }

  // ===== Cámara/Galería =====
  Future<void> _openGalleryImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final newImg = FloatingImage(
        filePath: picked.path,
        x: 320 + (_floatingImages.length * 30).toDouble(),
        y: 320 + (_floatingImages.length * 20).toDouble(),
      );

      setState(() {
        _floatingImages.add(newImg);
        final idx = _floatingImages.length - 1;
        _elementPositions['floating_img_$idx'] = Offset(newImg.x, newImg.y);
        widget.note.floatingImages.add({
          'path': newImg.filePath,
          'x': newImg.x,
          'y': newImg.y,
          'width': newImg.width,
          'height': newImg.height,
          'isLocked': false,
        });
      });
      _saveCanvasData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agregar la imagen: $e')));
    }
  }

  // ===== Render flotantes =====
  List<Widget> _buildFloatingImages() {
    final w = <Widget>[];
    for (int i = 0; i < _floatingImages.length; i++) {
      final img = _floatingImages[i];
      final keyId = 'floating_img_$i';
      final pos = _elementPositions[keyId] ?? Offset(img.x, img.y);

      w.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onPanUpdate: img.isLocked
                ? null
                : (d) {
                    setState(() => _elementPositions[keyId] = pos + d.delta);
                    _saveCanvasData();
                  },
            child: Container(
              width: img.width,
              height: img.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: img.isLocked ? Colors.red : Colors.black12,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4)
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(img.filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return w;
  }

  List<Widget> _buildFloatingTexts() {
    final w = <Widget>[];
    for (int i = 0; i < _floatingTexts.length; i++) {
      final t = _floatingTexts[i];
      final keyId = 'floating_text_$i';
      final pos = _elementPositions[keyId] ?? Offset(t.x, t.y);

      w.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onPanUpdate: t.isLocked
                ? null
                : (d) {
                    setState(() => _elementPositions[keyId] = pos + d.delta);
                    _saveCanvasData();
                  },
            child: Container(
              width: t.width,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (t.highlight && t.highlightColor != null)
                    ? Color(t.highlightColor!).withOpacity(0.25)
                    : Colors.yellow.withOpacity(0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: t.isLocked ? Colors.red : Colors.transparent,
                ),
              ),
              child: Text(
                t.text,
                style: TextStyle(
                  fontSize: t.fontSize,
                  fontWeight: t.bold ? FontWeight.bold : FontWeight.normal,
                  decoration: t.underline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: t.underlineColor != null
                      ? Color(t.underlineColor!)
                      : null,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return w;
  }

  // ===== Helpers UI =====
  Widget _iconBox({required Widget icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  Widget _buildFormatPanel() {
    return Positioned(
      right: 20,
      top: 120,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Formato',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Negrita',
                  icon: const Icon(Icons.format_bold),
                  onPressed: () {},
                ),
                IconButton(
                  tooltip: 'Cursiva',
                  icon: const Icon(Icons.format_italic),
                  onPressed: () {},
                ),
                IconButton(
                  tooltip: 'Subrayado',
                  icon: const Icon(Icons.format_underlined),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
