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
    return ChangeNotifierProvider(
      create: (_) => NoteProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Notas',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true,
          fontFamily: 'Roboto',
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

  static const List<Widget> _pages = <Widget>[
    NoteListScreen(),
    PendingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sticky_note_2_outlined, size: 28),
            activeIcon: Icon(Icons.sticky_note_2, size: 28),
            label: 'Notas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined, size: 28),
            activeIcon: Icon(Icons.checklist, size: 28),
            label: 'Pendientes',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
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
            )
          : null,
    );
  }
}

// Pantalla de pendientes (placeholder, puedes mejorarla luego)
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No tienes pendientes aún.',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}
