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
    final list = json.decode(data) as List;
    tasks = list.map((e) => PendingTask.fromJson(e)).toList();
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
      // Guardar como int (más robusto que string)
      'color': color.value,
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
    final list = json.decode(data) as List;
    notes = list.map((e) => Note.fromJson(e)).toList();
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

      // Si aún no ha pintado, espera un instante
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
                      selectedSkin: _skin,
                      color: _noteColor,
                      onSkinSelected: (s) {
                        setState(() => _skin = s);
                      },
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

            // Contenido con fondo de "skin"
            Expanded(
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

/// ===================
/// PANEL: Skins & Color
/// ===================
class SkinPanel extends StatelessWidget {
  final String selectedSkin;
  final Color color;
  final ValueChanged<String> onSkinSelected;
  final ValueChanged<Color> onColorSelected;

  const SkinPanel({
    super.key,
    required this.selectedSkin,
    required this.color,
    required this.onSkinSelected,
    required this.onColorSelected,
  });

  // Matriz para aumentar contraste en previews
  static const List<double> _previewBoostMatrix = <double>[
    // 4x5 matrix (20 entradas): contraste ~1.25 con leve desplazamiento
    1.25, 0.00, 0.00, 0.00, -32.0,
    0.00, 1.25, 0.00, 0.00, -32.0,
    0.00, 0.00, 1.25, 0.00, -32.0,
    0.00, 0.00, 0.00, 1.00, 0.0,
  ];

  @override
  Widget build(BuildContext context) {
    final skins = [
      'grid',
      'dots',
      'lines',
      'plain',
      'clouds',
      'flowers',
      'wood'
    ];
    final colors = <Color>[
      Colors.white,
      Colors.yellow.shade100,
      Colors.amber.shade100,
      Colors.pink.shade50,
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.cyan.shade50,
      Colors.orange.shade100,
      Colors.grey.shade200,
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fondo (Skin)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: skins.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) =>
                    _buildSkinOption(ctx, skins[i], selectedSkin),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) =>
                    _buildColorOption(ctx, colors[i], color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinOption(BuildContext context, String skin, String selected) {
    final isSelected = skin == selected;
    return GestureDetector(
      onTap: () {
        onSkinSelected(skin);
        Navigator.pop(context);
      },
      onLongPress: () {
        // Zoom rápido para ver detalles
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_previewBoostMatrix),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'packages/notes_module/assets/$skin.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _chip(_skinLabel(skin)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: Material(
        elevation: isSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.amber : Colors.grey.shade400,
              width: isSelected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_previewBoostMatrix),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'packages/notes_module/assets/$skin.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: _chip(_skinLabel(skin)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _skinLabel(String k) {
    switch (k) {
      case 'grid':
        return 'Cuadrícula';
      case 'dots':
        return 'Puntos';
      case 'lines':
        return 'Rayas';
      case 'plain':
        return 'Liso';
      case 'clouds':
        return 'Nubes';
      case 'flowers':
        return 'Flores';
      case 'wood':
        return 'Madera';
      default:
        return k;
    }
  }

  Widget _buildColorOption(BuildContext context, Color c, Color selected) {
    final isSelected = c.value == selected.value;
    return GestureDetector(
      onTap: () {
        onColorSelected(c);
        Navigator.pop(context);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c,
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
