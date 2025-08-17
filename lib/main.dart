import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'notes_module.dart';

void main() {
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider()),
        ChangeNotifierProvider<PendingProvider>(
            create: (_) => PendingProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Notas',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true,
          fontFamily: 'Roboto',
          splashColor: const Color(0xFFFFFFFF),
          highlightColor: const Color(0xFFFFFFFF).withOpacity(0),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = '';
  }

  void _showSearchDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempQuery = _searchQuery;
        return AlertDialog(
          title: const Text('Buscar'),
          content: TextField(
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Nombre, fecha o categoría'),
            onChanged: (v) => tempQuery = v,
            controller: TextEditingController(text: _searchQuery),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(tempQuery),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _searchQuery = result.trim();
      });
    }
  }

  List<Widget> get _pages => [
        NoteListScreen(searchQuery: _searchQuery),
        PendingScreen(searchQuery: _searchQuery),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0.0, 0.5),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: Text(
            _selectedIndex == 0 ? 'Enseñanzas' : 'Pendientes',
            key: ValueKey(_selectedIndex),
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/lupa.png',
              width: 28,
              height: 28,
            ),
            onPressed: _showSearchDialog,
            tooltip: 'Buscar',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color.fromARGB(255, 13, 0, 0),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/nota.gif',
              width: 28,
              height: 28,
            ),
            activeIcon: Image.asset(
              'assets/nota.gif',
              width: 32,
              height: 32,
            ),
            label: 'Enseñanzas',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/pendientes.gif',
              width: 28,
              height: 28,
            ),
            activeIcon: Image.asset(
              'assets/pendientes.gif',
              width: 32,
              height: 32,
            ),
            label: 'Pendientes',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.transparent,
        onPressed: () {
          if (_selectedIndex == 0) {
            final now = DateTime.now();
            final newNote = Note(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: '',
              content: '',
              date:
                  '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
              categoria: '',
            );
            context.read<NoteProvider>().addNote(newNote);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NoteEditScreen(note: newNote),
              ),
            );
          } else {
            final pendingProvider = context.read<PendingProvider>();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 24,
                ),
                child: AddTaskForm(pendingProvider: pendingProvider),
              ),
            );
          }
        },
        tooltip: _selectedIndex == 0 ? 'Nueva enseñanza' : 'Nuevo pendiente',
        elevation: 0,
        shape: const CircleBorder(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
          child: Image.asset(
            'assets/mas.png',
            key: ValueKey(_selectedIndex),
            width: 36,
            height: 36,
          ),
        ),
      ),
    );
  }
}

