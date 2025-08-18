import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'dart:convert';

/// =========================
/// MODELO + PROVIDER: Tareas
/// =========================

// Modelo de tarea pendiente
class PendingTask {
  String id;
  String title;
  String description;
  String categoria;
  DateTime dateTime;
  bool completed;

  PendingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.categoria,
    required this.dateTime,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'categoria': categoria,
        'dateTime': dateTime.toIso8601String(),
        'completed': completed,
      };

  factory PendingTask.fromJson(Map<String, dynamic> json) => PendingTask(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        categoria: json['categoria'] ?? '',
        dateTime: DateTime.parse(json['dateTime']),
        completed: json['completed'] ?? false,
      );
}

// Provider para tareas pendientes
class PendingProvider extends ChangeNotifier {
  List<PendingTask> tasks = [];

  PendingProvider() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('pending_tasks') ?? '[]';
    final List<dynamic> list = json.decode(data);
    tasks = list
        .map((e) => PendingTask.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pending_tasks',
      json.encode(tasks.map((e) => e.toJson()).toList()),
    );
  }

  void addTask(PendingTask task) {
    tasks.insert(0, task);
    _saveTasks();
    notifyListeners();
  }

  void completeTask(String id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      tasks[idx].completed = true;
      _saveTasks();
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _saveTasks();
    notifyListeners();
  }
}

/// =======================
/// MODELO + PROVIDER: Notas
/// =======================

/// Modelo de una nota.
class Note {
  String id;
  String title;
  String content;
  String date;
  String categoria;
  String skin;
  Color color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.categoria = '',
    this.skin = 'grid',
    this.color = Colors.white,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
      'categoria': categoria,
      'skin': skin,
      'color': color.value, // como int
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    final skinValue = (json['skin'] as String?)?.isNotEmpty == true
        ? json['skin'] as String
        : 'grid';

    final rawColor = json['color'];
    final colorInt = rawColor is int
        ? rawColor
        : (rawColor is String
            ? int.tryParse(rawColor) ?? 0xFFFFFFFF
            : 0xFFFFFFFF);

    return Note(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] ?? '',
      categoria: json['categoria'] ?? '',
      skin: skinValue,
      color: Color(colorInt),
    );
  }
}

/// Proveedor para gestionar el listado de notas y su persistencia local.
class NoteProvider extends ChangeNotifier {
  List<Note> notes = [];

  NoteProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notes') ?? '[]';
    final List<dynamic> list = json.decode(data);
    notes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'notes',
      json.encode(notes.map((e) => e.toJson()).toList()),
    );
  }

  void addNote(Note note) {
    notes.insert(0, note);
    _saveNotes();
    notifyListeners();
  }

  void updateNote(Note note) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      _saveNotes();
      notifyListeners();
    }
  }

  void deleteNote(Note note) {
    notes.removeWhere((n) => n.id == note.id);
    _saveNotes();
    notifyListeners();
  }

  // ...existing code...
}

