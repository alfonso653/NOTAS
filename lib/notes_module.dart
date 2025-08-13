import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de una nota.
class Note {
  String id;
  String title;
  String content;
  String date;
  String skin;
  Color color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.skin = 'grid',
    this.color = Colors.white,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
      'skin': skin,
      'color': color.value.toString(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] ?? '',
      skin: json['skin'] ?? 'grid',
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
}

/// Pantalla principal que muestra la lista de notas.
///
/// Puedes integrar este widget en tu aplicación existente como una nueva ruta.
class NoteListScreen extends StatelessWidget {
  const NoteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 28)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            tooltip: 'Buscar',
            onPressed: () {
              // Aquí puedes implementar la búsqueda
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Buscar'),
                  content: const Text('Función de búsqueda próximamente.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            tooltip: 'Menú',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(leading: const Icon(Icons.settings), title: const Text('Configuración'), onTap: () => Navigator.pop(ctx)),
                    ListTile(leading: const Icon(Icons.info_outline), title: const Text('Acerca de'), onTap: () => Navigator.pop(ctx)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.notes.isEmpty) {
            return const Center(
              child: Text('No tienes notas aún. ¡Agrega tu primera nota!', style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.notes.length,
            itemBuilder: (context, index) {
              final note = provider.notes[index];
              return Card(
                color: note.color,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteEditScreen(note: note),
                      ),
                    );
                  },
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade100),
                      ),
                      child: const Icon(Icons.sticky_note_2_outlined, color: Colors.amber, size: 26),
                    ),
                  title: Text(
                    note.title.isEmpty ? 'Sin título' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(note.date, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                    onSelected: (value) {
                      if (value == 'delete') {
                        provider.deleteNote(note);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () {
          final now = DateTime.now();
          final newNote = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '',
            content: '',
            date: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
          );
          context.read<NoteProvider>().addNote(newNote);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(note: newNote),
            ),
          );
        },
        tooltip: 'Nueva nota',
        child: const Icon(Icons.add, color: Colors.white, size: 32),
        elevation: 4,
        shape: const CircleBorder(),
      ),
    );
  }
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
  late Color _noteColor;
  late String _skin;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _noteColor = widget.note.color;
    _skin = widget.note.skin;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final note = widget.note;
    note.title = _titleController.text;
    note.content = _contentController.text;
    note.date = DateTime.now().toLocal().toString().split(' ')[0];
    note.color = _noteColor;
    note.skin = _skin;
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Editar nota', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber),
            tooltip: 'Guardar',
            onPressed: _saveNote,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black54),
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
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'skins':
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                      content: const Text('¿Estás seguro de que deseas eliminar esta nota?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () {
                            context.read<NoteProvider>().deleteNote(widget.note);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'skins', child: Text('Skins y color')),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar nota')),
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
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(widget.note.date, style: const TextStyle(color: Colors.black54)),
                const SizedBox(width: 8),
                const Text('|', style: TextStyle(color: Colors.black26)),
                const SizedBox(width: 8),
                const Icon(Icons.book, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                const Text('Cuaderno predeterminado', style: TextStyle(color: Colors.black54)),
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
                  image: AssetImage('packages/notes_module/assets/$_skin.png'),
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.amber, size: 28),
                  tooltip: 'Guardar',
                  onPressed: _saveNote,
                ),
                IconButton(
                  icon: const Icon(Icons.text_format, color: Colors.black54, size: 28),
                  tooltip: 'Formato',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Formato'),
                        content: const Text('Opciones de formato próximamente.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 28),
                  tooltip: 'Añadir foto',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Foto'),
                        content: const Text('Función de añadir foto próximamente.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.black54, size: 28),
                  tooltip: 'Garabato',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Garabato'),
                        content: const Text('Función de garabato próximamente.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.amber, size: 28),
                    tooltip: 'Guardar',
                    onPressed: _saveNote,
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_format, color: Colors.black54, size: 28),
                    tooltip: 'Formato',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Formato'),
                          content: const Text('Opciones de formato próximamente.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 28),
                    tooltip: 'Añadir foto',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Foto'),
                          content: const Text('Función de añadir foto próximamente.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.black54, size: 28),
                    tooltip: 'Garabato',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Garabato'),
                          content: const Text('Función de garabato próximamente.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
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