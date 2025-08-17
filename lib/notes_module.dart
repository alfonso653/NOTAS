import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
      'color': color.value.toString(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    String? skinValue = json['skin'];
    if (skinValue == null || skinValue.isEmpty) {
      skinValue = 'grid';
    }
    return Note(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] ?? '',
      categoria: json['categoria'] ?? '',
      skin: skinValue,
      color: Color(int.parse(json['color'] ?? '0xFFFFFFFF')),
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

/// Pantalla de edición de notas que contiene campos para el título, contenido,
/// selección de skins y colores y opciones de menú.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Text('◀️', style: TextStyle(fontSize: 24)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Editar nota',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Text('✅', style: TextStyle(fontSize: 24)),
            tooltip: 'Guardar',
            onPressed: _saveNote,
          ),
          IconButton(
            icon: const Text('📤', style: TextStyle(fontSize: 24)),
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
                      onTap: () => Navigator.pop(ctx),
                    ),
                    ListTile(
                      leading: const Icon(Icons.image),
                      title: const Text('Compartir como imagen'),
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Text('⚙️', style: TextStyle(fontSize: 22)),
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
                            child: const Text('Cancelar')),
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
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'skins', child: Text('Skins y color')),
              const PopupMenuItem(
                  value: 'delete', child: Text('Eliminar nota')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                  child: TextField(
                    controller: _categoriaController,
                    decoration: const InputDecoration(
                      hintText: 'Categoría',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
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
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _noteColor,
                image: DecorationImage(
                  image: AssetImage(
                      'packages/notes_module/assets/${(_skin.isNotEmpty ? _skin : 'grid')}.png'),
                  repeat: ImageRepeat.repeat,
                ),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: 'Escribe tu nota aquí...',
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
          // Barra inferior bonita y minimalista
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
                      content: const Text('Opciones de formato próximamente.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'))
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
                            child: const Text('OK'))
                      ],
                    ),
                  );
                }),
                _buildIconBox('✏️', () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Garabato'),
                      content: const Text('Función de garabato próximamente.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'))
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Icono bonito con fondo y borde sutil
  Widget _buildIconBox(String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}

/// Panel inferior que permite elegir distintos fondos (skins) y colores para las notas.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skins',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSkinOption(context, 'grid', selectedSkin),
                _buildSkinOption(context, 'lines', selectedSkin),
                _buildSkinOption(context, 'dots', selectedSkin),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Colores', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorOption(context, Colors.white, color),
                _buildColorOption(context, const Color(0xFFFDF7EE), color),
                _buildColorOption(context, const Color(0xFFEFF8FF), color),
                _buildColorOption(context, const Color(0xFFF5EEFD), color),
              ],
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
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: AssetImage('packages/notes_module/assets/$skin.png'),
            repeat: ImageRepeat.repeat,
          ),
        ),
      ),
    );
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
