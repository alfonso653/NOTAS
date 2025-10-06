// (Declaración de _dropInsertIndex movida a la clase correspondiente)
import 'dart:async'; // Para Timer
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';

import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/rendering.dart'; // Para RenderRepaintBoundary
import 'dart:ui' as ui; // Para ui.Image y ImageByteFormat
import 'dart:typed_data';
import 'dart:io';
import 'dart:math'; // Para cos y sin del menú en abanico
// import 'dart:convert';

import 'text_format_panel.dart';
import 'note.dart';
import 'note_provider.dart';
import 'audio_mic_fab.dart';
import 'camera_gallery_widget.dart';
import 'mindmap_test_screen.dart';
import 'mindmap_from_note_screen.dart';

/// =========================
/// Modelo de segmento (_TextPart)
/// =========================
class _TextPart {
  final String text;
  final bool bold;
  final bool underline;
  final int? underlineColor;
  final bool highlight;
  final int? highlightColor;

  // Extensiones para imágenes incrustadas (ya no se usan para pintar)
  final bool isImage;
  final double? imageWidth;
  final double? imageHeight;

  const _TextPart(
    this.text,
    this.bold, [
    this.underline = false,
    this.underlineColor,
    this.highlight = false,
    this.highlightColor,
    this.isImage = false,
    this.imageWidth,
    this.imageHeight,
  ]);

  Map<String, dynamic> toJson() => {
        'text': text,
        'bold': bold,
        'underline': underline,
        'underlineColor': underlineColor,
        'highlight': highlight,
        'highlightColor': highlightColor,
        'isImage': isImage,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
      };

  factory _TextPart.fromJson(Map<String, dynamic> json) => _TextPart(
        (json['text'] ?? '') as String,
        (json['bold'] ?? false) as bool,
        (json['underline'] ?? false) as bool,
        json['underlineColor'] == null
            ? null
            : (json['underlineColor'] as num).toInt(),
        (json['highlight'] ?? false) as bool,
        json['highlightColor'] == null
            ? null
            : (json['highlightColor'] as num).toInt(),
        (json['isImage'] ?? false) as bool,
        json['imageWidth'] == null
            ? null
            : (json['imageWidth'] as num).toDouble(),
        json['imageHeight'] == null
            ? null
            : (json['imageHeight'] as num).toDouble(),
      );
}

/// Modelo para trazos de dibujo libre
class DrawingStroke {
  final List<Offset>
      points; // Coordenadas en el espacio del CONTENIDO (y = yVisible + scroll)
  final Color color;
  final double strokeWidth;
  final String toolType; // 'pencil', 'pen', 'crayon', 'brush'

  const DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.toolType,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.value,
        'strokeWidth': strokeWidth,
        'toolType': toolType,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
        points: (json['points'] as List)
            .map((p) => Offset(
                (p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
            .toList(),
        color: Color(json['color'] as int),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        toolType: json['toolType'] as String,
      );
}

/// CustomPainter para renderizar los trazos de dibujo libre
class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  /// scrollOffset: cuánto ha avanzado el ListView (para desplazar el lienzo de visualización)
  final double scrollOffset;

  DrawingPainter({
    required this.strokes,
    this.currentStroke,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Limitar a la zona visible del overlay (área de contenido)
    canvas.clipRect(Offset.zero & size);

    // Convertir espacio de CONTENIDO -> espacio del OVERLAY visible
    // (yVisible = yContenido - scroll)
    canvas.save();
    canvas.translate(0, -scrollOffset);

    // Dibujar todos los trazos completados
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Dibujar el trazo actual (en progreso)
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    switch (stroke.toolType) {
      case 'pencil':
        _drawPencilStroke(canvas, stroke);
        break;
      case 'pen':
        _drawPenStroke(canvas, stroke);
        break;
      case 'crayon':
        _drawCrayonStroke(canvas, stroke);
        break;
      case 'brush':
        _drawBrushStroke(canvas, stroke);
        break;
    }
  }

  // ✏️ Lápiz - Trazo suave y uniforme
  void _drawPencilStroke(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color.withOpacity(0.8)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (stroke.points.isNotEmpty) {
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  // 🖊️ Lapicero - Trazo elegante y definido con brillo
  void _drawPenStroke(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (stroke.points.isNotEmpty) {
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);

      // Efecto de brillo interno
      final highlightPaint = Paint()
        ..color = stroke.color.withOpacity(0.3)
        ..strokeWidth = stroke.strokeWidth * 0.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, highlightPaint);
    }
  }

  // 🖍️ Crayola - Efecto punteado/granulado
  void _drawCrayonStroke(Canvas canvas, DrawingStroke stroke) {
    final random = Random(42); // Seed fijo para consistencia

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final start = stroke.points[i];
      final end = stroke.points[i + 1];

      for (double t = 0; t <= 1.0; t += 0.02) {
        final point = Offset.lerp(start, end, t)!;

        final offsetX = (random.nextDouble() - 0.5) * stroke.strokeWidth * 0.5;
        final offsetY = (random.nextDouble() - 0.5) * stroke.strokeWidth * 0.5;
        final randomPoint = point + Offset(offsetX, offsetY);

        final paint = Paint()
          ..color = stroke.color.withOpacity(random.nextDouble() * 0.4 + 0.6)
          ..style = PaintingStyle.fill;

        final radius = stroke.strokeWidth * (0.1 + random.nextDouble() * 0.2);
        canvas.drawCircle(randomPoint, radius, paint);
      }
    }
  }

  // 🖌️ Pincel - Efecto acuarela
  void _drawBrushStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.length < 2) return;

    final layers = [
      {'opacity': 0.15, 'width': stroke.strokeWidth * 2.0},
      {'opacity': 0.25, 'width': stroke.strokeWidth * 1.5},
      {'opacity': 0.4, 'width': stroke.strokeWidth * 1.0},
      {'opacity': 0.6, 'width': stroke.strokeWidth * 0.7},
    ];

    for (final layer in layers) {
      final paint = Paint()
        ..color = stroke.color.withOpacity(layer['opacity'] as double)
        ..strokeWidth = layer['width'] as double
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        if (i == stroke.points.length - 1) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        } else {
          final current = stroke.points[i];
          final next = stroke.points[i + 1];
          final controlPoint = Offset(
            (current.dx + next.dx) / 2,
            (current.dy + next.dy) / 2,
          );
          path.quadraticBezierTo(
              current.dx, current.dy, controlPoint.dx, controlPoint.dy);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter old) {
    // OPTIMIZACIÓN: Comparaciones más eficientes
    if (old.scrollOffset != scrollOffset) return true;
    if (old.currentStroke != currentStroke) return true;
    if (old.strokes.length != strokes.length) return true;
    return false;
  }
}

/// Imágenes flotantes (superpuestas al contenido)
class FloatingImage {
  String filePath;
  double x;
  double y;
  double width;
  double height;
  bool isLocked; // 🔒 Nueva propiedad para bloquear movimiento

  FloatingImage({
    required this.filePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isLocked = false, // Por defecto desbloqueado
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'isLocked': isLocked,
      };

  factory FloatingImage.fromJson(Map<String, dynamic> json) => FloatingImage(
        filePath: (json['filePath'] ?? '') as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        isLocked: (json['isLocked'] ?? false) as bool,
      );
}

/// Texto flotante (párrafos que se pueden mover libremente)
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
    required this.width,
    required this.bold,
    required this.underline,
    this.underlineColor,
    required this.highlight,
    this.highlightColor,
    this.isLocked = false,
    this.fontSize = 16.0,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'x': x,
        'y': y,
        'width': width,
        'bold': bold,
        'underline': underline,
        'underlineColor': underlineColor,
        'highlight': highlight,
        'highlightColor': highlightColor,
        'isLocked': isLocked,
        'fontSize': fontSize,
      };

  factory FloatingText.fromJson(Map<String, dynamic> json) => FloatingText(
        text: (json['text'] ?? '') as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        bold: (json['bold'] ?? false) as bool,
        underline: (json['underline'] ?? false) as bool,
        underlineColor: json['underlineColor'] == null
            ? null
            : (json['underlineColor'] as num).toInt(),
        highlight: (json['highlight'] ?? false) as bool,
        highlightColor: json['highlightColor'] == null
            ? null
            : (json['highlightColor'] as num).toInt(),
        isLocked: (json['isLocked'] ?? false) as bool,
        fontSize: (json['fontSize'] ?? 16.0) as double,
      );
}