// --- Pantalla de notas (ejemplo simple) ---
class NoteListScreen extends StatelessWidget {
  final String searchQuery;
  const NoteListScreen({Key? key, this.searchQuery = ''}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, provider, child) {
        final filtered = provider.notes.where((note) {
          final q = searchQuery.toLowerCase();
          return q.isEmpty ||
              note.title.toLowerCase().contains(q) ||
              note.date.toLowerCase().contains(q) ||
              (note.categoria.isNotEmpty &&
                  note.categoria.toLowerCase().contains(q));
        }).toList();
        if (filtered.isEmpty) {
          return const Center(
            child: Text('No hay resultados.',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          );
        }
        // Mapa de categorías a colores pastel
        const categoriaColores = {
          'Sermón': Color(0xFFFFD6E0),
          'Estudio Bíblico': Color(0xFFD6EFFF),
          'Reflexión': Color(0xFFFFF9D6),
          'Devocional': Color(0xFFD6FFD6),
          'Testimonio': Color(0xFFEAD6FF),
          'Apuntes Generales': Color(0xFFFFEFD6),
          'Discipulado': Color(0xFFD6FFF6),
        };
        final categorias = categoriaColores.keys.toList();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final note = filtered[index];
            final pastelColor =
                categoriaColores[note.categoria] ?? Colors.white;
            return Card(
              color: pastelColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        NoteEditScreen(note: note),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ));
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/agenda.png',
                    width: 22,
                    height: 22,
                  ),
                ),
                title: Text(
                  note.title.isEmpty ? 'Sin título' : note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      note.date,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (note.categoria.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note.categoria,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined,
                          color: Colors.indigo),
                      tooltip: 'Categoría',
                      onSelected: (cat) {
                        final updated = Note(
                          id: note.id,
                          title: note.title,
                          content: note.content,
                          date: note.date,
                          categoria: cat,
                          skin: note.skin,
                          color: categoriaColores[cat] ?? Colors.white,
                        );
                        Provider.of<NoteProvider>(context, listen: false)
                            .updateNote(updated);
                      },
                      itemBuilder: (ctx) => [
                        for (final cat in categorias)
                          PopupMenuItem(value: cat, child: Text(cat)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Text('🗑️', style: TextStyle(fontSize: 18)),
                      onSelected: (value) {
                        if (value == 'delete') {
                          provider.deleteNote(note);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                            value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Pantalla de pendientes ---
class PendingScreen extends StatelessWidget {
  final String searchQuery;
  const PendingScreen({Key? key, this.searchQuery = ''}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingProvider>(
      builder: (context, provider, _) {
        final q = searchQuery.toLowerCase();
        final pending = provider.tasks
            .where((t) =>
                !t.completed &&
                (q.isEmpty ||
                    t.title.toLowerCase().contains(q) ||
                    t.description.toLowerCase().contains(q) ||
                    t.categoria.toLowerCase().contains(q) ||
                    ("${t.dateTime.day}/${t.dateTime.month}/${t.dateTime.year}")
                        .contains(q)))
            .toList();
        final done = provider.tasks
            .where((t) =>
                t.completed &&
                (q.isEmpty ||
                    t.title.toLowerCase().contains(q) ||
                    t.description.toLowerCase().contains(q) ||
                    t.categoria.toLowerCase().contains(q) ||
                    ("${t.dateTime.day}/${t.dateTime.month}/${t.dateTime.year}")
                        .contains(q)))
            .toList();
        return Container(
          color: const Color(0xFFFEF7F0),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tareas',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (pending.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Text('No tienes tareas pendientes.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ...pending.map((task) => TaskCard(
                        task: task,
                        onComplete: provider.completeTask,
                        onDelete: provider.deleteTask)),
                    if (done.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Text('Completadas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                      ),
                      ...done.map((task) => TaskCard(
                          task: task,
                          completed: true,
                          onDelete: provider.deleteTask)),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Widget para agregar tarea ---
class AddTaskForm extends StatefulWidget {
  final PendingProvider pendingProvider;
  const AddTaskForm({required this.pendingProvider, super.key});

  @override
  State<AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<AddTaskForm> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  String _categoria = '';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _addTask() {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedTime != null) {
      _formKey.currentState!.save();
      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      widget.pendingProvider.addTask(PendingTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _title,
        description: _description,
        categoria: _categoria,
        dateTime: dateTime,
      ));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nueva tarea',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Título'),
            onSaved: (v) => _title = v ?? '',
            validator: (v) =>
                v == null || v.isEmpty ? 'Escribe un título' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Descripción'),
            onSaved: (v) => _description = v ?? '',
            validator: (v) =>
                v == null || v.isEmpty ? 'Escribe una descripción' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Categoría'),
            onSaved: (v) => _categoria = v ?? '',
            validator: (v) =>
                v == null || v.isEmpty ? 'Escribe una categoría' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_selectedDate == null
                      ? 'Fecha'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                  onPressed: _showDatePicker,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_selectedTime == null
                      ? 'Hora'
                      : _selectedTime!.format(context)),
                  onPressed: _showTimePicker,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: _addTask,
            child: const Text('Agregar tarea',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// --- Widget para mostrar una tarea ---
class TaskCard extends StatelessWidget {
  final PendingTask task;
  final void Function(String id)? onComplete;
  final void Function(String id) onDelete;
  final bool completed;

  const TaskCard({
    required this.task,
    this.onComplete,
    required this.onDelete,
    this.completed = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: completed ? Colors.indigo.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? Colors.indigo : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
                const SizedBox(width: 4),
                Text(
                    '${task.dateTime.day}/${task.dateTime.month}/${task.dateTime.year}'),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 16, color: Colors.indigo),
                const SizedBox(width: 4),
                Text(
                    '${task.dateTime.hour.toString().padLeft(2, '0')}:${task.dateTime.minute.toString().padLeft(2, '0')}'),
              ],
            ),
          ],
        ),
        trailing: completed
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => onDelete(task.id),
                tooltip: 'Eliminar',
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.indigo),
                    onPressed: () => onComplete?.call(task.id),
                    tooltip: 'Marcar como completada',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onDelete(task.id),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
      ),
    );
  }
}
