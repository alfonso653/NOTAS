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
          splashColor: const Color.fromARGB(
              255, 255, 255, 255), // Color del efecto expansivo (splash)
          highlightColor: const Color.fromARGB(255, 255, 255, 255)
              .withOpacity(0), // Color al mantener presionado
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
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Acción de búsqueda (puedes personalizarla)
            },
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
            );
            context.read<NoteProvider>().addNote(newNote);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NoteEditScreen(note: newNote),
              ),
            );
          } else {
            // Acción para pendientes (puedes personalizarla)
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
            // color: null, // Mostrar el PNG con sus colores originales en ambas pestañas
          ),
        ),
      ),
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
