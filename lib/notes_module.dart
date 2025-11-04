import 'dart:async'; // Para Timer
import 'dart:convert'; // Para JSON
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';

import 'package:share_plus/share_plus.dart';
import 'bible_service.dart';
import 'bible_autocomplete_widget.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/rendering.dart'; // Para RenderRepaintBoundary
import 'dart:ui' as ui; // Para ui.Image y ImageByteFormat
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math; // Para cos y sin del menú en abanico

import 'text_format_panel.dart';
import 'note.dart';
import 'note_provider.dart';
import 'audio_mic_fab.dart';
import 'image_gallery_fab.dart';



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
      // ✨ NUEVOS EFECTOS ÚNICOS
      case 'calligraphy_ink':
        _drawCalligraphyInkStroke(canvas, stroke);
        break;
      case 'watercolor':
        _drawWatercolorStroke(canvas, stroke);
        break;
      case 'crystal':
        _drawCrystalStroke(canvas, stroke);
        break;
      case 'spray':
        _drawSprayStroke(canvas, stroke);
        break;
      case 'neon':
        _drawNeonStroke(canvas, stroke);
        break;
      case 'brush_normal':
        _drawBrushStroke(canvas, stroke);
        break;
      case 'brush_thick':
        _drawBrushThickStroke(canvas, stroke);
        break;
      case 'marker':
        _drawMarkerStroke(canvas, stroke);
        break;
      case 'blur':
        _drawBlurStroke(canvas, stroke);
        break;
      // 🔧 HERRAMIENTAS ORIGINALES (compatibilidad)
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
    final random = math.Random(42); // Seed fijo para consistencia

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

  // 🖋️ ===== NUEVO: Efecto de Tinta Caligráfica =====
  void _drawCalligraphyInkStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.length < 2) return;

    // 1. Trazo principal con grosor variable
    final mainPaint =
        CalligraphyInkEffect.createPaint(stroke.color, stroke.strokeWidth);

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      final current = stroke.points[i];

      // Usar curvas suaves para el trazo principal
      if (i == stroke.points.length - 1) {
        path.lineTo(current.dx, current.dy);
      } else {
        final next = stroke.points[math.min(i + 1, stroke.points.length - 1)];
        final controlPoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
            current.dx, current.dy, controlPoint.dx, controlPoint.dy);
      }
    }

    // Dibujar trazo principal
    canvas.drawPath(path, mainPaint);

    // 2. Efectos adicionales: goteo y textura
    final random = math.Random();

    for (int i = 0; i < stroke.points.length; i += 8) {
      final point = stroke.points[i];

      // Goteo sutil
      if (random.nextDouble() < 0.3) {
        final dropPaint = Paint()
          ..color = stroke.color.withOpacity(0.4)
          ..style = PaintingStyle.fill;

        final dropY = point.dy + random.nextDouble() * 6 + 2;
        final dropSize = random.nextDouble() * 1.5 + 0.5;

        canvas.drawCircle(Offset(point.dx, dropY), dropSize, dropPaint);
      }

      // Textura orgánica
      if (random.nextDouble() < 0.4) {
        final texturePaint = Paint()
          ..color = stroke.color.withOpacity(0.2)
          ..style = PaintingStyle.fill;

        final offsetX = (random.nextDouble() - 0.5) * 2;
        final offsetY = (random.nextDouble() - 0.5) * 2;
        final texturePoint = Offset(point.dx + offsetX, point.dy + offsetY);

        canvas.drawCircle(texturePoint, 0.8, texturePaint);
      }
    }
  }

  // 🎨 ===== PLACEHOLDERS para otros efectos =====
  void _drawWatercolorStroke(Canvas canvas, DrawingStroke stroke) {
    // TODO: Implementar acuarela artística
    _drawBrushStroke(canvas, stroke); // Temporal
  }

  void _drawCrystalStroke(Canvas canvas, DrawingStroke stroke) {
    // TODO: Implementar efecto cristal
    _drawPenStroke(canvas, stroke); // Temporal
  }

  void _drawSprayStroke(Canvas canvas, DrawingStroke stroke) {
    // TODO: Implementar spray urbano
    _drawCrayonStroke(canvas, stroke); // Temporal
  }

  void _drawNeonStroke(Canvas canvas, DrawingStroke stroke) {
    // TODO: Implementar neón brillante
    _drawPenStroke(canvas, stroke); // Temporal
  }

  void _drawBrushThickStroke(Canvas canvas, DrawingStroke stroke) {
    final thickStroke = DrawingStroke(
      points: stroke.points,
      color: stroke.color,
      strokeWidth: stroke.strokeWidth * 1.5,
      toolType: stroke.toolType,
    );
    _drawBrushStroke(canvas, thickStroke);
  }

  void _drawMarkerStroke(Canvas canvas, DrawingStroke stroke) {
    final markerPaint = Paint()
      ..color = stroke.color.withOpacity(0.7)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, markerPaint);
  }

  void _drawBlurStroke(Canvas canvas, DrawingStroke stroke) {
    final blurPaint = Paint()
      ..color = stroke.color.withOpacity(0.5)
      ..strokeWidth = stroke.strokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, blurPaint);
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
    with TickerProviderStateMixin {
  // Estado UI
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  // Animation Controller para la biblia
  late AnimationController _bibleAnimationController;
  late Animation<double> _bibleScaleAnimation;
  late Animation<double> _bibleOpacityAnimation;
  late Animation<Offset> _bibleSlideAnimation;

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

  // Controller para el scroll del contenido
  late ScrollController _scrollController;

  // Control de inserciones por drag de texto
  int? _dropInsertIndex;

  // Textos flotantes superpuestos
  final List<FloatingText> _floatingTexts = <FloatingText>[];

  // Formato actual de escritura continua
  TextFormatValue _contentFormat = const TextFormatValue();

  // 🎨 MENÚ DE LÁPICES
  bool _showDrawingToolsMenu = false;
  bool _showColorPalette = false;
  Color _selectedDrawingColor = Colors.black;
  double _selectedBrushSize = 3.0;
  int _selectedBrushType = 0; // 0-4 para diferentes tipos de pincel

  // 📝 MENÚ DE VIÑETAS Y NUMERACIÓN
  bool _showBulletsMenu = false;

  // 📚 MENÚ DE VERSÍCULOS BÍBLICOS
  bool _showBibleMenu = false;
  String _currentBibleStep = 'testament'; // testament, books, chapters, verses
  String _selectedTestament = ''; // NT o AT
  String _selectedBook = '';
  String _selectedChapter = '';
  Map<String, dynamic>? _bibleData;
  List<Map<String, dynamic>> _bibleVerses = [];
  Set<String> _selectedVerses =
      {}; // Versículos seleccionados para inserción múltiple
  ScrollController _versesScrollController =
      ScrollController(); // Para mantener posición del scroll
  ValueNotifier<int> _selectionCounter =
      ValueNotifier<int>(0); // Contador para el botón

  // 📚 Libros del Nuevo Testamento
  final List<String> _ntBooks = [
    'Mateo',
    'Marcos',
    'Lucas',
    'Juan',
    'Hechos',
    'Romanos',
    '1 Corintios',
    '2 Corintios',
    'Gálatas',
    'Efesios',
    'Filipenses',
    'Colosenses',
    '1 Tesalonicenses',
    '2 Tesalonicenses',
    '1 Timoteo',
    '2 Timoteo',
    'Tito',
    'Filemón',
    'Hebreos',
    'Santiago',
    '1 Pedro',
    '2 Pedro',
    '1 Juan',
    '2 Juan',
    '3 Juan',
    'Judas',
    'Apocalipsis'
  ];

  // 📚 Libros del Antiguo Testamento (todos los 39 libros)
  final List<String> _atBooks = [
    'Génesis',
    'Éxodo',
    'Levítico',
    'Números',
    'Deuteronomio',
    'Josué',
    'Jueces',
    'Rut',
    '1 Samuel',
    '2 Samuel',
    '1 Reyes',
    '2 Reyes',
    '1 Crónicas',
    '2 Crónicas',
    'Esdras',
    'Nehemías',
    'Ester',
    'Job',
    'Salmos',
    'Proverbios',
    'Eclesiastés',
    'Cantares',
    'Isaías',
    'Jeremías',
    'Lamentaciones',
    'Ezequiel',
    'Daniel',
    'Oseas',
    'Joel',
    'Amós',
    'Abdías',
    'Jonás',
    'Miqueas',
    'Nahúm',
    'Habacuc',
    'Sofonías',
    'Hageo',
    'Zacarías',
    'Malaquías'
  ];

  // RepaintBoundary para compartir imagen
  final GlobalKey _noteKey = GlobalKey();

  // ======= CLAVES/GEOMETRÍA PARA DELIMITAR ÁREA DE CONTENIDO =======
  final GlobalKey _contentAreaKey = GlobalKey(); // mide el área de ListView
  Rect? _contentRectInStack; // rect relativo al Stack raíz

  // Snackbar manual
  bool _showSavedSnackbar = false;

  // ========= Bible Autocomplete Variables =========
  bool _showBibleAutocomplete = false;
  final TextEditingController _bibleController = TextEditingController();

  // OPTIMIZACIÓN: Debounce mejorado para _saveNote
  Timer? _saveDebounceTimer;

  // OPTIMIZACIÓN: Cache para evitar cálculos repetitivos
  Timer? _contentRectUpdateTimer;

  // ========= Sistema de Dibujo Libre =========
  final List<DrawingStroke> _drawingStrokes = <DrawingStroke>[];
  bool _isDrawingMode = false;
  DrawingStroke? _currentStroke;

  // ========= Header Collapsible =========
  bool _isHeaderCollapsed = false;

  // ========= Floating Buttons Collapsible =========
  bool _isFloatingButtonsCollapsed = false;

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

  /// 📝 Funciones para viñetas y numeración
  void _addBulletPoint(String bulletType) {
    setState(() {
      // Agregar viñeta al texto actual del _hiddenController
      final String currentText = _hiddenController.text;
      final int cursorPosition = _hiddenController.selection.start;

      // Insertar la viñeta en la posición actual del cursor
      final String beforeCursor = currentText.substring(0, cursorPosition);
      final String afterCursor = currentText.substring(cursorPosition);

      final String newText = beforeCursor + '$bulletType ' + afterCursor;

      _hiddenController.text = newText;

      // Posicionar el cursor después de la viñeta y el espacio
      _hiddenController.selection = TextSelection.collapsed(
          offset: cursorPosition + bulletType.length + 1);

      _showBulletsMenu = false; // Cerrar el menú
    });
  }

  void _addNumberedList() {
    int nextNumber = 1;
    int maxFoundNumber = 0;

    // Revisar todos los párrafos guardados en _contentParts
    for (final part in _contentParts) {
      final text = part.text;
      // Buscar todos los números en formato "X. " en cualquier parte del texto
      final numberMatches = RegExp(r'(\d+)\.\s').allMatches(text);
      for (final match in numberMatches) {
        final number = int.parse(match.group(1)!);
        if (number > maxFoundNumber) {
          maxFoundNumber = number;
        }
      }
    }

    // También revisar en el texto actual del _hiddenController
    final currentText = _hiddenController.text;
    final currentMatches = RegExp(r'(\d+)\.\s').allMatches(currentText);
    for (final match in currentMatches) {
      final number = int.parse(match.group(1)!);
      if (number > maxFoundNumber) {
        maxFoundNumber = number;
      }
    }

    // El siguiente número es el máximo encontrado + 1
    nextNumber = maxFoundNumber + 1;

    setState(() {
      // Agregar numeración al texto actual del _hiddenController
      final int cursorPosition = _hiddenController.selection.start;

      // Insertar el número en la posición actual del cursor
      final String beforeCursor = currentText.substring(0, cursorPosition);
      final String afterCursor = currentText.substring(cursorPosition);

      final String newText = beforeCursor + '$nextNumber. ' + afterCursor;

      _hiddenController.text = newText;

      // Posicionar el cursor después del número y el espacio
      _hiddenController.selection = TextSelection.collapsed(
          offset: cursorPosition + '$nextNumber. '.length);

      _showBulletsMenu = false; // Cerrar el menú
    });
  }

  void _addIndentation() {
    setState(() {
      // Agregar sangría al texto actual del _hiddenController
      final String currentText = _hiddenController.text;
      final int cursorPosition = _hiddenController.selection.start;

      // Insertar la sangría en la posición actual del cursor
      final String beforeCursor = currentText.substring(0, cursorPosition);
      final String afterCursor = currentText.substring(cursorPosition);

      final String newText = beforeCursor + '    ➤ ' + afterCursor;

      _hiddenController.text = newText;

      // Posicionar el cursor después de la sangría y el espacio
      _hiddenController.selection = TextSelection.collapsed(
          offset: cursorPosition + 6 // '    ➤ ' tiene 6 caracteres
          );

      _showBulletsMenu = false; // Cerrar el menú
    });
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

    // Determinar herramienta - Sistema NUEVO de menú flotante de lápices
    String toolType = '';
    Color color = Colors.black;
    double strokeWidth = 2.0;

    // 🎨 NUEVO: Usar herramientas del menú flotante si está activo
    if (_showDrawingToolsMenu) {
      switch (_selectedBrushType) {
        case 0: // Pincel Normal
          toolType = 'brush_normal';
          color = _selectedDrawingColor;
          strokeWidth = _selectedBrushSize;
          break;
        case 1: // Lápiz Fino - TINTA CALIGRÁFICA ✨
          toolType = 'calligraphy_ink';
          color = _selectedDrawingColor;
          strokeWidth = _selectedBrushSize;
          break;
        case 2: // Pincel Grueso
          toolType = 'brush_thick';
          color = _selectedDrawingColor;
          strokeWidth = _selectedBrushSize;
          break;
        case 3: // Difuminado
          toolType = 'blur';
          color = _selectedDrawingColor;
          strokeWidth = _selectedBrushSize;
          break;
        case 4: // Marcador
          toolType = 'marker';
          color = _selectedDrawingColor;
          strokeWidth = _selectedBrushSize;
          break;
      }
    }
    // Sistema ANTIGUO de botones (mantener compatibilidad)
    else if (_contentFormat.pencil) {
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
      DrawingStroke finalStroke = _currentStroke!;

      // 🎨 Aplicar efectos únicos según el tipo de herramienta
      if (finalStroke.toolType == 'calligraphy_ink') {
        // Aplicar efecto de tinta caligráfica
        final enhancedPoints = CalligraphyInkEffect.applyEffect(
          finalStroke.points,
          color: finalStroke.color,
          baseSize: finalStroke.strokeWidth,
          canvasSize: Size(800, 1200), // Tamaño aproximado del canvas
        );

        finalStroke = DrawingStroke(
          points: enhancedPoints,
          color: finalStroke.color,
          strokeWidth: finalStroke.strokeWidth,
          toolType: finalStroke.toolType,
        );
      }

      _drawingStrokes.add(finalStroke);
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

  // ========= Header Collapsible Methods =========

  void _toggleHeaderCollapse() {
    setState(() {
      _isHeaderCollapsed = !_isHeaderCollapsed;
    });
    _saveHeaderCollapseState();
  }

  void _saveHeaderCollapseState() {
    widget.note.isHeaderCollapsed = _isHeaderCollapsed;
    _saveNote(pop: false);
  }

  void _loadHeaderCollapseState() {
    _isHeaderCollapsed = widget.note.isHeaderCollapsed ?? false;
  }

  // ========= Floating Buttons Collapsible Methods =========

  void _toggleFloatingButtonsCollapse() {
    setState(() {
      _isFloatingButtonsCollapsed = !_isFloatingButtonsCollapsed;
    });
    _saveFloatingButtonsCollapseState();
  }

  void _saveFloatingButtonsCollapseState() {
    widget.note.isFloatingButtonsCollapsed = _isFloatingButtonsCollapsed;
    _saveNote(pop: false);
  }

  void _loadFloatingButtonsCollapseState() {
    _isFloatingButtonsCollapsed =
        widget.note.isFloatingButtonsCollapsed ?? false;
  }

  // ========= Header Flotante Mini - Widgets =========

  Widget _buildMiniFloatingHeader() {
    return Row(
      key: const ValueKey('mini'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador de categoría minimalista
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _categoriaController.text.isNotEmpty
                ? Colors.blue.shade400
                : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),

        // Texto de categoría ultra compacto
        Expanded(
          child: Text(
            _categoriaController.text.isNotEmpty
                ? _categoriaController.text
                : 'Sin categoría',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),

        const SizedBox(width: 4),

        // Botón expandir ultra compacto
        GestureDetector(
          onTap: _toggleHeaderCollapse,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue.shade100.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.expand_more,
              size: 12,
              color: Colors.blue.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedFloatingHeader() {
    return Column(
      key: const ValueKey('expanded'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primera fila: Fecha y hora
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(widget.note.date),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Botón colapsar
            GestureDetector(
              onTap: _toggleHeaderCollapse,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: AnimatedRotation(
                  turns: 0.5,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_less,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Segunda fila: Categoría y selector
        Row(
          children: [
            // Indicador de categoría
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _categoriaController.text.isNotEmpty
                    ? Colors.green.shade400
                    : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),

            // Texto de categoría
            Expanded(
              child: Text(
                _categoriaController.text.isNotEmpty
                    ? _categoriaController.text
                    : 'Sin categoría',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            const SizedBox(width: 8),

            // Selector de categoría compacto
            GestureDetector(
              onTap: () async {
                final selected = await showMenu<String>(
                  context: context,
                  position: const RelativeRect.fromLTRB(200, 80, 16, 0),
                  items: const [
                    PopupMenuItem(value: 'Sermón', child: Text('📖  Sermón')),
                    PopupMenuItem(
                        value: 'Estudio Bíblico',
                        child: Text('📚  Estudio Bíblico')),
                    PopupMenuItem(
                        value: 'Reflexión', child: Text('🤔  Reflexión')),
                    PopupMenuItem(
                        value: 'Devocional', child: Text('❤️  Devocional')),
                    PopupMenuItem(
                        value: 'Testimonio', child: Text('🌟  Testimonio')),
                    PopupMenuItem(
                        value: 'Apuntes Generales',
                        child: Text('📓  Apuntes Generales')),
                    PopupMenuItem(
                        value: 'Discipulado', child: Text('🏫  Discipulado')),
                    PopupMenuItem(
                        value: 'Conexion', child: Text('🔗  Conexion')),
                    PopupMenuItem(value: 'Música', child: Text('🎵  Música')),
                    PopupMenuItem(value: 'Cita', child: Text('💬  Cita')),
                    PopupMenuItem(
                        value: 'Versículo', child: Text('📜  Versículo')),
                    PopupMenuItem(value: 'Oración', child: Text('🙏  Oración')),
                    PopupMenuItem(value: 'Culto', child: Text('⛪  Culto')),
                    PopupMenuItem(value: 'Otro', child: Text('🌀  Otro')),
                  ],
                );
                if (selected != null) {
                  setState(() {
                    _categoriaController.text = selected;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200, width: 0.5),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: Colors.orange.shade600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========= Floating Buttons Collapsible - Widgets =========

  Widget _buildMiniFloatingButtons() {
    return Container(
      key: const ValueKey('mini-buttons'),
      width: 50,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade100.withOpacity(0.9),
            Colors.white.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _toggleFloatingButtonsCollapse,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.unfold_more,
              size: 16,
              color: Colors.blue.shade600,
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.mic,
              size: 14,
              color: Colors.green.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFloatingButtons() {
    return Column(
      key: const ValueKey('expanded-buttons'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón colapsar en la parte superior
        GestureDetector(
          onTap: _toggleFloatingButtonsCollapse,
          child: Container(
            width: 60,
            height: 25,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: Icon(
              Icons.unfold_less,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        // Botón de imágenes (nuevo - arriba del audio)
        ImageButton(noteId: widget.note.id.toString()),

        const SizedBox(height: 12),

        // Botón de audio (el original)
        AudioButton(noteId: widget.note.id.toString()),
      ],
    );
  }

  // ========= Bible Verse Methods =========

  Future<void> _addBibleVerse() async {
    // Cargar biblia si no está cargada
    await BibleService.instance.loadBible();

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

    // Mostrar el autocomplete de versículos
    setState(() {
      _showBibleAutocomplete = true;
    });

    _bibleController.clear();
    _bibleAnimationController.forward();
  }

  void _onVerseSelected(BibleVerse verse) {
    // Ocultar el autocomplete
    setState(() {
      _showBibleAutocomplete = false;
    });

    // 🎯 Agregar al historial de versículos usados
    BibleService.instance.addToHistory(verse);

    // Agregar el versículo seleccionado
    setState(() {
      _contentParts.add(_TextPart(
        '📖 ${verse.fullText}',
        true, // bold para destacar
        false, // underline
        null, // underlineColor
        true, // highlight con color bíblico
        0xFFF3E8FF, // Color púrpura muy suave
        false, // no es imagen especial
      ));
    });

    _saveNote(pop: false);

    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Versículo añadido: ${verse.reference}'),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 2),
      ),
    );

    // Enfocar de nuevo el campo de texto principal
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_hiddenFocus);
      }
    });
  }

  void _cancelBibleAutocomplete() {
    _bibleAnimationController.reverse().then((_) {
      setState(() {
        _showBibleAutocomplete = false;
      });
    });
    _bibleController.clear();
  }

  void _onMultipleVersesSelected(List<BibleVerse> verses) {
    // Ocultar el autocomplete
    setState(() {
      _showBibleAutocomplete = false;
    });

    // Agregar cada versículo al historial y a la nota
    for (final verse in verses) {
      // 🎯 Agregar al historial de versículos usados
      BibleService.instance.addToHistory(verse);

      // Agregar el versículo seleccionado
      _contentParts.add(_TextPart(
        '📖 ${verse.fullText}',
        true, // bold para destacar
        false, // underline
        null, // underlineColor
        true, // highlight con color bíblico
        0xFFF3E8FF, // Color púrpura muy suave
        false, // no es imagen especial
      ));
    }

    setState(() {}); // Actualizar UI

    _saveNote(pop: false);

    // Mostrar confirmación
    final verseCount = verses.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(verseCount == 1
            ? 'Versículo añadido: ${verses.first.reference}'
            : '$verseCount versículos añadidos exitosamente'),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 3),
      ),
    );

    // Enfocar de nuevo el campo de texto principal
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_hiddenFocus);
      }
    });
  }

  void _processBibleReference(String reference) {
    if (reference.trim().isEmpty) return;

    // Buscar versículo
    final verse = BibleService.instance.searchVerse(reference);

    if (verse != null) {
      // Reemplazar placeholder con versículo encontrado
      final lastPartIndex = _contentParts.length - 1;
      if (lastPartIndex >= 0 && _contentParts[lastPartIndex].isImage) {
        setState(() {
          _contentParts[lastPartIndex] = _TextPart(
            '📖 ${verse.fullText}',
            true, // bold para destacar
            false, // underline
            null, // underlineColor
            true, // highlight con color bíblico
            0xFFF3E8FF, // Color púrpura muy suave
            false, // no es imagen especial
          );
        });
        _hiddenController.clear(); // Limpiar el input
        _saveNote(pop: false);

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Versículo añadido: ${verse.reference}'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Mostrar mensaje de no encontrado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Versículo no encontrado: $reference'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ========= Save Note =========

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
            _contentFormat
                .bold, // RESTAURADO: negrilla se aplica al texto principal
            _contentFormat
                .underline, // RESTAURADO: subrayado se aplica al texto principal
            _contentFormat.underline
                ? _contentFormat.underlineColor.value
                : null,
            _contentFormat
                .highlight, // RESTAURADO: resaltado se aplica al texto principal
            _contentFormat.highlight
                ? _contentFormat.highlightColor.value
                : null,
            false,
          ),
        );
      }
    }

    note.contentParts = partsToSave.map((e) => e.toJson()).toList();
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

  /// 🎨 Menú flotante de herramientas de dibujo (estilo de la imagen)
  Widget _buildDrawingToolsMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Selector de color (círculo multicolor)
            _buildColorPicker(),

            // Separador
            Container(width: 1, height: 30, color: Colors.white24),

            // 5 tipos de lápices/pinceles
            ..._buildBrushTools(),
          ],
        ),
      ),
    );
  }

  /// 🎨 Paletas de colores temáticas
  static const Map<String, List<Color>> _colorThemes = {
    'Básicos': [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFF795548),
      Color(0xFF607D8B),
    ],
    'Pasteles': [
      Color(0xFFFFCDD2),
      Color(0xFFF8BBD9),
      Color(0xFFE1BEE7),
      Color(0xFFD1C4E9),
      Color(0xFFC5CAE9),
      Color(0xFFBBDEFB),
      Color(0xFFB2EBF2),
      Color(0xFFB2DFDB),
    ],
    'Vibrantes': [
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
      Color(0xFF3F51B5),
      Color(0xFF2196F3),
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF4CAF50),
    ],
    'Neón': [
      Color(0xFF00FFFF),
      Color(0xFF00FF00),
      Color(0xFFFFFF00),
      Color(0xFFFF00FF),
      Color(0xFFFF0080),
      Color(0xFF8000FF),
      Color(0xFF0080FF),
      Color(0xFF80FF00),
    ],
  };

  /// 🎨 Selector de color circular
  Widget _buildColorPicker() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showColorPalette = !_showColorPalette;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
              Colors.red,
            ],
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _selectedDrawingColor,
          ),
        ),
      ),
    );
  }

  /// 🌈 Paleta de colores temática completa
  Widget _buildColorPalette() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎨 Paleta de Colores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showColorPalette = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Temas de colores
            ..._colorThemes.entries.map((themeEntry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título del tema
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      themeEntry.key,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Colores del tema
                  Container(
                    height: 45,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: themeEntry.value.length,
                      itemBuilder: (context, index) {
                        final color = themeEntry.value[index];
                        final isSelected = _selectedDrawingColor == color;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDrawingColor = color;
                              // Cerrar la paleta después de seleccionar
                              _showColorPalette = false;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// 🖌️ Herramientas de pincel
  List<Widget> _buildBrushTools() {
    final brushIcons = [
      Icons.brush_rounded, // Pincel normal
      Icons.edit_rounded, // Lápiz fino
      Icons.format_paint_rounded, // Pincel grueso
      Icons.blur_on_rounded, // Difuminado
      Icons.highlight_rounded, // Marcador
    ];

    return List.generate(5, (index) {
      final isSelected = _selectedBrushType == index;
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedBrushType = index;
            // Ajustar tamaño según tipo de pincel
            switch (index) {
              case 0:
                _selectedBrushSize = 3.0;
                break; // Normal
              case 1:
                _selectedBrushSize = 1.5;
                break; // Fino
              case 2:
                _selectedBrushSize = 6.0;
                break; // Grueso
              case 3:
                _selectedBrushSize = 8.0;
                break; // Difuminado
              case 4:
                _selectedBrushSize = 12.0;
                break; // Marcador
            }
          });
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            brushIcons[index],
            color: isSelected ? Colors.white : Colors.white70,
            size: 20,
          ),
        ),
      );
    });
  }

  // � Botón estilo Glass Morphism con efectos translúcidos
  /// � Menú flotante de versículos bíblicos (estilo uniforme)
  Widget _buildBibleMenu() {
    switch (_currentBibleStep) {
      case 'testament':
        return _buildTestamentMenu();
      case 'books':
        return _buildBooksMenu();
      case 'chapters':
        return _buildChaptersMenu();
      case 'verses':
        return _buildVersesMenu();
      default:
        return _buildTestamentMenu();
    }
  }

  /// 📖 Menú inicial: NT vs AT (compacto)
  /// 📖 Menú AT/NT simple e intuitivo (responsivo)
  Widget _buildTestamentMenu() {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculamos tamaños responsivos basados en el ancho disponible
          final screenWidth = MediaQuery.of(context).size.width;
          final containerWidth = math.min(
              screenWidth * 0.7, 300.0); // Máximo 70% del ancho o 300px
          final buttonWidth = (containerWidth - 80) /
              2; // Ancho disponible dividido por 2 botones

          return Container(
            width: containerWidth,
            height: 75, // Aumentamos 5px para evitar overflow
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04, // 4% del ancho de pantalla
              vertical: 6, // Reducimos padding vertical
            ),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Título arriba
                Text(
                  'Agregar Cita Bíblica',
                  style: TextStyle(
                    fontSize: math.max(
                        screenWidth * 0.03, 10.0), // Mínimo 10px, escalable
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4), // Reducimos de 6 a 4px
                // Botones abajo - responsivos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSimpleButton('AT', buttonWidth),
                    _buildSimpleButton('NT', buttonWidth),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleButton(String text, [double? width]) {
    bool isSelected = _selectedTestament == text;
    final screenWidth = MediaQuery.of(context).size.width;

    // Ancho responsivo: usa el parámetro si se proporciona, sino calcula automáticamente
    final buttonWidth = width ??
        math.max(screenWidth * 0.15, 50.0); // Mínimo 50px, máximo 15% pantalla
    final buttonHeight =
        math.max(screenWidth * 0.08, 28.0); // Altura proporcional, mínimo 28px
    final fontSize =
        math.max(screenWidth * 0.035, 12.0); // Texto escalable, mínimo 12px

    return GestureDetector(
      onTap: () => _selectTestament(text),
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(
              buttonHeight * 0.5), // Radio proporcional a la altura
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 📚 Seleccionar testamento y mostrar libros
  void _selectTestament(String testament) {
    setState(() {
      _selectedTestament = testament;
      _currentBibleStep = 'books';
    });
  }

  /// 📚 Menú de libros bíblicos (claro y funcional)
  Widget _buildBooksMenu() {
    final books = _selectedTestament == 'NT' ? _ntBooks : _atBooks;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 350, // Más grande para ver mejor los libros
          maxWidth: 320, // Más ancho
        ),
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Fondo más sólido y visible
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900.withOpacity(0.95), // Misma paleta azul
              Colors.blue.shade800.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.4), // Borde más visible
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4), // Sombra más fuerte
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con título y botón cerrar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedTestament == 'NT'
                        ? 'Nuevo Testamento'
                        : 'Antiguo Testamento',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBibleStep = 'testament';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Grid de libros con scroll
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 columnas para mejor legibilidad
                  childAspectRatio: 2.2, // Mejor proporción
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  return _buildBookOption(books[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookOption(String book) {
    return GestureDetector(
      onTap: () => _selectBook(book),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          // Fondo más sólido y visible
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9), // Mucho más sólido
              Colors.white.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            book,
            style: const TextStyle(
              fontSize: 11, // Texto más grande
              fontWeight: FontWeight.bold,
              color: Colors.black87, // Texto oscuro sobre fondo blanco
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// 📖 Seleccionar libro y mostrar capítulos
  void _selectBook(String book) {
    setState(() {
      _selectedBook = book;
      _currentBibleStep = 'chapters';
    });
  }

  /// 📖 Seleccionar capítulo y mostrar versículos
  void _selectChapter(String chapter) {
    setState(() {
      _selectedChapter = chapter;
      _selectedVerses.clear(); // Limpiar selecciones anteriores
      _selectionCounter.value = 0; // Resetear contador
      _currentBibleStep =
          'verses'; // Ir a la pantalla de versículos con checkboxes
    });

    // Resetear scroll al inicio para nuevo capítulo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_versesScrollController.hasClients) {
        _versesScrollController.jumpTo(0);
      }
    });
  }

  /// � Menú de capítulos del libro seleccionado
  Widget _buildChaptersMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 320, // Altura fija más compacta
          maxWidth: 300, // Ancho fijo
        ),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Fondo más sólido y visible
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900
                  .withOpacity(0.95), // Misma paleta azul consistente
              Colors.blue.shade800.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.4), // Borde más visible
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5), // Sombra más fuerte
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header con título y botón cerrar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Capítulos de $_selectedBook',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBibleStep = 'books';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // FutureBuilder para cargar capítulos dinámicamente
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _getBookChapters(_selectedBook),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error cargando capítulos',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final bookChapters = snapshot.data ?? [];

                  return GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: bookChapters.length,
                    itemBuilder: (context, index) {
                      return _buildChapterOption(bookChapters[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterOption(String chapter) {
    return GestureDetector(
      onTap: () => _selectChapter(chapter),
      child: Container(
        decoration: BoxDecoration(
          // Fondo más sólido y visible
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9), // Mucho más sólido
              Colors.white.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            chapter,
            style: const TextStyle(
              fontSize: 16, // Texto más grande
              fontWeight: FontWeight.bold,
              color: Colors.black87, // Texto oscuro sobre fondo blanco
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMenu(String message) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// �📝 Menú de versículos populares (pantalla completa)
  Widget _buildVersesMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 400, // Altura apropiada para ver versículos
          maxWidth: 340, // Ancho adecuado
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Fondo consistente con las otras tarjetas
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900.withOpacity(0.95), // Misma paleta azul
              Colors.blue.shade800.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header con título y botón regresar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$_selectedBook $_selectedChapter',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBibleStep = 'chapters';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // FutureBuilder para cargar versículos dinámicamente
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getChapterVerses(_selectedBook, _selectedChapter),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error cargando versículos',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final chapterVerses = snapshot.data ?? [];

                  return Column(
                    children: [
                      // Lista de versículos
                      Expanded(
                        child: ListView.builder(
                          controller: _versesScrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: chapterVerses.length,
                          itemBuilder: (context, index) {
                            final verse = chapterVerses[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: _buildVerseOptionFromBible(verse),
                            );
                          },
                        ),
                      ),
                      // Botón para insertar múltiples versículos (solo se reconstruye cuando cambia)
                      ValueListenableBuilder<int>(
                        valueListenable: _selectionCounter,
                        builder: (context, count, child) {
                          if (count == 0) return const SizedBox.shrink();

                          return Column(
                            children: [
                              // Botón para insertar versículos seleccionados
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 12),
                                child: ElevatedButton.icon(
                                  onPressed: () => _insertSelectedVerses(),
                                  icon: const Icon(Icons.add,
                                      color: Colors.white),
                                  label: Text(
                                    'Insertar $count versículo${count > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              // Botón para cancelar selecciones
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedVerses.clear();
                                      _selectionCounter.value = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white70),
                                  label: const Text(
                                    'Cancelar selección',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseOptionFromBible(Map<String, dynamic> verse) {
    final reference =
        '${verse['book_name']} ${verse['chapter']}:${verse['verse']}';
    final text = verse['text'] as String;
    final verseId =
        '${verse['book_name']}_${verse['chapter']}_${verse['verse']}';
    final isSelected = _selectedVerses.contains(verseId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.green.withOpacity(0.4)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Si hay versículos seleccionados, cambiar modo selección
            if (_selectedVerses.isNotEmpty) {
              setState(() {
                if (isSelected) {
                  _selectedVerses.remove(verseId);
                } else {
                  _selectedVerses.add(verseId);
                }
                _selectionCounter.value = _selectedVerses.length;
              });
              return;
            }

            // Comportamiento normal: insertar versículo individual
            _insertSingleVerse(verse, reference, text);
          },
          onLongPress: () {
            // Activar modo selección múltiple con long press
            setState(() {
              if (_selectedVerses.isEmpty) {
                // Iniciar selección múltiple con este versículo
                _selectedVerses.add(verseId);
                _selectionCounter.value = 1;

                // Mostrar feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Modo selección múltiple activado'),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                // Toggle selección del versículo
                if (isSelected) {
                  _selectedVerses.remove(verseId);
                } else {
                  _selectedVerses.add(verseId);
                }
                _selectionCounter.value = _selectedVerses.length;
              }
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                  if (isSelected) SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      // Si hay selecciones múltiples, mostrar solo el número del versículo
                      _selectedVerses.isNotEmpty
                          ? 'Versículo ${verse['verse']}'
                          : reference,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.green : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.green.shade200 : Colors.white70,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función para insertar un versículo individual
  void _insertSingleVerse(
      Map<String, dynamic> verse, String reference, String text) {
    print('🔥 VERSÍCULO PRESIONADO: $reference');

    // Extraer número del versículo y agregar punto
    final verseNumber = verse['verse'];
    final formattedText = '$verseNumber.${text.trimLeft()}';
    print('🔥 DEBUG - Número: $verseNumber, Texto formateado: $formattedText');

    // Insertar como NUEVO PÁRRAFO independiente con formato correcto
    final verseText = '📖 $reference\n$formattedText';
    print('🔥 Texto a insertar: $verseText');

    // SIEMPRE crear una nueva parte para el versículo
    final newPartIndex = widget.note.contentParts.length;
    print('🔥 ContentParts antes: ${widget.note.contentParts.length}');

    widget.note.contentParts.add({
      'text': verseText,
      'bold': false,
      'italic': false,
      'underline': false,
      'fontSize': widget.note.contentFontSize,
    });

    print('🔥 ContentParts después: ${widget.note.contentParts.length}');
    print('🔥 Nueva parte creada en índice: $newPartIndex');

    // TAMBIÉN agregar a _contentParts como UN SOLO bloque pegado
    final completeText = '📖 $reference\n$formattedText';
    _contentParts.add(_TextPart(completeText, false));
    print(
        '🔥 Agregado a _contentParts como bloque único. Total visual: ${_contentParts.length}');

    // CREAR controller para la nueva parte
    _partControllers[newPartIndex] = TextEditingController();
    final controller = _partControllers[newPartIndex]!;
    controller.text = verseText;
    print('🔥 Controller creado y actualizado');

    // Mover cursor al final
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    // Forzar actualización COMPLETA de la UI
    setState(() {
      // Forzar rebuild completo del widget
    });

    // Verificar que el widget se está actualizando
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          '🔥 UI actualizada. Partes totales: ${widget.note.contentParts.length}');
      print('🔥 Controllers totales: ${_partControllers.length}');
    });

    // Cerrar menú bíblico después del repaint
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showBibleMenu = false;
          _currentBibleStep = 'testament';
          _selectedTestament = '';
          _selectedBook = '';
          _selectedChapter = '';
        });
      }
    });

    print('🔥 Guardando nota...');
    // Guardar cambios
    _saveNote(pop: false);
    print(
        '🔥 ¡Nota guardada! Total partes: ${widget.note.contentParts.length}');
  }

  // Función para insertar todos los versículos seleccionados
  void _insertSelectedVerses() async {
    try {
      final verses = await _getChapterVerses(_selectedBook, _selectedChapter);
      final selectedVersesList = <Map<String, dynamic>>[];

      // Filtrar solo los versículos seleccionados
      for (final verse in verses) {
        final verseId =
            '${verse['book_name']}_${verse['chapter']}_${verse['verse']}';
        if (_selectedVerses.contains(verseId)) {
          selectedVersesList.add(verse);
        }
      }

      if (selectedVersesList.isNotEmpty) {
        // Ordenar versículos por número
        selectedVersesList.sort((a, b) => int.parse(a['verse'].toString())
            .compareTo(int.parse(b['verse'].toString())));

        // Crear referencia agrupada
        final bookName = selectedVersesList.first['book_name'];
        final chapter = selectedVersesList.first['chapter'];
        final verseNumbers =
            selectedVersesList.map((v) => v['verse'].toString()).toList();

        String groupedReference;
        if (verseNumbers.length == 1) {
          groupedReference = '$bookName $chapter:${verseNumbers.first}';
        } else {
          // Crear rango compacto (ej: "Juan 3:16-18" o "Juan 3:16, 18-20")
          groupedReference =
              '$bookName $chapter:${_formatVerseRange(verseNumbers)}';
        }

        // Crear UN SOLO TextPart con todo pegado
        final StringBuffer completeText = StringBuffer();

        // 1. Agregar referencia
        completeText.write('📖 $groupedReference\n');

        // 2. Agregar todos los versículos cada uno en su línea
        for (int i = 0; i < selectedVersesList.length; i++) {
          final verse = selectedVersesList[i];
          final verseText = verse['text'] ?? '';
          final verseNumber = verse['verse'] ?? '';

          // Cada versículo en su propia línea con punto después del número
          final formattedVerse = '$verseNumber.${verseText.trimLeft()}';
          print('🔥 DEBUG MÚLTIPLE - Verso $verseNumber: $formattedVerse');
          completeText.write(formattedVerse);

          // Agregar pequeño espacio entre versículos para estética
          if (i < selectedVersesList.length - 1) {
            completeText.write('\n\n');
          }
        }

        // Crear un solo TextPart con todo el contenido
        _contentParts.add(_TextPart(completeText.toString(),
            false)); // Crear un texto plano para contentParts (para persistencia)
        final StringBuffer plainText = StringBuffer();
        plainText.write('📖 $groupedReference\n');
        for (int i = 0; i < selectedVersesList.length; i++) {
          final verse = selectedVersesList[i];
          final verseText = verse['text'] ?? '';
          final verseNumber = verse['verse'] ?? '';
          plainText.write('$verseNumber.${verseText.trimLeft()}');

          // Agregar pequeño espacio entre versículos para estética
          if (i < selectedVersesList.length - 1) {
            plainText.write('\n\n');
          }
        }

        // Insertar usando el sistema actual de contentParts
        final newPartIndex = widget.note.contentParts.length;

        widget.note.contentParts.add({
          'text': plainText.toString(),
          'bold': false,
          'italic': false,
          'underline': false,
          'fontSize': widget.note.contentFontSize,
        });

        // Crear controller para la nueva parte
        _partControllers[newPartIndex] = TextEditingController();
        final controller = _partControllers[newPartIndex]!;
        controller.text = plainText.toString();

        // Mover cursor al final
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );

        // Actualizar UI
        setState(() {
          _selectedVerses.clear();
          _selectionCounter.value = 0;
          _showBibleMenu = false;
          _currentBibleStep = 'testament';
          _selectedTestament = '';
          _selectedBook = '';
          _selectedChapter = '';
        });

        // Guardar cambios
        _saveNote(pop: false);

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${selectedVersesList.length} versículos añadidos: $groupedReference'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error insertando versículos: $e');
    }
  }

  // Función auxiliar para formatear rangos de versículos
  String _formatVerseRange(List<String> verseNumbers) {
    if (verseNumbers.isEmpty) return '';
    if (verseNumbers.length == 1) return verseNumbers.first;

    final numbers = verseNumbers.map(int.parse).toList()..sort();
    final ranges = <String>[];
    int start = numbers.first;
    int end = start;

    for (int i = 1; i < numbers.length; i++) {
      if (numbers[i] == end + 1) {
        end = numbers[i];
      } else {
        // Finalizar rango actual
        if (start == end) {
          ranges.add(start.toString());
        } else {
          ranges.add('$start-$end');
        }
        start = numbers[i];
        end = start;
      }
    }

    // Agregar último rango
    if (start == end) {
      ranges.add(start.toString());
    } else {
      ranges.add('$start-$end');
    }

    return ranges.join(', ');
  }

  Widget _buildVerseOption(Map<String, String> verse) {
    return GestureDetector(
      onTap: () => _insertVerse(verse),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse['reference']!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              verse['text']!,
              style: const TextStyle(
                fontSize: 8,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 📖 Obtener versículos populares por libro
  List<Map<String, String>> _getPopularVerses(String book) {
    final popularVerses = {
      'Juan': [
        {
          'reference': 'Juan 3:16',
          'text': 'Porque de tal manera amó Dios al mundo...'
        },
        {
          'reference': 'Juan 8:32',
          'text': 'Y conoceréis la verdad, y la verdad os hará libres...'
        },
        {
          'reference': 'Juan 14:6',
          'text': 'Yo soy el camino, la verdad y la vida...'
        },
      ],
      'Salmos': [
        {
          'reference': 'Salmos 23:1',
          'text': 'Jehová es mi pastor, nada me faltará...'
        },
        {
          'reference': 'Salmos 46:10',
          'text': 'Estad quietos, y conoced que yo soy Dios...'
        },
        {
          'reference': 'Salmos 118:24',
          'text': 'Este es el día que hizo Jehová...'
        },
      ],
      'Filipenses': [
        {
          'reference': 'Filipenses 4:13',
          'text': 'Todo lo puedo en Cristo que me fortalece...'
        },
        {
          'reference': 'Filipenses 4:19',
          'text': 'Mi Dios, pues, suplirá todo lo que os falta...'
        },
      ],
      'Romanos': [
        {
          'reference': 'Romanos 8:28',
          'text': 'Y sabemos que a los que aman a Dios...'
        },
        {
          'reference': 'Romanos 10:9',
          'text': 'Si confesares con tu boca que Jesús es el Señor...'
        },
      ],
      'Proverbios': [
        {
          'reference': 'Proverbios 3:5-6',
          'text': 'Fíate de Jehová de todo tu corazón...'
        },
        {
          'reference': 'Proverbios 16:9',
          'text': 'El corazón del hombre piensa su camino...'
        },
      ],
      'Mateo': [
        {
          'reference': 'Mateo 6:33',
          'text': 'Mas buscad primeramente el reino de Dios...'
        },
        {
          'reference': 'Mateo 11:28',
          'text': 'Venid a mí todos los que estáis trabajados...'
        },
      ],
      'Malaquías': [
        {
          'reference': 'Malaquías 1:11',
          'text':
              'Porque desde donde el sol nace hasta donde se pone, es grande mi nombre...'
        },
        {
          'reference': 'Malaquías 2:10',
          'text':
              '¿No tenemos todos un mismo padre? ¿No nos ha creado un mismo Dios?'
        },
        {
          'reference': 'Malaquías 3:6',
          'text':
              'Porque yo Jehová no cambio; por esto, hijos de Jacob, no habéis sido consumidos.'
        },
        {
          'reference': 'Malaquías 3:7',
          'text':
              'Desde los días de vuestros padres os habéis apartado de mis leyes...'
        },
        {
          'reference': 'Malaquías 3:10',
          'text':
              'Traed todos los diezmos al alfolí y haya alimento en mi casa...'
        },
        {
          'reference': 'Malaquías 4:2',
          'text':
              'Mas a vosotros los que teméis mi nombre, nacerá el Sol de justicia...'
        },
      ],
    };

    return popularVerses[book] ??
        [
          {
            'reference': '$book 1:1',
            'text': 'Versículo de ejemplo para $book...'
          },
        ];
  }

  /// 📖 Insertar versículo seleccionado
  void _insertVerse(Map<String, String> verse) {
    final verseText = '📖 ${verse['reference']}: ${verse['text']}';

    setState(() {
      final currentText = _hiddenController.text;
      final cursorPosition = _hiddenController.selection.start;

      final beforeCursor = currentText.substring(0, cursorPosition);
      final afterCursor = currentText.substring(cursorPosition);

      _hiddenController.text = beforeCursor + verseText + afterCursor;
      _hiddenController.selection =
          TextSelection.collapsed(offset: cursorPosition + verseText.length);

      _showBibleMenu = false;
      _currentBibleStep = 'testament'; // Reset para próxima vez
    });
  }

  /// 📖 Insertar versículo desde datos completos de la Biblia
  void _insertVerseFromBible(Map<String, dynamic> verse) {
    final reference =
        '${verse['book_name']} ${verse['chapter']}:${verse['verse']}';
    final text = verse['text'] as String;
    final verseText = '📖 $reference: $text';

    setState(() {
      final currentText = _hiddenController.text;
      final cursorPosition = _hiddenController.selection.start;

      final beforeCursor = currentText.substring(0, cursorPosition);
      final afterCursor = currentText.substring(cursorPosition);

      _hiddenController.text = beforeCursor + verseText + afterCursor;
      _hiddenController.selection =
          TextSelection.collapsed(offset: cursorPosition + verseText.length);

      _showBibleMenu = false;
      _currentBibleStep = 'testament'; // Reset para próxima vez
    });
  }

  /// �📝 Menú flotante de viñetas y numeración (estilo uniforme con lápices)
  Widget _buildBulletsMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBulletOption(
                icon: '●', label: 'Viñetas', onTap: () => _addBulletPoint('•')),
            _buildBulletOption(
                icon: '■',
                label: 'Cuadradas',
                onTap: () => _addBulletPoint('▪')),
            _buildBulletOption(
                icon: '1.',
                label: 'Numeración',
                onTap: () => _addNumberedList()),
            _buildBulletOption(
                icon: '➤', label: 'Sangría', onTap: () => _addIndentation()),
          ],
        ),
      ),
    );
  }

  // Optimiza el tamaño de cada símbolo para mejor visibilidad
  double _getIconSize(String icon) {
    switch (icon) {
      case '●':
        return 18.0; // Punto más grande y sólido
      case '■':
        return 16.0; // Cuadrado sólido
      case '➤':
        return 17.0; // Flecha triangular más visible
      case '→':
        return 16.0; // Flecha básica (fallback)
      case '1.':
        return 14.0; // Numeración estándar
      default:
        return 14.0;
    }
  }

  Widget _buildBulletOption(
      {required String icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon,
                style: TextStyle(
                    fontSize:
                        _getIconSize(icon), // Tamaño optimizado por símbolo
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            if (label.isNotEmpty)
              Text(label,
                  style: const TextStyle(fontSize: 6, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required Widget icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        width: 52,
        height: 42,
        decoration: BoxDecoration(
          // 🎭 Fondo activo: azul claro translúcido, inactivo: transparente
          color: isActive
              ? const Color(0xFF87CEEB)
                  .withOpacity(0.3) // Azul claro como la imagen
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          // 💎 Bordes sutiles para efecto cristal
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.4)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          // 🌟 Sombras suaves glassmorphism
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                    spreadRadius: -1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isActive ? 1.05 : 1.0,
            child: icon,
          ),
        ),
      ),
    );
  }

  // 🎯 Función legacy mantenida por compatibilidad
  Widget _buildIconBox({
    required Widget icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF059669) : Colors.white,
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
      // OPTIMIZADO: Solo recalcular área de contenido
      if (mounted) {
        _scheduleUpdateContentRect();

        // CORREGIDO: Actualizar trazos de dibujo y textos flotantes cuando hay scroll
        if (_drawingStrokes.isNotEmpty ||
            _currentStroke != null ||
            _floatingTexts.isNotEmpty) {
          setState(() {});
        }
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

    // Inicializar animaciones de la biblia
    _bibleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _bibleScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bibleAnimationController,
      curve: Curves.elasticOut,
    ));

    _bibleOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bibleAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _bibleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bibleAnimationController,
      curve: Curves.easeOutCubic,
    ));

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

    // Cargar estado del header collapsible
    _loadHeaderCollapseState();
    _loadFloatingButtonsCollapseState();

    // Restaurar textos flotantes
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

      // Cargar biblia en background
      BibleService.instance.loadBible();
    });
  }

  /// 📖 Cargar datos completos de la Biblia desde JSON (optimizado)
  Future<void> _loadBibleData() async {
    // Solo cargar cuando se necesite, no al inicio
    if (_bibleData != null) return;

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/biblia.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        _bibleData = jsonData;
        _bibleVerses = List<Map<String, dynamic>>.from(jsonData['verses']);
      });
    } catch (e) {
      print('Error cargando datos de la Biblia: $e');
    }
  }

  /// 📖 Obtener capítulos de un libro específico (sin cargar todo)
  Future<List<String>> _getBookChapters(String bookName) async {
    if (_bibleData == null) {
      await _loadBibleData();
    }

    final Set<String> chapters = <String>{};
    for (final verse in _bibleVerses) {
      if (verse['book_name'] == bookName) {
        chapters.add(verse['chapter'] as String);
      }
    }

    final List<String> sortedChapters = chapters.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return sortedChapters;
  }

  /// 📖 Obtener versículos de un capítulo específico
  Future<List<Map<String, dynamic>>> _getChapterVerses(
      String bookName, String chapter) async {
    if (_bibleData == null) {
      await _loadBibleData();
    }

    final chapterVerses = _bibleVerses
        .where((verse) =>
            verse['book_name'] == bookName && verse['chapter'] == chapter)
        .toList()
      ..sort((a, b) => int.parse(a['verse']).compareTo(int.parse(b['verse'])));

    return chapterVerses;
  }

  void _onAnyChange() {
    setHasUnsavedChanges(true);

    // Detectar si estamos en un párrafo bíblico y procesar referencia
    if (_contentParts.isNotEmpty && _contentParts.last.isImage) {
      final currentText = _hiddenController.text.trim();
      if (currentText.isNotEmpty && _isBibleReference(currentText)) {
        _processBibleReference(currentText);
      }
    }
  }

  bool _isBibleReference(String text) {
    // Detectar patrones como "juan 3:16", "1 pedro 2:5", etc.
    final regex = RegExp(r'^\d*\s*\w+\s+\d+:\d+$', caseSensitive: false);
    return regex.hasMatch(text.trim());
  }

  @override
  void dispose() {
    // OPTIMIZACIÓN: Limpiar timers para evitar memory leaks
    _saveDebounceTimer?.cancel();
    _contentRectUpdateTimer?.cancel();

    // Solo guardar si el widget aún está montado
    if (mounted) {
      _performSave(pop: false); // Guardado final sin debounce
    }
    _blinkController.dispose();
    _bibleAnimationController.dispose();
    _titleController.removeListener(_onAnyChange);
    _categoriaController.removeListener(_onAnyChange);
    _hiddenController.removeListener(_onAnyChange);
    _titleController.dispose();
    _categoriaController.dispose();
    _hiddenController.dispose();
    _hiddenFocus.dispose();
    _scrollController.dispose();
    _versesScrollController.dispose(); // Limpiar controller de versículos
    _selectionCounter.dispose(); // Limpiar notifier de selección
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double _bottomBarHeight = 50.0;

    final currentScroll =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false, // 🎯 Desactivar resize automático
          backgroundColor: _noteColor,
          // Configuración optimizada para respuesta inmediata
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            backgroundColor: _noteColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 22,
                color: Color(0xFF374151),
              ),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Volver',
            ),
            title: const Text(
              'Editar nota',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AnimatedBuilder(
                  animation: _blinkAnimation,
                  builder: (context, child) {
                    return IconButton(
                      icon: Opacity(
                        opacity:
                            _hasUnsavedChanges ? _blinkAnimation.value : 1.0,
                        child: Icon(
                          Icons.save_rounded,
                          size: 24,
                          color: _hasUnsavedChanges
                              ? const Color(0xFF059669)
                              : const Color(0xFF6B7280),
                        ),
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
                icon: const Icon(
                  Icons.share_rounded,
                  size: 22,
                  color: Color(0xFF374151),
                ),
                tooltip: 'Compartir',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading:
                              const Text('🟢', style: TextStyle(fontSize: 22)),
                          title: const Text('Compartir como texto'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _shareAsText();
                          },
                        ),
                        ListTile(
                          leading:
                              const Text('🟡', style: TextStyle(fontSize: 22)),
                          title: const Text('Compartir como PDF'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _shareAsPdf();
                          },
                        ),
                        ListTile(
                          leading:
                              const Text('🔴', style: TextStyle(fontSize: 22)),
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
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 22,
                  color: Color(0xFF374151),
                ),
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
                    // Header Flotante Mini - Compacto y elegante
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      margin: EdgeInsets.symmetric(
                        horizontal: _isHeaderCollapsed ? 50 : 10,
                        vertical: _isHeaderCollapsed ? 4 : 8,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: _isHeaderCollapsed ? 8 : 16,
                        vertical: _isHeaderCollapsed ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isHeaderCollapsed
                              ? [
                                  Colors.blue.shade50.withOpacity(0.95),
                                  Colors.white.withOpacity(0.95),
                                ]
                              : [
                                  Colors.white.withOpacity(0.85),
                                  Colors.blue.shade50.withOpacity(0.85),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(_isHeaderCollapsed ? 20 : 12),
                        border: Border.all(
                          color: _isHeaderCollapsed
                              ? Colors.blue.shade200.withOpacity(0.7)
                              : Colors.grey.shade300,
                          width: _isHeaderCollapsed ? 1 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(_isHeaderCollapsed ? 0.06 : 0.12),
                            blurRadius: _isHeaderCollapsed ? 3 : 6,
                            offset: Offset(0, _isHeaderCollapsed ? 1 : 2),
                            spreadRadius: _isHeaderCollapsed ? 0 : 0.5,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _isHeaderCollapsed
                            ? _buildMiniFloatingHeader()
                            : _buildExpandedFloatingHeader(),
                      ),
                    ),

                    // Título y sliders
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 0),
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
                                  onTap: () =>
                                      setState(() => _editingTitle = true),
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
                                            _minTitleFontSize,
                                            _maxTitleFontSize);
                                        final scaleFactor = newSize / oldSize;

                                        _titleFontSize = newSize;
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
                                        _minContentFontSize,
                                        _maxContentFontSize),
                                    onChanged: (v) {
                                      setState(() {
                                        final oldSize = _contentFontSize;
                                        final newSize = v.clamp(
                                            _minContentFontSize,
                                            _maxContentFontSize);
                                        final scaleFactor = newSize / oldSize;

                                        _contentFontSize = newSize;

                                        for (int i = 0;
                                            i < _floatingTexts.length;
                                            i++) {
                                          _floatingTexts[i].fontSize *=
                                              scaleFactor;
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
                              children:
                                  List.generate(_contentParts.length, (i) {
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
                                            _partControllers[i]?.text ??
                                                part.text,
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
                                    child: Material(
                                      color: Colors.transparent,
                                      elevation: 0,
                                      child: TextField(
                                        controller: _partControllers[i],
                                        autofocus: false,
                                        maxLines: null,
                                        style: TextStyle(
                                          fontSize: _contentFontSize,
                                          fontWeight: _contentParts[i].bold
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: Colors.black87,
                                          decoration: _contentParts[i].underline
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                          decorationColor:
                                              _contentParts[i].underline
                                                  ? Color(_contentParts[i]
                                                          .underlineColor ??
                                                      0xFF9333EA)
                                                  : null,
                                          decorationThickness:
                                              _contentParts[i].underline
                                                  ? 2.5
                                                  : null,
                                          backgroundColor:
                                              _contentParts[i].highlight
                                                  ? Color(_contentParts[i]
                                                          .highlightColor ??
                                                      0xFFEAB308)
                                                  : Colors.transparent,
                                        ),
                                        textAlign: TextAlign.left,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                        ),
                                        onChanged: (_) =>
                                            setHasUnsavedChanges(true),
                                        onSubmitted: (value) {
                                          setState(() {
                                            _contentParts[i] = _TextPart(
                                              value,
                                              _contentParts[i].bold,
                                              _contentParts[i].underline,
                                              _contentParts[i].underlineColor,
                                              _contentParts[i].highlight,
                                              _contentParts[i].highlightColor,
                                              false,
                                            );
                                            _editingPartIndex = null;
                                            _partControllers.remove(i);
                                          });
                                          _saveNote();
                                        },
                                      ),
                                    ),
                                  );
                                } else {
                                  return LongPressDraggable<int>(
                                    data: i,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0, horizontal: 8.0),
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
                                                  decorationColor: part
                                                              .underline &&
                                                          part.underlineColor !=
                                                              null
                                                      ? Color(
                                                          part.underlineColor!)
                                                      : null,
                                                  decorationThickness:
                                                      part.underline
                                                          ? 2.5
                                                          : null,
                                                  backgroundColor: part
                                                              .highlight &&
                                                          part.highlightColor !=
                                                              null
                                                      ? Color(
                                                          part.highlightColor!)
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
                                        builder: (context, candidateData,
                                            rejectedData) {
                                          final isActive =
                                              candidateData.isNotEmpty;
                                          return Column(
                                            children: [
                                              AnimatedOpacity(
                                                opacity: isActive ? 1.0 : 0.0,
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                child: Container(
                                                  height: 3,
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 4.0,
                                                      horizontal: 8.0),
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: part.text,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  _contentFontSize,
                                                              fontWeight: part.bold
                                                                  ? FontWeight
                                                                      .bold
                                                                  : FontWeight
                                                                      .normal,
                                                              color: Colors
                                                                  .black87,
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
                                  hintText: 'Construye...',
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
                          // Textos flotantes
                          ..._floatingTexts.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final text = entry.value;

                            final scrollOffset = _scrollController.hasClients
                                ? _scrollController.offset
                                : 0.0;
                            final adjustedY = text.y - scrollOffset;

                            return Positioned(
                              key:
                                  ValueKey('floating_text_${idx}_${text.text}'),
                              left: text.x,
                              top: adjustedY,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTap: () {
                                  _editFloatingText(idx, text);
                                },
                                onLongPress: () {
                                  _showFloatingTextOptionsPanel(
                                      context, idx, text);
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
                                      decorationColor:
                                          text.underlineColor != null
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

          // ======= BARRA FLOTANTE TIPO iOS =======
          bottomNavigationBar: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 15
                  : 47, // 🎯 Subido 2 píxeles más para ajuste fino
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              minimum: EdgeInsets.zero,
              child: Container(
                height:
                    MediaQuery.of(context).viewInsets.bottom > 0 ? 100 : 120,
                decoration: BoxDecoration(
                  // � Fondo oscuro tipo dock de iOS
                  // 🌙 Fondo Glass Morphism - translúcido con blur
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(24),
                  // 🎭 Bordes sutiles para efecto cristal
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  // ✨ Sombra elegante y minimalista
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // PRIMERA FILA - 4 botones de formato
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Botón A - Texto Normal
                            _buildFloatingButton(
                              isActive: (!_contentFormat.bold &&
                                  !_contentFormat.underline &&
                                  !_contentFormat.highlight),
                              icon: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                child: Text(
                                  'A',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                    color: (!_contentFormat.bold &&
                                            !_contentFormat.underline &&
                                            !_contentFormat.highlight)
                                        ? const Color(
                                            0xFF2563EB) // Azul para activo
                                        : const Color(
                                            0xFF64748B), // Gris azulado para inactivo
                                  ),
                                ),
                              ),
                              onTap: () {
                                // 🎯 FORMATO CONTINUO: Separar texto antes de cambiar formato
                                final String currentText =
                                    _hiddenController.text.trim();
                                if (currentText.isNotEmpty) {
                                  // Guardar texto actual con formato anterior
                                  setState(() {
                                    _contentParts.add(_TextPart(
                                      currentText,
                                      _contentFormat.bold,
                                      _contentFormat.underline,
                                      _contentFormat.underline
                                          ? _contentFormat.underlineColor.value
                                          : null,
                                      _contentFormat.highlight,
                                      _contentFormat.highlight
                                          ? _contentFormat.highlightColor.value
                                          : null,
                                      false,
                                    ));
                                  });
                                  _hiddenController.clear();
                                }

                                // Cambiar a formato normal
                                setState(() {
                                  _contentFormat = _contentFormat.copyWith(
                                    bold: false,
                                    underline: false,
                                    highlight: false,
                                  );
                                });
                                _saveNote(pop: false);
                                // Mantener foco en el texto
                                FocusScope.of(context)
                                    .requestFocus(_hiddenFocus);
                              },
                            ),
                            _buildFloatingButton(
                              isActive: _contentFormat.bold,
                              icon: Icon(
                                Icons.format_bold_rounded,
                                size: 20,
                                color: _contentFormat.bold
                                    ? const Color(
                                        0xFF2563EB) // Azul para activo
                                    : const Color(
                                        0xFF64748B), // Gris azulado para inactivo
                              ),
                              onTap: () {
                                // 🎯 FORMATO CONTINUO: Separar texto antes de cambiar formato
                                final String currentText =
                                    _hiddenController.text.trim();
                                if (currentText.isNotEmpty) {
                                  // Guardar texto actual con formato anterior
                                  setState(() {
                                    _contentParts.add(_TextPart(
                                      currentText,
                                      _contentFormat.bold,
                                      _contentFormat.underline,
                                      _contentFormat.underline
                                          ? _contentFormat.underlineColor.value
                                          : null,
                                      _contentFormat.highlight,
                                      _contentFormat.highlight
                                          ? _contentFormat.highlightColor.value
                                          : null,
                                      false,
                                    ));
                                  });
                                  _hiddenController.clear();
                                }

                                // Cambiar formato para texto nuevo
                                setState(() {
                                  _contentFormat = _contentFormat.copyWith(
                                    bold: !_contentFormat.bold,
                                  );
                                });
                                _saveNote(pop: false);
                                // Mantener foco en el texto
                                FocusScope.of(context)
                                    .requestFocus(_hiddenFocus);
                              },
                            ),
                            _buildFloatingButton(
                              isActive: _contentFormat.underline,
                              icon: Icon(
                                Icons.format_underlined_rounded,
                                size: 20,
                                color: _contentFormat.underline
                                    ? const Color(
                                        0xFF2563EB) // Azul para activo
                                    : const Color(
                                        0xFF64748B), // Gris azulado para inactivo
                              ),
                              onTap: () {
                                // 🎯 FORMATO CONTINUO: Separar texto antes de cambiar formato
                                final String currentText =
                                    _hiddenController.text.trim();
                                if (currentText.isNotEmpty) {
                                  // Guardar texto actual con formato anterior
                                  setState(() {
                                    _contentParts.add(_TextPart(
                                      currentText,
                                      _contentFormat.bold,
                                      _contentFormat.underline,
                                      _contentFormat.underline
                                          ? _contentFormat.underlineColor.value
                                          : null,
                                      _contentFormat.highlight,
                                      _contentFormat.highlight
                                          ? _contentFormat.highlightColor.value
                                          : null,
                                      false,
                                    ));
                                  });
                                  _hiddenController.clear();
                                }

                                // Cambiar formato para texto nuevo
                                setState(() {
                                  _contentFormat = _contentFormat.copyWith(
                                    underline: !_contentFormat.underline,
                                  );
                                });
                                _saveNote(pop: false);
                                // Mantener foco en el texto
                                FocusScope.of(context)
                                    .requestFocus(_hiddenFocus);
                              },
                            ),

                            _buildFloatingButton(
                              icon: const Icon(
                                Icons.auto_fix_high,
                                size: 20,
                                color: Color(
                                    0xFF64748B), // Gris azulado consistente
                              ),
                              onTap: () {
                                // TODO: Implementar Auto-Format Inteligente
                                print('🎨 Auto-Format Inteligente - Próximamente');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8), // 🎯 Separación entre filas
                      // SEGUNDA FILA - 4 botones funcionales
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFloatingButton(
                              isActive: _contentFormat.highlight,
                              icon: Icon(
                                Icons.highlight_rounded,
                                size: 20,
                                color: _contentFormat.highlight
                                    ? const Color(
                                        0xFF2563EB) // Azul para activo
                                    : const Color(
                                        0xFF64748B), // Gris azulado para inactivo
                              ),
                              onTap: () {
                                // 🎯 FORMATO CONTINUO: Separar texto antes de cambiar formato
                                final String currentText =
                                    _hiddenController.text.trim();
                                if (currentText.isNotEmpty) {
                                  // Guardar texto actual con formato anterior
                                  setState(() {
                                    _contentParts.add(_TextPart(
                                      currentText,
                                      _contentFormat.bold,
                                      _contentFormat.underline,
                                      _contentFormat.underline
                                          ? _contentFormat.underlineColor.value
                                          : null,
                                      _contentFormat.highlight,
                                      _contentFormat.highlight
                                          ? _contentFormat.highlightColor.value
                                          : null,
                                      false,
                                    ));
                                  });
                                  _hiddenController.clear();
                                }

                                // Cambiar formato para texto nuevo
                                setState(() {
                                  _contentFormat = _contentFormat.copyWith(
                                    highlight: !_contentFormat.highlight,
                                  );
                                });
                                _saveNote(pop: false);
                                // Mantener foco en el texto
                                FocusScope.of(context)
                                    .requestFocus(_hiddenFocus);
                              },
                            ),
                            // 🎨 NUEVO BOTÓN LÁPIZ
                            _buildFloatingButton(
                              isActive: _isDrawingMode,
                              icon: Icon(
                                Icons.brush_rounded,
                                size: 20,
                                color: _isDrawingMode
                                    ? const Color(
                                        0xFF2563EB) // Azul para activo
                                    : const Color(
                                        0xFF64748B), // Gris azulado para inactivo
                              ),
                              onTap: () {
                                setState(() {
                                  _showDrawingToolsMenu =
                                      !_showDrawingToolsMenu;
                                  if (_showDrawingToolsMenu) {
                                    _isDrawingMode = true;
                                  } else {
                                    _isDrawingMode = false;
                                  }
                                });
                              },
                            ),
                            _buildFloatingButton(
                              isActive: _showBibleMenu,
                              icon: Icon(
                                Icons.menu_book_rounded,
                                size: 20,
                                color: _showBibleMenu
                                    ? const Color(
                                        0xFF2563EB) // Azul para activo
                                    : const Color(
                                        0xFF64748B), // Gris azulado para inactivo
                              ),
                              onTap: () {
                                // 🎯 Ocultar teclado automáticamente para mostrar las tarjetas bíblicas
                                FocusScope.of(context).unfocus();
                                
                                setState(() {
                                  _showBibleMenu = !_showBibleMenu;
                                  if (_showBibleMenu) {
                                    _showBulletsMenu =
                                        false; // Cerrar otros menús
                                    _showDrawingToolsMenu = false;
                                    _showColorPalette = false;
                                    _currentBibleStep =
                                        'testament'; // Empezar con NT/AT
                                  }
                                });
                              },
                            ),
                            // 📝 Botón de viñetas y numeración
                            _buildFloatingButton(
                              isActive: _showBulletsMenu,
                              icon: Icon(
                                Icons.format_list_bulleted_rounded,
                                size: 20,
                                color: _showBulletsMenu
                                    ? const Color(
                                        0xFF2563EB) // Azul para activo
                                    : const Color(
                                        0xFF64748B), // Gris azulado para inactivo
                              ),
                              onTap: () {
                                setState(() {
                                  _showBulletsMenu = !_showBulletsMenu;
                                  // Cerrar otros menús si están abiertos
                                  if (_showBulletsMenu) {
                                    _showDrawingToolsMenu = false;
                                    _showColorPalette = false;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ======= BOTONES FLOTANTES COLAPSIBLES =======
          floatingActionButton: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _isFloatingButtonsCollapsed
                  ? _buildMiniFloatingButtons()
                  : _buildExpandedFloatingButtons(),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),

        // ========= Bible Autocomplete Overlay =========
        if (_showBibleAutocomplete)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bibleAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bibleScaleAnimation.value,
                  child: SlideTransition(
                    position: _bibleSlideAnimation,
                    child: FadeTransition(
                      opacity: _bibleOpacityAnimation,
                      child: Material(
                        color: Colors.black
                            .withOpacity(0.5 * _bibleOpacityAnimation.value),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              child: BibleAutoCompleteWidget(
                                controller: _bibleController,
                                onVerseSelected: _onVerseSelected,
                                onMultipleVersesSelected:
                                    _onMultipleVersesSelected,
                                onCancel: _cancelBibleAutocomplete,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // ======= MENÚ FLOTANTE DE LÁPICES =======
        // � ======= MENÚ DE VERSÍCULOS BÍBLICOS =======
        if (_showBibleMenu)
          Positioned(
            bottom: 200, // ⬆️ Subido para evitar superposición con el menú principal
            left: 40, // Un poco más hacia la izquierda
            right: 60, // Compensamos el otro lado
            child: _buildBibleMenu(),
          ),

        // �📝 ======= MENÚ DE VIÑETAS Y NUMERACIÓN =======
        if (_showBulletsMenu)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom +
                    140 // 🎯 Arriba del teclado con Glass Morphism
                : 177, // 🎯 Arriba del menú Glass Morphism (altura 125 + padding 47 + espacio 5)
            left: 20,
            right: 20,
            child: _buildBulletsMenu(),
          ),

        if (_showDrawingToolsMenu)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom +
                    140 // 🎯 Arriba del teclado con Glass Morphism
                : 177, // 🎯 Arriba del menú Glass Morphism (altura 125 + padding 47 + espacio 5)
            left: 20,
            right: 20,
            child: _buildDrawingToolsMenu(),
          ),

        // 🌈 ======= PALETA DE COLORES TEMÁTICA =======
        if (_showColorPalette)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom +
                    210 // 🎯 Arriba del menú de lápices
                : 247, // 🎯 Arriba del menú de lápices (177 + altura del menú ~70)
            left: 20,
            right: 20,
            child: _buildColorPalette(),
          ),
      ],
    );
  }
}

/// ===================
/// MENÚ EN ABANICO CIRCULAR
/// ===================

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
    final x = radius * math.cos(radians);
    final y = radius * math.sin(radians);

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

/// ===================
/// 🎨 EFECTOS DE DIBUJO ÚNICOS
/// ===================

/// 🖋️ Efecto de Tinta Caligráfica
class CalligraphyInkEffect {
  static List<Offset> applyEffect(
    List<Offset> points, {
    required Color color,
    required double baseSize,
    required Size canvasSize,
  }) {
    if (points.length < 2) return points;

    List<Offset> enhancedPoints = [];

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // Agregar punto principal
      enhancedPoints.add(point);

      // Agregar goteo sutil cada ciertos puntos
      if (i % 15 == 0 && i > 0) {
        final random = math.Random();
        final dropOffset = Offset(
          point.dx + (random.nextDouble() - 0.5) * 2,
          point.dy + random.nextDouble() * 4 + 2,
        );
        if (_isWithinBounds(dropOffset, canvasSize)) {
          enhancedPoints.add(dropOffset);
        }
      }

      // Textura orgánica - pequeñas variaciones
      if (i % 3 == 0) {
        final random = math.Random();
        final textureOffset = Offset(
          point.dx + (random.nextDouble() - 0.5) * 1.5,
          point.dy + (random.nextDouble() - 0.5) * 1.5,
        );
        if (_isWithinBounds(textureOffset, canvasSize)) {
          enhancedPoints.add(textureOffset);
        }
      }
    }

    return enhancedPoints;
  }

  static bool _isWithinBounds(Offset point, Size canvasSize) {
    return point.dx >= 0 &&
        point.dx <= canvasSize.width &&
        point.dy >= 0 &&
        point.dy <= canvasSize.height;
  }

  static Paint createPaint(Color color, double size) {
    return Paint()
      ..color = color
      ..strokeWidth = size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
  }
}

/// 🎨 Efecto de Acuarela (para implementar después)
class WatercolorEffect {
  // TODO: Implementar en el siguiente paso
}

/// 💎 Efecto de Cristal (para implementar después)
class CrystalEffect {
  // TODO: Implementar en el siguiente paso
}

/// 🎯 Efecto de Spray (para implementar después)
class SprayEffect {
  // TODO: Implementar en el siguiente paso
}

/// ✨ Efecto de Neón (para implementar después)
class NeonEffect {
  // TODO: Implementar en el siguiente paso
}