/// =========================
/// PANTALLA DE EDICIÓN DE NOTA
/// =========================
class NoteEditScreen extends StatefulWidget {
  final Note note;

  const NoteEditScreen({super.key, required this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen>
    with SingleTickerProviderStateMixin {
  // Estado UI
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  bool _hasUnsavedChanges = false;
  bool _editingTitle = false;

  // Controladores
  late TextEditingController _titleController;
  late TextEditingController _categoriaController;
  final TextEditingController _hiddenController = TextEditingController();
  final FocusNode _hiddenFocus = FocusNode();

  // Apariencia
  Color _noteColor = Colors.white;
  String _skin = 'grid';
  double _titleFontSize = 24;
  double _contentFontSize = 16;

  // Límites
  final double _minTitleFontSize = 18;
  final double _maxTitleFontSize = 64;
  final double _minContentFontSize = 12;
  final double _maxContentFontSize = 28;

  // Contenido
  List<_TextPart> _contentParts = <_TextPart>[];
  final Map<int, TextEditingController> _partControllers = {};
  int? _editingPartIndex;

  // Selección (se usará para imágenes flotantes)
  int? _activeImageIndex;

  // Controller para el scroll del contenido
  late ScrollController _scrollController;

  // Control de inserciones por drag de texto
  int? _dropInsertIndex;

  // Imágenes flotantes superpuestas
  final List<FloatingImage> _floatingImages = <FloatingImage>[];

  // Textos flotantes superpuestos
  final List<FloatingText> _floatingTexts = <FloatingText>[];

  // Formato actual de escritura continua
  TextFormatValue _contentFormat = const TextFormatValue();

  // RepaintBoundary para compartir imagen
  final GlobalKey _noteKey = GlobalKey();

  // ======= CLAVES/GEOMETRÍA PARA DELIMITAR ÁREA DE CONTENIDO =======
  final GlobalKey _contentAreaKey = GlobalKey(); // mide el área de ListView
  Rect? _contentRectInStack; // rect relativo al Stack raíz

  // Snackbar manual
  bool _showSavedSnackbar = false;

  // OPTIMIZACIÓN: Debounce para _saveNote
  Timer? _saveDebounceTimer;
  
  // OPTIMIZACIÓN: Cache para evitar cálculos repetitivos
  Timer? _contentRectUpdateTimer;

  // ========= Sistema de Dibujo Libre =========
  final List<DrawingStroke> _drawingStrokes = <DrawingStroke>[];
  bool _isDrawingMode = false;
  DrawingStroke? _currentStroke;

  // ========= Helpers =========

  /// 🔄 Convertir párrafo en texto flotante arrastrable
  void _convertParagraphToFloating(int index, _TextPart part) {
    setState(() {
      final floatingText = FloatingText(
        text: part.text,
        x: 50.0,
        y: 200.0 + (_floatingTexts.length * 80.0),
        width: 250.0,
        bold: part.bold,
        underline: part.underline,
        underlineColor: part.underlineColor,
        highlight: part.highlight,
        highlightColor: part.highlightColor,
        fontSize: _contentFontSize,
      );
      _floatingTexts.add(floatingText);
      _contentParts.removeAt(index);
    });

    _saveNote(pop: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📝 Párrafo convertido a texto flotante'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// ✏️ Editar texto flotante
  void _editFloatingText(int index, FloatingText text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController(text: text.text);

        return AlertDialog(
          title: const Text('✏️ Editar texto flotante'),
          content: TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Escribe el texto...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _floatingTexts[index].text = controller.text.trim();
                  });
                  _saveNote(pop: false);
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  /// 🎯 Mostrar menú en abanico específico para textos flotantes
  void _showFloatingTextOptionsPanel(
      BuildContext context, int index, FloatingText text) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, _) => _FanMenuOverlay(
          animation: animation,
          onMoveTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('💡 Arrastra el texto para moverlo'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          onDuplicateTap: () {
            Navigator.pop(context);
            setState(() {
              final duplicatedText = FloatingText(
                text: text.text,
                x: text.x + 20,
                y: text.y + 20,
                width: text.width,
                bold: text.bold,
                underline: text.underline,
                underlineColor: text.underlineColor,
                highlight: text.highlight,
                highlightColor: text.highlightColor,
                fontSize: text.fontSize,
              );
              _floatingTexts.add(duplicatedText);
            });
            _saveNote();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📋 Texto flotante duplicado'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          onDeleteTap: () {
            Navigator.pop(context);
            setState(() {
              _floatingTexts.removeAt(index);
            });
            _saveNote();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🗑️ Texto flotante eliminado'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          onFormatTap: () {
            Navigator.pop(context);
            _showFloatingTextFormatPanel(context, index, text);
          },
        ),
      ),
    );
  }

  /// 📝 Mostrar panel de formato específico para texto flotante
  void _showFloatingTextFormatPanel(
      BuildContext context, int index, FloatingText text) {
    TextFormatValue currentFormat = TextFormatValue(
      bold: text.bold,
      underline: text.underline,
      underlineColor: text.underlineColor != null
          ? Color(text.underlineColor!)
          : const Color(0xFF000000),
      highlight: text.highlight,
      highlightColor: text.highlightColor != null
          ? Color(text.highlightColor!)
          : const Color(0xFFFFFF00),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: MediaQuery.of(ctx).viewInsets,
        child: TextFormatPanel(
          value: currentFormat,
          onChanged: (val) {
            setState(() {
              _floatingTexts[index].bold = val.bold;
              _floatingTexts[index].underline = val.underline;
              _floatingTexts[index].underlineColor =
                  val.underline ? val.underlineColor.value : null;
              _floatingTexts[index].highlight = val.highlight;
              _floatingTexts[index].highlightColor =
                  val.highlight ? val.highlightColor.value : null;
            });
            _saveNote(pop: false);
          },
          onClose: () {
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  /// 🎯 Mostrar menú en abanico circular para párrafo específico
  void _showParagraphOptionsPanel(
      BuildContext context, int index, _TextPart part) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, _) => _FanMenuOverlay(
          animation: animation,
          onMoveTap: () {
            Navigator.pop(context);
            _convertParagraphToFloating(index, part);
          },
          onDuplicateTap: () {
            Navigator.pop(context);
            setState(() {
              _contentParts.insert(index + 1, part);
            });
            _saveNote();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📋 Párrafo duplicado'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
          onFormatTap: () {
            Navigator.pop(context);
            _showParagraphFormatPanel(context, index, part);
          },
          onDeleteTap: () {
            Navigator.pop(context);
            _deleteParagraph(index, part);
          },
        ),
      ),
    );
  }

  /// 🧶 Panel de formato para párrafo
  void _showParagraphFormatPanel(
      BuildContext context, int index, _TextPart part) {
    TextFormatValue currentFormat = TextFormatValue(
      bold: part.bold,
      underline: part.underline,
      underlineColor: part.underlineColor != null
          ? Color(part.underlineColor!)
          : const Color(0xFF000000),
      highlight: part.highlight,
      highlightColor: part.highlightColor != null
          ? Color(part.highlightColor!)
          : const Color(0xFFFFFF00),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: MediaQuery.of(ctx).viewInsets,
        child: TextFormatPanel(
          value: currentFormat,
          onChanged: (val) {
            setState(() {
              _contentParts[index] = _TextPart(
                part.text,
                val.bold,
                val.underline,
                val.underline ? val.underlineColor.value : null,
                val.highlight,
                val.highlight ? val.highlightColor.value : null,
                false,
              );
            });
            _saveNote(pop: false);
          },
          onClose: () {
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  /// 🗑️ Eliminar párrafo
  void _deleteParagraph(int index, _TextPart part) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar párrafo?'),
        content: Text(
            'Se eliminará: "${part.text.length > 50 ? part.text.substring(0, 50) + '...' : part.text}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _contentParts.removeAt(index);
              });
              _saveNote();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Párrafo eliminado'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void setHasUnsavedChanges(bool v) {
    if (_hasUnsavedChanges == v) return;
    setState(() {
      _hasUnsavedChanges = v;
    });
    if (v) {
      if (!_blinkController.isAnimating) _blinkController.forward();
    } else {
      if (_blinkController.isAnimating) _blinkController.stop();
    }
  }

  // Acepta DateTime? o String (evita error de tipos)
  String _formatDateTime(dynamic value) {
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value);
    }
    if (dt == null) return value?.toString() ?? '';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _shareAsText() async {
    final buffer = StringBuffer();
    buffer.writeln(widget.note.title);
    if (widget.note.categoria.isNotEmpty) {
      buffer.writeln('# ${widget.note.categoria}');
    }
    buffer.writeln('');
    for (final e in _contentParts) {
      if (!e.isImage) {
        buffer.writeln(e.text);
        buffer.writeln('');
      }
    }
    final textOut = buffer.toString().trim();
    if (textOut.isEmpty) return;
    await Share.share(textOut);
  }

  Future<void> _shareAsPdf() async {
    try {
      final pdf = pw.Document();
      final nunito = pw.Font.helvetica();
      final nunitoBold = pw.Font.helveticaBold();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            theme: pw.ThemeData.withFont(base: nunito, bold: nunitoBold),
            margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          ),
          build: (context) {
            return <pw.Widget>[
              pw.SizedBox(height: 12),
              pw.Text(widget.note.title,
                  style: pw.TextStyle(
                    font: nunitoBold,
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center),
              if (widget.note.categoria.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
                  child: pw.Text(widget.note.categoria,
                      style: pw.TextStyle(
                        font: nunito,
                        fontSize: 16,
                        color: PdfColors.blueGrey,
                      ),
                      textAlign: pw.TextAlign.center),
                ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1.2, color: PdfColors.blueGrey),
              pw.SizedBox(height: 12),
              ..._contentParts.map((e) {
                if (e.isImage) return pw.SizedBox(height: 0);
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Container(
                    color: (e.highlight && e.highlightColor != null)
                        ? PdfColor.fromInt(e.highlightColor!)
                        : null,
                    child: pw.Text(
                      e.text,
                      style: pw.TextStyle(
                        font: e.bold ? nunitoBold : nunito,
                        fontSize: 16,
                        decoration: e.underline
                            ? pw.TextDecoration.underline
                            : pw.TextDecoration.none,
                        decorationColor: e.underline && e.underlineColor != null
                            ? PdfColor.fromInt(e.underlineColor!)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey, font: nunito),
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nota.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: 'nota.pdf')],
        text: _titleController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir como PDF: $e')),
      );
    }
  }

  Future<void> _shareAsImage() async {
    try {
      final boundary =
          _noteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo acceder al área de la nota');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No se pudo codificar la imagen');
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nota.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'nota.png')],
        text: _titleController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir como imagen: $e')),
      );
    }
  }

  // ========= Geometría del área de contenido =========

  void _scheduleUpdateContentRect() {
    // OPTIMIZACIÓN: Evitar múltiples updates por frame
    _contentRectUpdateTimer?.cancel();
    _contentRectUpdateTimer = Timer(const Duration(milliseconds: 16), () {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentRect());
    });
  }

  void _updateContentRect() {
    try {
      final stackBox =
          _noteKey.currentContext?.findRenderObject() as RenderBox?;
      final contentBox =
          _contentAreaKey.currentContext?.findRenderObject() as RenderBox?;
      if (stackBox == null || contentBox == null) return;

      final topLeft = contentBox.localToGlobal(Offset.zero, ancestor: stackBox);
      final size = contentBox.size;
      final newRect =
          Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);

      if (_contentRectInStack == null ||
          _rectsDifferent(_contentRectInStack!, newRect)) {
        setState(() {
          _contentRectInStack = newRect;
        });
      }
    } catch (_) {
      // Silencio: puede ocurrir durante hot-reload
    }
  }

  bool _rectsDifferent(Rect a, Rect b) {
    const eps = 0.5;
    return (a.left - b.left).abs() > eps ||
        (a.top - b.top).abs() > eps ||
        (a.width - b.width).abs() > eps ||
        (a.height - b.height).abs() > eps;
  }

  // ========= Métodos de Dibujo Libre =========

  // Convierte posición local del overlay de dibujo -> coordenadas del CONTENIDO
  Offset _toContentCoords(Offset localInOverlay) {
    final scroll =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    return Offset(localInOverlay.dx, localInOverlay.dy + scroll);
  }

  void _onDrawStart(DragStartDetails details) {
    if (!_isDrawingMode) return;

    // Determinar herramienta
    String toolType = '';
    Color color = Colors.black;
    double strokeWidth = 2.0;

    if (_contentFormat.pencil) {
      toolType = 'pencil';
      color = _contentFormat.pencilColor;
      strokeWidth = 2.0;
    } else if (_contentFormat.pen) {
      toolType = 'pen';
      color = _contentFormat.penColor;
      strokeWidth = 4.0;
    } else if (_contentFormat.crayon) {
      toolType = 'crayon';
      color = _contentFormat.crayonColor;
      strokeWidth = 8.0;
    } else if (_contentFormat.brush) {
      toolType = 'brush';
      color = _contentFormat.brushColor;
      strokeWidth = 6.0;
    } else if (_contentFormat.eraser) {
      // Borrador: manejar en update
    }

    // Crear nuevo trazo (en espacio de CONTENIDO)
    setState(() {
      final p = _toContentCoords(details.localPosition);
      _currentStroke = (_contentFormat.eraser)
          ? null
          : DrawingStroke(
              points: [p],
              color: color,
              strokeWidth: strokeWidth,
              toolType: toolType,
            );
    });
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    if (!_isDrawingMode) return;

    final p = _toContentCoords(details.localPosition);

    if (_contentFormat.eraser) {
      _eraseStrokesAt(p);
      return;
    }

    if (_currentStroke == null) return;

    setState(() {
      _currentStroke = DrawingStroke(
        points: [..._currentStroke!.points, p],
        color: _currentStroke!.color,
        strokeWidth: _currentStroke!.strokeWidth,
        toolType: _currentStroke!.toolType,
      );
    });
  }

  void _onDrawEnd(DragEndDetails details) {
    if (!_isDrawingMode) return;
    if (_contentFormat.eraser) return;
    if (_currentStroke == null) return;

    setState(() {
      _drawingStrokes.add(_currentStroke!);
      _currentStroke = null;
    });

    _saveNote();
  }

  // Borrar trazos cerca de una posición (en coordenadas de CONTENIDO)
  void _eraseStrokesAt(Offset positionInContent) {
    const double eraserRadius = 20.0;
    final toRemove = <DrawingStroke>[];

    for (final stroke in _drawingStrokes) {
      for (final point in stroke.points) {
        if ((point - positionInContent).distance <= eraserRadius) {
          toRemove.add(stroke);
          break;
        }
      }
    }

    if (toRemove.isNotEmpty) {
      setState(() {
        for (final s in toRemove) {
          _drawingStrokes.remove(s);
        }
      });
      _saveNote();
    }
  }

  void _saveNote({bool pop = false}) {
    // OPTIMIZACIÓN: Cancelar timer anterior y programar nuevo guardado
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSave(pop: pop);
    });
  }

  void _performSave({bool pop = false}) {
    final note = widget.note;
    note.title = _titleController.text;
    note.categoria = _categoriaController.text;
    note.color = _noteColor;
    note.skin = _skin.isEmpty ? 'grid' : _skin;
    note.titleFontSize = _titleFontSize;
    note.contentFontSize = _contentFontSize;

    final List<_TextPart> partsToSave = List<_TextPart>.from(_contentParts);
    final String pendingText = _hiddenController.text.trim();
    if (pendingText.isNotEmpty) {
      if (partsToSave.isEmpty || partsToSave.last.text != pendingText) {
        partsToSave.add(
          _TextPart(
            pendingText,
            _contentFormat.bold,    // RESTAURADO: negrilla se aplica al texto principal
            _contentFormat.underline, // RESTAURADO: subrayado se aplica al texto principal
            _contentFormat.underline
                ? _contentFormat.underlineColor.value
                : null,
            _contentFormat.highlight, // RESTAURADO: resaltado se aplica al texto principal
            _contentFormat.highlight
                ? _contentFormat.highlightColor.value
                : null,
            false,
          ),
        );
      }
    }

    note.contentParts = partsToSave.map((e) => e.toJson()).toList();
    note.floatingImages = _floatingImages.map((img) => img.toJson()).toList();
    note.floatingTexts = _floatingTexts.map((text) => text.toJson()).toList();
    note.drawingStrokes = _drawingStrokes.map((s) => s.toJson()).toList();

    context.read<NoteProvider>().updateNote(note);

    if (_showSavedSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota guardada'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showSavedSnackbar = false;
    }
    if (pop) Navigator.pop(context);
  }

  Widget _buildIconBox({required Widget icon, required VoidCallback onTap}) {
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

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      // OPTIMIZADO: Solo recalcular área de contenido, sin setState innecesario
      if (mounted) {
        _scheduleUpdateContentRect();
      }
    });

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _blinkController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _blinkController.forward();
      }
    });

    _titleController = TextEditingController(text: widget.note.title);
    _categoriaController = TextEditingController(text: widget.note.categoria);
    _noteColor = widget.note.color;
    _skin = widget.note.skin.isEmpty ? 'grid' : widget.note.skin;
    _titleFontSize = widget.note.titleFontSize;
    _contentFontSize = widget.note.contentFontSize;

    _contentFormat = const TextFormatValue();

    _contentParts = (widget.note.contentParts)
        .map<_TextPart>(
          (e) => _TextPart.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
    _hiddenController.clear();

    _titleController.addListener(_onAnyChange);
    _categoriaController.addListener(_onAnyChange);
    _hiddenController.addListener(_onAnyChange);

    // Restaurar imágenes y textos flotantes
    _floatingImages.clear();
    for (final img in widget.note.floatingImages) {
      final restoredImg =
          FloatingImage.fromJson((img as Map).cast<String, dynamic>());
      _floatingImages.add(restoredImg);
    }

    _floatingTexts.clear();
    for (final text in widget.note.floatingTexts) {
      final restoredText =
          FloatingText.fromJson((text as Map).cast<String, dynamic>());
      _floatingTexts.add(restoredText);
    }

    // Restaurar trazos
    _drawingStrokes.clear();
    for (final stroke in widget.note.drawingStrokes) {
      final restoredStroke =
          DrawingStroke.fromJson((stroke as Map).cast<String, dynamic>());
      _drawingStrokes.add(restoredStroke);
    }

    // Ajuste de posiciones post-frame y guardar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateContentRect();
      setState(() {});
      _saveNote(pop: false);
    });
  }

  void _onAnyChange() => setHasUnsavedChanges(true);

  @override
  void dispose() {
    // OPTIMIZACIÓN: Limpiar timers para evitar memory leaks
    _saveDebounceTimer?.cancel();
    _contentRectUpdateTimer?.cancel();
    
    _performSave(pop: false); // Guardado final sin debounce
    _blinkController.dispose();
    _titleController.removeListener(_onAnyChange);
    _categoriaController.removeListener(_onAnyChange);
    _hiddenController.removeListener(_onAnyChange);
    _titleController.dispose();
    _categoriaController.dispose();
    _hiddenController.dispose();
    _hiddenFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double _bottomBarHeight = 72.0;

    final currentScroll =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _noteColor,
      appBar: AppBar(
        backgroundColor: _noteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Text('⬅️',
              style: TextStyle(fontSize: 24, color: Colors.black)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        title: const Text(
          'Editar nota',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                return IconButton(
                  icon: Opacity(
                    opacity: _hasUnsavedChanges ? _blinkAnimation.value : 1.0,
                    child: const Text('💾', style: TextStyle(fontSize: 26)),
                  ),
                  tooltip: 'Guardar',
                  onPressed: () {
                    _showSavedSnackbar = true;
                    setHasUnsavedChanges(false);
                    _saveNote(pop: false);
                  },
                );
              },
            ),
          ),
          IconButton(
            icon: Image.asset('assets/compartir.png', width: 28, height: 28),
            tooltip: 'Compartir',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Text('🟢', style: TextStyle(fontSize: 22)),
                      title: const Text('Compartir como texto'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _shareAsText();
                      },
                    ),
                    ListTile(
                      leading: const Text('🟡', style: TextStyle(fontSize: 22)),
                      title: const Text('Compartir como PDF'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _shareAsPdf();
                      },
                    ),
                    ListTile(
                      leading: const Text('🔴', style: TextStyle(fontSize: 22)),
                      title: const Text('Compartir como imagen'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _shareAsImage();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Text('⚙️',
                style: TextStyle(fontSize: 22, color: Colors.black)),
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'skins':
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => SkinPanel(
                      color: _noteColor,
                      onColorSelected: (c) {
                        setState(() {
                          _noteColor = c;
                          _saveNote(pop: false);
                          _scheduleUpdateContentRect();
                        });
                      },
                    ),
                  );
                  break;
                case 'delete':
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar nota'),
                      content: const Text(
                          '¿Estás seguro de que deseas eliminar esta nota?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<NoteProvider>()
                                .deleteNote(widget.note);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Eliminar',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'skins', child: Text('Skins y color')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar nota')),
            ],
          ),
        ],
      ),

      // ======= BODY: Stack con contenido principal + overlays =======
      body: RepaintBoundary(
        key: _noteKey,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ---- Contenido principal (debajo) ----
            Column(
              children: [
                // Cabecera (fecha/categoría)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⏳',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDateTime(widget.note.date),
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 13.5),
                            ),
                            if (_categoriaController.text.isNotEmpty)
                              Row(
                                children: [
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _categoriaController.text,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 13.5,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 1.5,
                                            color: Colors.black12,
                                            offset: Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Text('📂',
                            style:
                                TextStyle(fontSize: 18, color: Colors.black)),
                        onPressed: () async {
                          final selected = await showMenu<String>(
                            context: context,
                            position:
                                const RelativeRect.fromLTRB(200, 80, 16, 0),
                            items: const [
                              PopupMenuItem(
                                  value: 'Sermón', child: Text('📖  Sermón')),
                              PopupMenuItem(
                                  value: 'Estudio Bíblico',
                                  child: Text('📚  Estudio Bíblico')),
                              PopupMenuItem(
                                  value: 'Reflexión',
                                  child: Text('🤔  Reflexión')),
                              PopupMenuItem(
                                  value: 'Devocional',
                                  child: Text('❤️  Devocional')),
                              PopupMenuItem(
                                  value: 'Testimonio',
                                  child: Text('🌟  Testimonio')),
                              PopupMenuItem(
                                  value: 'Apuntes Generales',
                                  child: Text('📓  Apuntes Generales')),
                              PopupMenuItem(
                                  value: 'Discipulado',
                                  child: Text('🏫  Discipulado')),
                              PopupMenuItem(
                                  value: 'Conexion',
                                  child: Text('🔗  Conexion')),
                              PopupMenuItem(
                                  value: 'Música', child: Text('🎵  Música')),
                              PopupMenuItem(
                                  value: 'Cita', child: Text('💬  Cita')),
                              PopupMenuItem(
                                  value: 'Versículo',
                                  child: Text('📜  Versículo')),
                              PopupMenuItem(
                                  value: 'Oración', child: Text('🙏  Oración')),
                              PopupMenuItem(
                                  value: 'Culto', child: Text('⛪  Culto')),
                              PopupMenuItem(
                                  value: 'Otro', child: Text('🌀  Otro')),
                            ],
                          );
                          if (selected != null) {
                            setState(() {
                              _categoriaController.text = selected;
                            });
                          }
                        },
                        tooltip: 'Seleccionar categoría',
                      ),
                    ],
                  ),
                ),

                // Título y sliders
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  child: Column(
                    children: [
                      _editingTitle
                          ? TextField(
                              controller: _titleController,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              maxLines: null,
                              minLines: 1,
                              decoration: const InputDecoration(
                                hintText: 'Encabezado',
                                border: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.zero,
                                counterText: '',
                              ),
                              style: TextStyle(
                                fontSize: _titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.done,
                              onChanged: (v) => _saveNote(pop: false),
                              onEditingComplete: () {
                                setState(() => _editingTitle = false);
                                _saveNote(pop: false);
                              },
                            )
                          : GestureDetector(
                              onTap: () => setState(() => _editingTitle = true),
                              child: Center(
                                child: AutoSizeText(
                                  _titleController.text.isEmpty
                                      ? 'Encabezado'
                                      : _titleController.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: _titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 10,
                                  minFontSize: 10,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ),
                      const SizedBox(height: 6),

                      // Slider para el título
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                                thumbColor: Colors.black,
                                activeTrackColor: Colors.black54,
                                inactiveTrackColor: Colors.black26,
                              ),
                              child: Slider(
                                min: _minTitleFontSize,
                                max: _maxTitleFontSize,
                                value: _titleFontSize.clamp(
                                    _minTitleFontSize, _maxTitleFontSize),
                                onChanged: (v) {
                                  setState(() {
                                    final oldSize = _titleFontSize;
                                    final newSize = v.clamp(
                                        _minTitleFontSize, _maxTitleFontSize);
                                    final scaleFactor = newSize / oldSize;

                                    _titleFontSize = newSize;

                                    for (int i = 0;
                                        i < _floatingImages.length;
                                        i++) {
                                      _floatingImages[i].width *= scaleFactor;
                                      _floatingImages[i].height *= scaleFactor;
                                      _floatingImages[i].width =
                                          _floatingImages[i]
                                              .width
                                              .clamp(60.0, 600.0);
                                      _floatingImages[i].height =
                                          _floatingImages[i]
                                              .height
                                              .clamp(60.0, 600.0);
                                    }
                                  });
                                  _saveNote();
                                  _scheduleUpdateContentRect();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Slider para el contenido
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                                thumbColor: Colors.blue,
                                activeTrackColor: Colors.blueAccent,
                                inactiveTrackColor:
                                    Colors.blueAccent.withOpacity(0.25),
                              ),
                              child: Slider(
                                min: _minContentFontSize,
                                max: _maxContentFontSize,
                                value: _contentFontSize.clamp(
                                    _minContentFontSize, _maxContentFontSize),
                                onChanged: (v) {
                                  setState(() {
                                    final oldSize = _contentFontSize;
                                    final newSize = v.clamp(_minContentFontSize,
                                        _maxContentFontSize);
                                    final scaleFactor = newSize / oldSize;

                                    _contentFontSize = newSize;

                                    for (int i = 0;
                                        i < _floatingImages.length;
                                        i++) {
                                      _floatingImages[i].width *= scaleFactor;
                                      _floatingImages[i].height *= scaleFactor;
                                      _floatingImages[i].width =
                                          _floatingImages[i]
                                              .width
                                              .clamp(60.0, 600.0);
                                      _floatingImages[i].height =
                                          _floatingImages[i]
                                              .height
                                              .clamp(60.0, 600.0);
                                    }

                                    for (int i = 0;
                                        i < _floatingTexts.length;
                                        i++) {
                                      _floatingTexts[i].fontSize *= scaleFactor;
                                      _floatingTexts[i].fontSize =
                                          _floatingTexts[i]
                                              .fontSize
                                              .clamp(8.0, 48.0);
                                    }
                                  });
                                  _saveNote();
                                  _scheduleUpdateContentRect();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenido + LISTVIEW (llenará el resto)
                Expanded(
                  child: Container(
                    key:
                        _contentAreaKey, // 📌 Medimos esta caja para el overlay
                    child: ListView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        8,
                        16,
                        16,
                        _bottomBarHeight +
                            MediaQuery.of(context).padding.bottom +
                            16,
                      ),
                      shrinkWrap: false,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(_contentParts.length, (i) {
                            final part = _contentParts[i];

                            if (part.isImage) {
                              return const SizedBox.shrink();
                            }

                            if (_editingPartIndex == i) {
                              _partControllers[i] ??=
                                  TextEditingController(text: part.text);
                              return Focus(
                                onFocusChange: (hasFocus) {
                                  if (!hasFocus) {
                                    setState(() {
                                      _contentParts[i] = _TextPart(
                                        _partControllers[i]?.text ?? part.text,
                                        _contentFormat.bold,
                                        _contentFormat.underline,
                                        _contentFormat.underline
                                            ? _contentFormat
                                                .underlineColor.value
                                            : null,
                                        _contentFormat.highlight,
                                        _contentFormat.highlight
                                            ? _contentFormat
                                                .highlightColor.value
                                            : null,
                                        false,
                                      );
                                      _editingPartIndex = null;
                                      _partControllers.remove(i);
                                    });
                                    _saveNote();
                                  }
                                },
                                child: TextField(
                                  controller: _partControllers[i],
                                  autofocus: true,
                                  maxLines: null,
                                  style: TextStyle(
                                    fontSize: _contentFontSize,
                                    fontWeight: _contentFormat.bold
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: Colors.black87,
                                    decoration: _contentFormat.underline
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                    decorationColor: _contentFormat.underline
                                        ? _contentFormat.underlineColor
                                        : null,
                                    decorationThickness:
                                        _contentFormat.underline ? 2.5 : null,
                                    backgroundColor: _contentFormat.highlight
                                        ? _contentFormat.highlightColor
                                        : Colors.transparent,
                                  ),
                                  textAlign: TextAlign.left,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                  ),
                                  onChanged: (_) => setHasUnsavedChanges(true),
                                  onSubmitted: (value) {
                                    setState(() {
                                      _contentParts[i] = _TextPart(
                                        value,
                                        _contentFormat.bold,
                                        _contentFormat.underline,
                                        _contentFormat.underline
                                            ? _contentFormat
                                                .underlineColor.value
                                            : null,
                                        _contentFormat.highlight,
                                        _contentFormat.highlight
                                            ? _contentFormat
                                                .highlightColor.value
                                            : null,
                                        false,
                                      );
                                      _editingPartIndex = null;
                                      _partControllers.remove(i);
                                    });
                                    _saveNote();
                                  },
                                ),
                              );
                            } else {
                              return LongPressDraggable<int>(
                                data: i,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0, horizontal: 4.0),
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: part.text,
                                            style: TextStyle(
                                              fontSize: _contentFontSize,
                                              fontWeight: part.bold
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.black54,
                                              decoration: part.underline
                                                  ? TextDecoration.underline
                                                  : TextDecoration.none,
                                              decorationColor: part.underline &&
                                                      part.underlineColor !=
                                                          null
                                                  ? Color(part.underlineColor!)
                                                  : null,
                                              decorationThickness:
                                                  part.underline ? 2.5 : null,
                                              backgroundColor: part.highlight &&
                                                      part.highlightColor !=
                                                          null
                                                  ? Color(part.highlightColor!)
                                                  : Colors.transparent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                childWhenDragging: const SizedBox.shrink(),
                                onDragCompleted: () {},
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _editingPartIndex = i;
                                  }),
                                  onLongPress: () {
                                    _showParagraphOptionsPanel(
                                        context, i, part);
                                  },
                                  child: DragTarget<int>(
                                    onWillAccept: (from) =>
                                        from != null && from != i,
                                    onAccept: (from) {
                                      setState(() {
                                        final moved =
                                            _contentParts.removeAt(from);
                                        _contentParts.insert(
                                            _dropInsertIndex ?? i, moved);
                                        _dropInsertIndex = null;
                                        _saveNote();
                                      });
                                    },
                                    onLeave: (_) => setState(() {
                                      _dropInsertIndex = null;
                                    }),
                                    builder:
                                        (context, candidateData, rejectedData) {
                                      final isActive = candidateData.isNotEmpty;
                                      return Column(
                                        children: [
                                          AnimatedOpacity(
                                            opacity: isActive ? 1.0 : 0.0,
                                            duration: const Duration(
                                                milliseconds: 180),
                                            child: Container(
                                              height: 3,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() {
                                              _editingPartIndex = i;
                                            }),
                                            onLongPress: () {
                                              _showParagraphOptionsPanel(
                                                  context, i, part);
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2.0,
                                                      horizontal: 4.0),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: part.text,
                                                        style: TextStyle(
                                                          fontSize:
                                                              _contentFontSize,
                                                          fontWeight: part.bold
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                          color: Colors.black87,
                                                          decoration: part
                                                                  .underline
                                                              ? TextDecoration
                                                                  .underline
                                                              : TextDecoration
                                                                  .none,
                                                          decorationColor: part
                                                                      .underline &&
                                                                  part.underlineColor !=
                                                                      null
                                                              ? Color(part
                                                                  .underlineColor!)
                                                              : null,
                                                          decorationThickness:
                                                              part.underline
                                                                  ? 2.5
                                                                  : null,
                                                          backgroundColor: part
                                                                      .highlight &&
                                                                  part.highlightColor !=
                                                                      null
                                                              ? Color(part
                                                                  .highlightColor!)
                                                              : Colors
                                                                  .transparent,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          }),
                        ),
                        const SizedBox(height: 8),

                        // Campo de escritura continua
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            border: Border.fromBorderSide(BorderSide.none),
                            color: Colors.transparent,
                          ),
                          child: TextField(
                            controller: _hiddenController,
                            focusNode: _hiddenFocus,
                            maxLines: null,
                            minLines: 3,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            cursorColor: Colors.amber,
                            style: TextStyle(
                              fontSize: _contentFontSize,
                              fontWeight: _contentFormat.bold
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.black87,
                              decoration: _contentFormat.underline
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: _contentFormat.underline
                                  ? _contentFormat.underlineColor
                                  : null,
                              decorationThickness:
                                  _contentFormat.underline ? 2.5 : null,
                              backgroundColor: _contentFormat.highlight
                                  ? _contentFormat.highlightColor
                                  : Colors.transparent,
                              height: 1.8,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.only(
                                  left: 0, right: 8, top: 10, bottom: 10),
                              hintText:
                                  'Escribe aquí...\n\nPresiona Enter para crear párrafos separados',
                              fillColor: Colors.transparent,
                              filled: true,
                            ),
                            textAlign: TextAlign.left,
                            onChanged: (_) {
                              _saveNote(pop: false);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ---- Área clipeada para imágenes y textos flotantes (limitadas al contenido) ----
            if (_contentRectInStack != null)
              Positioned.fromRect(
                rect: _contentRectInStack!,
                child: ClipRect(
                  child: Stack(
                    children: [
                      // Imágenes flotantes
                      ..._floatingImages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final img = entry.value;

                        final scrollOffset = _scrollController.hasClients
                            ? _scrollController.offset
                            : 0.0;
                        final adjustedY = img.y - scrollOffset;

                        return Positioned(
                          key: ValueKey('floating_${idx}_${img.filePath}'),
                          left: img.x,
                          top: adjustedY,
                          child: GestureDetector(
                            behavior: HitTestBehavior.deferToChild,
                            onTap: () {
                              setState(() {
                                _activeImageIndex =
                                    _activeImageIndex == idx ? null : idx;
                              });
                              _saveNote(pop: false);
                            },
                            onPanStart: (details) {
                              if (img.isLocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '🔒 Imagen bloqueada. Toca el candado para desbloquear.'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            onPanUpdate: (details) {
                              if (!img.isLocked) {
                                setState(() {
                                  _floatingImages[idx].x += details.delta.dx;
                                  _floatingImages[idx].y += details.delta.dy;
                                });
                              }
                            },
                            onPanEnd: (_) {
                              if (!img.isLocked) {
                                _saveNote(pop: false);
                              }
                            },
                            child: _ResizableImage(
                              filePath: img.filePath,
                              width: img.width,
                              height: img.height,
                              selected: _activeImageIndex == idx,
                              isLocked: img.isLocked,
                              onSelect: () {
                                setState(() {
                                  _activeImageIndex =
                                      _activeImageIndex == idx ? null : idx;
                                });
                                _saveNote(pop: false);
                              },
                              onResize: (w, h) {
                                setState(() {
                                  _floatingImages[idx].width = w;
                                  _floatingImages[idx].height = h;
                                });
                                _saveNote(pop: false);
                              },
                              onToggleLock: () {
                                setState(() {
                                  _floatingImages[idx].isLocked =
                                      !_floatingImages[idx].isLocked;
                                });
                                _saveNote(pop: false);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_floatingImages[idx].isLocked
                                        ? '🔒 Imagen bloqueada'
                                        : '🔓 Imagen desbloqueada'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor:
                                        _floatingImages[idx].isLocked
                                            ? Colors.red.shade400
                                            : Colors.green.shade400,
                                  ),
                                );
                              },
                              onDelete: () {
                                setState(() {
                                  _floatingImages.removeAt(idx);
                                  _activeImageIndex = null;
                                });
                                _saveNote(pop: false);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Imagen eliminada'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),

                      // Textos flotantes
                      ..._floatingTexts.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final text = entry.value;

                        final scrollOffset = _scrollController.hasClients
                            ? _scrollController.offset
                            : 0.0;
                        final adjustedY = text.y - scrollOffset;

                        return Positioned(
                          key: ValueKey('floating_text_${idx}_${text.text}'),
                          left: text.x,
                          top: adjustedY,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: () {
                              _editFloatingText(idx, text);
                            },
                            onLongPress: () {
                              _showFloatingTextOptionsPanel(context, idx, text);
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _floatingTexts[idx].x += details.delta.dx;
                                _floatingTexts[idx].y += details.delta.dy;
                              });
                            },
                            onPanEnd: (_) {
                              _saveNote(pop: false);
                            },
                            child: Container(
                              width: text.width,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                text.text,
                                style: TextStyle(
                                  fontSize: text.fontSize,
                                  fontWeight: text.bold
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  decoration: text.underline
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  decorationColor: text.underlineColor != null
                                      ? Color(text.underlineColor!)
                                      : null,
                                  backgroundColor: text.highlight &&
                                          text.highlightColor != null
                                      ? Color(text.highlightColor!)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            // ===== Capa de dibujo libre - SOLO en área de contenido =====
            if (_contentRectInStack != null &&
                (_drawingStrokes.isNotEmpty || _isDrawingMode))
              Positioned.fromRect(
                rect: _contentRectInStack!,
                child: _isDrawingMode
                    ? GestureDetector(
                        onPanStart: _onDrawStart,
                        onPanUpdate: _onDrawUpdate,
                        onPanEnd: _onDrawEnd,
                        behavior: HitTestBehavior.opaque,
                        child: CustomPaint(
                          painter: DrawingPainter(
                            strokes: _drawingStrokes,
                            currentStroke: _currentStroke,
                            scrollOffset: currentScroll,
                          ),
                        ),
                      )
                    : IgnorePointer(
                        child: CustomPaint(
                          painter: DrawingPainter(
                            strokes: _drawingStrokes,
                            currentStroke: null,
                            scrollOffset: currentScroll,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),

      // ======= BARRA INFERIOR =======
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
        child: Container(
          height: _bottomBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconBox(
                icon: Image.asset('assets/abc.png', width: 32, height: 32),
                onTap: () async {
                  // NUEVA LÓGICA DE TOGGLE SOLO PARA LAS 4 HERRAMIENTAS DE DIBUJO:
                  // Si estás en modo dibujo -> salir del modo dibujo con un toque (sin afectar formato de texto)
                  if (_isDrawingMode) {
                    setState(() {
                      _isDrawingMode = false; // 😌 Vuelves a escribir texto
                    });
                    FocusScope.of(context).requestFocus(_hiddenFocus);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '✍️ Modo dibujo desactivado. Puedes escribir.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    return; // No abrimos el panel en este toque
                  }

                  // Si NO estás en modo dibujo -> abrir panel normal
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Padding(
                      padding: MediaQuery.of(ctx).viewInsets,
                      child: TextFormatPanel(
                        value: _contentFormat,
                        onChanged: (val) {
                          // Comportamiento DIFERENTE para los 3 primeros vs los 4 nuevos
                          
                          // Comportamiento RESTAURADO: Los 3 primeros crean nuevos párrafos independientes
                          if ((val.bold && !_contentFormat.bold) ||
                              (val.underline && !_contentFormat.underline) ||
                              (val.highlight && !_contentFormat.highlight)) {
                            
                            // Guardar texto actual si existe
                            final String currentText = _hiddenController.text.trim();
                            if (currentText.isNotEmpty) {
                              setState(() {
                                _contentParts.add(_TextPart(
                                  currentText,
                                  _contentFormat.bold,
                                  _contentFormat.underline,
                                  _contentFormat.underline ? _contentFormat.underlineColor.value : null,
                                  _contentFormat.highlight,
                                  _contentFormat.highlight ? _contentFormat.highlightColor.value : null,
                                  false,
                                ));
                              });
                              _hiddenController.clear();
                            }
                            
                            // Aplicar SOLO el nuevo formato seleccionado (crear nuevo párrafo)
                            setState(() {
                              if (val.bold && !_contentFormat.bold) {
                                _contentFormat = TextFormatValue(
                                  bold: true,
                                  underline: false,
                                  highlight: false,
                                  // Mantener herramientas de dibujo existentes
                                  pencil: _contentFormat.pencil,
                                  pencilColor: _contentFormat.pencilColor,
                                  pen: _contentFormat.pen,
                                  penColor: _contentFormat.penColor,
                                  crayon: _contentFormat.crayon,
                                  crayonColor: _contentFormat.crayonColor,
                                  brush: _contentFormat.brush,
                                  brushColor: _contentFormat.brushColor,
                                  eraser: _contentFormat.eraser,
                                );
                              } else if (val.underline && !_contentFormat.underline) {
                                _contentFormat = TextFormatValue(
                                  bold: false,
                                  underline: true,
                                  underlineColor: val.underlineColor,
                                  highlight: false,
                                  // Mantener herramientas de dibujo existentes
                                  pencil: _contentFormat.pencil,
                                  pencilColor: _contentFormat.pencilColor,
                                  pen: _contentFormat.pen,
                                  penColor: _contentFormat.penColor,
                                  crayon: _contentFormat.crayon,
                                  crayonColor: _contentFormat.crayonColor,
                                  brush: _contentFormat.brush,
                                  brushColor: _contentFormat.brushColor,
                                  eraser: _contentFormat.eraser,
                                );
                              } else if (val.highlight && !_contentFormat.highlight) {
                                _contentFormat = TextFormatValue(
                                  bold: false,
                                  underline: false,
                                  highlight: true,
                                  highlightColor: val.highlightColor,
                                  // Mantener herramientas de dibujo existentes
                                  pencil: _contentFormat.pencil,
                                  pencilColor: _contentFormat.pencilColor,
                                  pen: _contentFormat.pen,
                                  penColor: _contentFormat.penColor,
                                  crayon: _contentFormat.crayon,
                                  crayonColor: _contentFormat.crayonColor,
                                  brush: _contentFormat.brush,
                                  brushColor: _contentFormat.brushColor,
                                  eraser: _contentFormat.eraser,
                                );
                              }
                            });
                            
                            _saveNote(pop: false);
                            
                            // SOLUCIÓN COLORES: Solo cerrar si es BOLD (sin colores)
                            if (val.bold && !val.underline && !val.highlight) {
                              Navigator.pop(ctx);
                              FocusScope.of(context).requestFocus(_hiddenFocus);
                            }
                            // Para underline y highlight, NO cerrar para permitir selección de color
                            return;
                          }
                          
                          // Detectar cuando se selecciona color en underline o highlight
                          if ((val.underline && _contentFormat.underline && val.underlineColor != _contentFormat.underlineColor) ||
                              (val.highlight && _contentFormat.highlight && val.highlightColor != _contentFormat.highlightColor)) {
                            // Solo actualizar el color, y cerrar
                            setState(() {
                              if (val.underline && val.underlineColor != _contentFormat.underlineColor) {
                                _contentFormat = _contentFormat.copyWith(underlineColor: val.underlineColor);
                              }
                              if (val.highlight && val.highlightColor != _contentFormat.highlightColor) {
                                _contentFormat = _contentFormat.copyWith(highlightColor: val.highlightColor);
                              }
                            });
                            _saveNote(pop: false);
                            Navigator.pop(ctx);
                            FocusScope.of(context).requestFocus(_hiddenFocus);
                            return;
                          }
                          
                          // Para las 4 herramientas de dibujo -> comportamiento actual (acumulativo)
                          _contentFormat = val;

                          // Activar/desactivar modo dibujo: SOLO por las 4 herramientas (y borrador)
                          final drawingActive = val.pencil ||
                              val.pen ||
                              val.crayon ||
                              val.brush ||
                              val.eraser;

                          if (drawingActive != _isDrawingMode) {
                            setState(() {
                              _isDrawingMode = drawingActive;
                            });
                          }

                          _saveNote(pop: false);
                        },
                        onClose: () {
                          Navigator.pop(ctx);
                          // Si sigue desactivado, enfocamos texto
                          if (!_isDrawingMode && mounted) {
                            FocusScope.of(context).requestFocus(_hiddenFocus);
                          }
                        },
                      ),
                    ),
                  );

                  // Volver foco a escribir si no quedaste en modo dibujo
                  if (!_isDrawingMode) {
                    FocusScope.of(context).requestFocus(_hiddenFocus);
                  }
                },
              ),
              _buildIconBox(
                icon: Image.asset('assets/camara.png', width: 32, height: 32),
                onTap: () {
                  showModalBottomSheet<File?>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (ctx) => const CameraGalleryWidget(),
                  ).then((selectedImage) {
                    if (selectedImage != null) {
                      final defaultW = 240.0;
                      final defaultH = 160.0;
                      final size = MediaQuery.of(context).size;
                      final startX = (size.width - defaultW) / 2 + 16;
                      final startY = 220.0 + 16;

                      setState(() {
                        _floatingImages.add(
                          FloatingImage(
                            filePath: selectedImage.path,
                            x: startX,
                            y: startY,
                            width: defaultW,
                            height: defaultH,
                          ),
                        );
                        _activeImageIndex = _floatingImages.length - 1;
                      });
                      _saveNote();
                      _scheduleUpdateContentRect();
                    }
                  });
                },
              ),
              _buildIconBox(
                icon: Image.asset('assets/IA.png', width: 32, height: 32),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MindMapFromNoteScreen(note: widget.note),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // ======= BOTÓN DE AUDIO =======
      floatingActionButton: AudioButton(noteId: widget.note.id.toString()),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// ===================
/// Imagen con handles (afuera del picker)
/// ===================
class _ResizableImage extends StatefulWidget {
  final String filePath;
  final double width;
  final double height;
  final bool selected;
  final bool isLocked; // 🔒 Estado del candado
  final VoidCallback onSelect;
  final void Function(double w, double h) onResize;
  final VoidCallback? onDelete; // 🔴 Callback para eliminar
  final VoidCallback? onToggleLock; // 🔒 Callback para alternar candado

  const _ResizableImage({
    Key? key,
    required this.filePath,
    required this.width,
    required this.height,
    required this.selected,
    required this.isLocked,
    required this.onSelect,
    required this.onResize,
    this.onDelete,
    this.onToggleLock,
  }) : super(key: key);

  @override
  State<_ResizableImage> createState() => _ResizableImageState();
}

class _ResizableImageState extends State<_ResizableImage> {
  late double _w;
  late double _h;
  final double _handle = 24;
  Offset? _start;
  late double _startW;
  late double _startH;

  @override
  void initState() {
    super.initState();
    _w = widget.width;
    _h = widget.height;
  }

  @override
  void didUpdateWidget(covariant _ResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _w = widget.width;
      _h = widget.height;
    }
  }

  Widget _handleAt(int idx) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        if (widget.isLocked) {
          return;
        }
        _start = d.localPosition;
        _startW = _w;
        _startH = _h;
      },
      onPanUpdate: (d) {
        if (widget.isLocked) {
          return;
        }
        final delta = d.localPosition - (_start ?? d.localPosition);
        setState(() {
          switch (idx) {
            case 0: // top-left
              _w = (_startW - delta.dx).clamp(60, 600);
              _h = (_startH - delta.dy).clamp(60, 600);
              break;
            case 1: // top-right
              _w = (_startW + delta.dx).clamp(60, 600);
              _h = (_startH - delta.dy).clamp(60, 600);
              break;
            case 2: // bottom-left
              _w = (_startW - delta.dx).clamp(60, 600);
              _h = (_startH + delta.dy).clamp(60, 600);
              break;
            case 3: // bottom-right
              _w = (_startW + delta.dx).clamp(60, 600);
              _h = (_startH + delta.dy).clamp(60, 600);
              break;
          }
        });
        widget.onResize(_w, _h);
      },
      child: Container(
        width: _handle,
        height: _handle,
        decoration: BoxDecoration(
          color: widget.isLocked ? Colors.grey.shade300 : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
              color: widget.isLocked ? Colors.grey.shade500 : Colors.blueAccent,
              width: 2),
          boxShadow: [
            BoxShadow(
                color: widget.isLocked ? Colors.black12 : Colors.black26,
                blurRadius: 4)
          ],
        ),
        child: widget.isLocked
            ? const Icon(
                Icons.lock,
                size: 12,
                color: Colors.grey,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: _w + _handle,
        height: _h + _handle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _handle / 2,
              top: _handle / 2,
              child: GestureDetector(
                onTap: widget.onSelect,
                child: Container(
                  width: _w,
                  height: _h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: widget.selected
                        ? Border.all(color: Colors.blueAccent, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(widget.filePath),
                      width: _w,
                      height: _h,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.selected) ...[
              Positioned(left: 0, top: 0, child: _handleAt(0)),
              Positioned(right: 0, top: 0, child: _handleAt(1)),
              Positioned(left: 0, bottom: 0, child: _handleAt(2)),
              Positioned(right: 0, bottom: 0, child: _handleAt(3)),
              if (widget.onDelete != null)
                Positioned(
                  top: (_handle / 2) + -22,
                  left: (_handle / 2) + -22,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('¿Eliminar imagen?'),
                            content:
                                const Text('Esta acción no se puede deshacer.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  widget.onDelete!();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.onToggleLock != null)
                Positioned(
                  top: (_handle / 2) + -22,
                  right: (_handle / 2) + -22,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        widget.onToggleLock!();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: widget.isLocked
                                  ? Colors.red.shade400
                                  : Colors.green.shade400,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.isLocked ? '🔒' : '🔓',
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===================
/// MENÚ EN ABANICO CIRCULAR
/// ===================
class _FanMenuOverlay extends StatefulWidget {
  final Animation<double> animation;
  final VoidCallback onMoveTap;
  final VoidCallback onDuplicateTap;
  final VoidCallback onFormatTap;
  final VoidCallback onDeleteTap;

  const _FanMenuOverlay({
    required this.animation,
    required this.onMoveTap,
    required this.onDuplicateTap,
    required this.onFormatTap,
    required this.onDeleteTap,
  });

  @override
  State<_FanMenuOverlay> createState() => _FanMenuOverlayState();
}

class _FanMenuOverlayState extends State<_FanMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildFanButton(
                        icon: Icons.open_with,
                        angle: -90,
                        onTap: widget.onMoveTap,
                      ),
                      _buildFanButton(
                        icon: Icons.copy,
                        angle: 0,
                        onTap: widget.onDuplicateTap,
                      ),
                      _buildFanButton(
                        icon: Icons.delete,
                        angle: 90,
                        onTap: widget.onDeleteTap,
                      ),
                      _buildFanButton(
                        icon: Icons.text_format,
                        angle: 180,
                        onTap: widget.onFormatTap,
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.black54,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFanButton({
    required IconData icon,
    required double angle,
    required VoidCallback onTap,
  }) {
    final radians = angle * (3.14159 / 180);
    final radius = 70.0;
    final x = radius * cos(radians);
    final y = radius * sin(radians);

    return Transform.translate(
      offset: Offset(
        x * _rotationAnimation.value,
        y * _rotationAnimation.value,
      ),
      child: Transform.rotate(
        angle: _rotationAnimation.value * 2 * 3.14159,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black12,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.black87,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// ===================
/// PANEL: Skins & Color
/// ===================
class SkinPanel extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorSelected;

  const SkinPanel({
    super.key,
    required this.color,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.white,
      Colors.grey.shade50,
      Colors.grey.shade100,
      Colors.grey.shade200,
      Colors.grey.shade300,
      Colors.yellow.shade50,
      Colors.yellow.shade100,
      Colors.yellow.shade200,
      Colors.yellow.shade300,
      Colors.yellow.shade400,
      Colors.yellow.shade500,
      Colors.amber.shade50,
      Colors.amber.shade100,
      Colors.amber.shade200,
      Colors.amber.shade300,
      Colors.amber.shade400,
      Colors.amber.shade500,
      Colors.orange.shade50,
      Colors.orange.shade100,
      Colors.orange.shade200,
      Colors.orange.shade300,
      Colors.orange.shade400,
      Colors.orange.shade500,
      Colors.pink.shade50,
      Colors.pink.shade100,
      Colors.pink.shade200,
      Colors.pink.shade300,
      Colors.pink.shade400,
      Colors.pink.shade500,
      Colors.purple.shade50,
      Colors.purple.shade100,
      Colors.purple.shade200,
      Colors.purple.shade300,
      Colors.purple.shade400,
      Colors.purple.shade500,
      Colors.deepPurple.shade50,
      Colors.deepPurple.shade100,
      Colors.deepPurple.shade200,
      Colors.deepPurple.shade300,
      Colors.deepPurple.shade400,
      Colors.deepPurple.shade500,
      Colors.blue.shade50,
      Colors.blue.shade100,
      Colors.blue.shade200,
      Colors.blue.shade300,
      Colors.blue.shade400,
      Colors.blue.shade500,
      Colors.lightBlue.shade50,
      Colors.lightBlue.shade100,
      Colors.lightBlue.shade200,
      Colors.lightBlue.shade300,
      Colors.lightBlue.shade400,
      Colors.lightBlue.shade500,
      Colors.cyan.shade50,
      Colors.cyan.shade100,
      Colors.cyan.shade200,
      Colors.cyan.shade300,
      Colors.cyan.shade400,
      Colors.cyan.shade500,
      Colors.indigo.shade50,
      Colors.indigo.shade100,
      Colors.indigo.shade200,
      Colors.indigo.shade300,
      Colors.indigo.shade400,
      Colors.indigo.shade500,
      Colors.green.shade50,
      Colors.green.shade100,
      Colors.green.shade200,
      Colors.green.shade300,
      Colors.green.shade400,
      Colors.green.shade500,
      Colors.lime.shade50,
      Colors.lime.shade100,
      Colors.lime.shade200,
      Colors.lime.shade300,
      Colors.lime.shade400,
      Colors.lime.shade500,
      Colors.teal.shade50,
      Colors.teal.shade100,
      Colors.teal.shade200,
      Colors.teal.shade300,
      Colors.teal.shade400,
      Colors.teal.shade500,
      Colors.brown.shade50,
      Colors.brown.shade100,
      Colors.brown.shade200,
      Colors.brown.shade300,
      Colors.brown.shade400,
      Colors.brown.shade500,
      const Color(0xFFf6d365),
      const Color(0xFFfda085),
      const Color(0xFFfbc2eb),
      const Color(0xFFa1c4fd),
      const Color(0xFFc2e9fb),
      const Color(0xFFd4fc79),
      const Color(0xFF96e6a1),
      const Color(0xFFf7797d),
      const Color(0xFFe0c3fc),
      const Color(0xFF8fd3f4),
      const Color(0xFFfcb69f),
      const Color(0xFFffecd2),
      const Color(0xFFa8edea),
      const Color(0xFFfed6e3),
      const Color(0xFFcfd9df),
      const Color(0xFFe2d1c3),
      const Color(0xFFf5f7fa),
      const Color(0xFFc9ffbf),
      const Color(0xFFffafbd),
      const Color(0xFFb2fefa),
      // Pasteles extra
      const Color(0xFFf8d7da),
      const Color(0xFFfce4ec),
      const Color(0xFFf3e5f5),
      const Color(0xFFede7f6),
      const Color(0xFFe8f5e8),
      const Color(0xFFe0f2f1),
      const Color(0xFFe3f2fd),
      const Color(0xFFe1f5fe),
      const Color(0xFFe0f7fa),
      const Color(0xFFf1f8e9),
      const Color(0xFFf9fbe7),
      const Color(0xFFfffde7),
      const Color(0xFFfff8e1),
      const Color(0xFFfff3e0),
      const Color(0xFFe8eaf6),
      const Color(0xFFfafafa),
      const Color(0xFFf5f5f5),
      const Color(0xFFeceff1),
      const Color(0xFFcfd8dc),
      const Color(0xFFb0bec5),
      const Color(0xFF90a4ae),
      const Color(0xFFf8bbd9),
      const Color(0xFFe7c3ff),
      const Color(0xFFc3e7ff),
      const Color(0xFFc3ffc3),
      const Color(0xFFFFFFC3),
      const Color(0xFFFFC3C3),
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Color de fondo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                const minBox = 20.0;
                const maxBox = 32.0;
                int crossAxisCount = (maxWidth / (minBox + 6)).floor();
                double boxSize =
                    (maxWidth - (crossAxisCount - 1) * 6) / crossAxisCount;
                if (boxSize > maxBox) boxSize = maxBox;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics()
                      .applyTo(const NeverScrollableScrollPhysics()),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: colors.length,
                  itemBuilder: (ctx, i) =>
                      _buildColorOption(ctx, colors[i], color, size: boxSize),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, Color c, Color selected,
      {double size = 40}) {
    final isSelected = c.value == selected.value;
    return GestureDetector(
      onTap: () {
        onColorSelected(c);
        Navigator.pop(context);
      },
      child: AnimatedScale(
        scale: isSelected ? 1.22 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c,
            border: Border.all(
              color: isSelected ? Colors.amber : Colors.grey.shade400,
              width: isSelected ? 3.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.18),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }
}