/// ========================================
/// PANTALLA: Edición de nota (NoteEditScreen)
/// ========================================
class NoteEditScreen extends StatefulWidget {
  final Note note;
  const NoteEditScreen({super.key, required this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _categoriaController;
  late Color _noteColor;
  late String _skin;

  final GlobalKey _noteKey = GlobalKey();

  Future<void> _shareAsText() async {
    final text = '${_titleController.text}\n\n${_contentController.text}';
    await Share.share(text, subject: _titleController.text);
  }

  Future<void> _shareAsImage() async {
    try {
      final boundary =
          _noteKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await Share.shareXFiles(
        [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'nota.png')],
        text: _titleController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir como imagen: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _categoriaController = TextEditingController(text: widget.note.categoria);
    _noteColor = widget.note.color;
    _skin = widget.note.skin.isEmpty ? 'grid' : widget.note.skin;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final note = widget.note;
    note.title = _titleController.text;
    note.content = _contentController.text;
    note.categoria = _categoriaController.text;
    note.date = DateTime.now().toLocal().toString().split(' ')[0];
    note.color = _noteColor;
    note.skin = _skin.isEmpty ? 'grid' : _skin;
    context.read<NoteProvider>().updateNote(note);
    Navigator.pop(context);
  }

  Widget _buildIconBox(String emoji, VoidCallback onTap) {
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
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          IconButton(
            icon: const Text('✔️',
                style: TextStyle(fontSize: 24, color: Colors.black)),
            tooltip: 'Guardar',
            onPressed: _saveNote,
          ),
          IconButton(
            icon: Image.asset(
              'assets/compartir.png',
              width: 28,
              height: 28,
            ),
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
                      leading: const Icon(Icons.text_fields),
                      title: const Text('Compartir como texto'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _shareAsText();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.image),
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
                        setState(() => _noteColor = c);
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
      body: RepaintBoundary(
        key: _noteKey,
        child: Column(
          children: [
            // Barra superior con fecha y categoría
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(widget.note.date,
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(width: 8),
                  const Text('|', style: TextStyle(color: Colors.black26)),
                  const SizedBox(width: 8),
                  const Icon(Icons.book, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoriaController.text.isNotEmpty
                          ? _categoriaController.text
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Categoría',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                            value: 'Sermón', child: Text('Sermón')),
                        DropdownMenuItem(
                            value: 'Estudio Bíblico',
                            child: Text('Estudio Bíblico')),
                        DropdownMenuItem(
                            value: 'Reflexión', child: Text('Reflexión')),
                        DropdownMenuItem(
                            value: 'Devocional', child: Text('Devocional')),
                        DropdownMenuItem(
                            value: 'Testimonio', child: Text('Testimonio')),
                        DropdownMenuItem(
                            value: 'Apuntes Generales',
                            child: Text('Apuntes Generales')),
                        DropdownMenuItem(
                            value: 'Discipulado', child: Text('Discipulado')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _categoriaController.text = v ?? '';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Encabezado',
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Contenido con transición de cuadros al cambiar color
            Expanded(
              child: TileRevealColorTransition(
                color: _noteColor,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'packages/notes_module/assets/${(_skin.isNotEmpty ? _skin : 'grid')}.png'),
                      repeat: ImageRepeat.repeat,
                      filterQuality: FilterQuality.high, // nitidez
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.16), // + contraste
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      hintText: 'Contenido...',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),

            // Barra inferior minimalista
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconBox('✅', _saveNote),
                  _buildIconBox('🔤', () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Formato'),
                        content:
                            const Text('Opciones de formato próximamente.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }),
                  _buildIconBox('📷', () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Foto'),
                        content:
                            const Text('Función de añadir foto próximamente.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }),
                  _buildIconBox('✏️', () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Garabato'),
                        content:
                            const Text('Función de garabato próximamente.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================================
/// Widget para transición de cuadros (tiles) al cambiar color
/// =======================================================
class TileRevealColorTransition extends StatefulWidget {
  final Color color;
  final Widget child;
  final int rows;
  final int columns;
  final Duration duration;

  const TileRevealColorTransition({
    super.key,
    required this.color,
    required this.child,
    this.rows = 8,
    this.columns = 16,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<TileRevealColorTransition> createState() =>
      _TileRevealColorTransitionState();
}

class _TileRevealColorTransitionState extends State<TileRevealColorTransition>
    with SingleTickerProviderStateMixin {
  late Color _oldColor;
  late Color _currentColor;
  late AnimationController _controller;
  late List<Animation<double>> _tileAnims;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _oldColor = widget.color;
    _currentColor = widget.color;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _initTileAnims();
  }

  void _initTileAnims() {
    final total = widget.rows * widget.columns;
    _tileAnims = List.generate(total, (i) {
      final row = i ~/ widget.columns;
      final col = i % widget.columns;
      // Efecto diagonal: tiles más arriba/izquierda empiezan antes
      final delay = (row + col) / (widget.rows + widget.columns);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay * 0.7,
            (delay * 0.7) + 0.3,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(TileRevealColorTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != _currentColor && !_animating) {
      _oldColor = _currentColor;
      _currentColor = widget.color;
      _animating = true;
      _controller.reset();
      _initTileAnims();
      _controller.forward().then((_) {
        if (mounted) {
          setState(() {
            _animating = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileW = constraints.maxWidth / widget.columns;
        final tileH = constraints.maxHeight / widget.rows;
        final diameter = (tileW > tileH ? tileW : tileH) * 1.25;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _animating ? _oldColor : _currentColor),
            widget.child,
            if (_animating)
              ...List.generate(widget.rows * widget.columns, (i) {
                final row = i ~/ widget.columns;
                final col = i % widget.columns;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final v = _tileAnims[i].value;
                    return Positioned(
                      left: col * tileW + tileW / 2 - diameter / 2,
                      top: row * tileH + tileH / 2 - diameter / 2,
                      width: diameter,
                      height: diameter,
                      child: v > 0
                          ? Opacity(
                              opacity: v,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _currentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                );
              }),
          ],
        );
      },
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
    // Paleta extendida de colores pastel y vivos
    final colors = <Color>[
      // Blancos y grises claros
      Colors.white,
      Colors.grey.shade50,
      Colors.grey.shade100,
      Colors.grey.shade200,
      Colors.grey.shade300,
      // Amarillos y naranjas pastel
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
      // Rosas y lilas pastel
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
      // Azules y celestes pastel
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
      // Verdes y menta pastel
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
      // Marrones claros
      Colors.brown.shade50,
      Colors.brown.shade100,
      Colors.brown.shade200,
      Colors.brown.shade300,
      Colors.brown.shade400,
      Colors.brown.shade500,
      // Extras personalizados elegantes y degradados
      Color(0xFFf6d365),
      Color(0xFFfda085),
      Color(0xFFfbc2eb),
      Color(0xFFa1c4fd),
      Color(0xFFc2e9fb),
      Color(0xFFd4fc79),
      Color(0xFF96e6a1),
      Color(0xFFf7797d),
      Color(0xFFe0c3fc),
      Color(0xFF8fd3f4),
      Color(0xFFfcb69f),
      Color(0xFFffecd2),
      Color(0xFFa8edea),
      Color(0xFFfed6e3),
      Color(0xFFcfd9df),
      Color(0xFFe2d1c3),
      Color(0xFFf5f7fa),
      Color(0xFFc9ffbf),
      Color(0xFFffafbd),
      Color(0xFFb2fefa),
      Color(0xFFf3e7e9),
      Color(0xFFc9ffbf),
      Color(0xFFf9f586),
      Color(0xFFf7b267),
      Color(0xFFe0c3fc),
      Color(0xFFf3e7e9),
      Color(0xFFf5f7fa),
      Color(0xFFe0eafc),
      Color(0xFFf7ffea),
      Color(0xFFe2d1c3),
      Color(0xFFfbc2eb),
      Color(0xFFfcb69f),
      Color(0xFFf6d365),
      Color(0xFFfda085),
      Color(0xFFfbc2eb),
      Color(0xFFa1c4fd),
      Color(0xFFc2e9fb),
      Color(0xFFd4fc79),
      Color(0xFF96e6a1),
      Color(0xFFf7797d),
      Color(0xFFe0c3fc),
      Color(0xFF8fd3f4),
      Color(0xFFfcb69f),
      Color(0xFFffecd2),
      Color(0xFFa8edea),
      Color(0xFFfed6e3),
      Color(0xFFcfd9df),
      Color(0xFFe2d1c3),
      Color(0xFFf5f7fa),
      Color(0xFFc9ffbf),
      Color(0xFFffafbd),
      Color(0xFFb2fefa),
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
                final minBox = 20.0;
                final maxBox = 32.0;
                int crossAxisCount = (maxWidth / (minBox + 6)).floor();
                double boxSize =
                    (maxWidth - (crossAxisCount - 1) * 6) / crossAxisCount;
                if (boxSize > maxBox) boxSize = maxBox;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
