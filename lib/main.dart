import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'notes_module.dart';
import 'note.dart';
import 'note_provider.dart';
import 'pending.dart';
import 'calendar_screen.dart';
import 'notification_service.dart';
import 'notebook_provider.dart';
import 'alarm_screen_service.dart';
import 'real_alarm_service.dart';
import 'monthly_tasks_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 🌍 Mantener inglés para selectores pero español para fechas (manual)
  await initializeDateFormatting('en_US', null);
  Intl.defaultLocale = 'en_US';

  // 📱 Inicializar servicio de notificaciones
  await NotificationService.initialize();

  // 🚨 Inicializar servicio de alarmas reales
  await RealAlarmService.initialize();

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
        ChangeNotifierProvider<NotebookProvider>(
            create: (_) => NotebookProvider()..initialize()),
      ],
      child: MaterialApp(
        navigatorKey:
            AlarmScreenService.navigatorKey, // Para pantallas de alarma
        debugShowCheckedModeBanner: false,
        title: 'Notas',
        // 🌍 Localización básica (selectores mantienen formato original)
        locale: const Locale('en', 'US'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'), // Inglés para selectores
          Locale('es', 'ES'), // Español para fechas (manual)
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true,
          fontFamily: 'Roboto',
          splashColor: const Color(0xFFFFFFFF),
          highlightColor: const Color(0xFFFFFFFF).withOpacity(0),
          // Configuración para splash screen
          scaffoldBackgroundColor: const Color(0xFFFEF7F0),
          // 🚀 Optimización nativa de Android para máxima fluidez
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          // Configuración de animaciones nativas
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        home: const AppInitializer(),
      ),
    );
  }
}

/// Inicializador de la aplicación que maneja la secuencia:
/// Splash Personalizado (5s) → App Principal
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _showCustomSplash = true;
  double _splashOpacity = 1.0; // Empezar visible directamente

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  void _startSplashSequence() async {
    // Mostrar tu splash inmediatamente por 6 segundos
    await Future.delayed(const Duration(seconds: 6));

    // Solo fade-out rápido al final
    setState(() {
      _splashOpacity = 0.0;
    });

    // Transición rápida y directa a la app
    await Future.delayed(const Duration(milliseconds: 300));

    // Restaurar la barra de estado y cambiar a la app
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    setState(() {
      _showCustomSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomSplash) {
      return _buildCustomSplash();
    } else {
      return const HomeScreen();
    }
  }

  Widget _buildCustomSplash() {
    // Pantalla completa sin barras del sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    return Scaffold(
      body: AnimatedOpacity(
        opacity: _splashOpacity,
        duration: const Duration(milliseconds: 300), // Transición más suave
        curve: Curves.easeOut, // Curva optimizada para salida
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black, // Fondo negro simple
          child: Image.asset(
            'assets/splash/splash.gif', // Tu GIF expandido
            fit: BoxFit.cover, // Cubrir toda la pantalla
            width: double.infinity,
            height: double.infinity,
            // Configuración para GIF:
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              // Fallback si no encuentra la imagen
              return Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(
                    Icons.note_alt_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
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
  // Estado de navegación
  int _selectedIndex = 0;

  // Filtros
  DateTime? _selectedDate;
  TimeOfDay? _selectedTimeFrom;
  TimeOfDay? _selectedTimeTo;
  String _timeText = '';
  String _searchQuery = '';
  String _searchCategory = '';

  bool get _isDesktopLike =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Diferir mutaciones al próximo frame para evitar re-entrancia.
  void _defer(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
  }

  // ---------- Picker MATERIAL (móvil) 12h con AM/PM ----------
  Widget _hourMinutePicker({
    required TimeOfDay initial,
    required void Function(TimeOfDay) onChanged,
  }) {
    int hour = initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod;
    int minute = initial.minute;
    bool isPm = initial.period == DayPeriod.pm;

    return StatefulBuilder(
      builder: (context, setSB) {
        final double scrollWidth =
            MediaQuery.of(context).size.width < 400 ? 48 : 60;
        final double scrollHeight =
            MediaQuery.of(context).size.height < 700 ? 90 : 120;
        final double fontSize =
            MediaQuery.of(context).size.width < 400 ? 16 : 20;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: scrollWidth,
              height: scrollHeight,
              alignment: Alignment.center,
              child: ListWheelScrollView.useDelegate(
                itemExtent: scrollHeight / 3,
                diameterRatio: 1.2,
                physics: const FixedExtentScrollPhysics(),
                controller: FixedExtentScrollController(initialItem: hour - 1),
                onSelectedItemChanged: (i) {
                  hour = i + 1;
                  _defer(() {
                    onChanged(TimeOfDay(
                      hour: isPm
                          ? (hour == 12 ? 12 : hour + 12)
                          : (hour == 12 ? 0 : hour),
                      minute: minute,
                    ));
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, i) => Center(
                    child:
                        Text('${i + 1}', style: TextStyle(fontSize: fontSize)),
                  ),
                  childCount: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(':', style: TextStyle(fontSize: fontSize)),
            ),
            Container(
              width: scrollWidth,
              height: scrollHeight,
              alignment: Alignment.center,
              child: ListWheelScrollView.useDelegate(
                itemExtent: scrollHeight / 3,
                diameterRatio: 1.2,
                physics: const FixedExtentScrollPhysics(),
                controller: FixedExtentScrollController(initialItem: minute),
                onSelectedItemChanged: (i) {
                  minute = i;
                  _defer(() {
                    onChanged(TimeOfDay(
                      hour: isPm
                          ? (hour == 12 ? 12 : hour + 12)
                          : (hour == 12 ? 0 : hour),
                      minute: minute,
                    ));
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, i) => Center(
                    child: Text(i.toString().padLeft(2, '0'),
                        style: TextStyle(fontSize: fontSize)),
                  ),
                  childCount: 60,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RadioListTile<bool>(
                  title: Text('AM', style: TextStyle(fontSize: fontSize - 4)),
                  value: false,
                  groupValue: isPm,
                  onChanged: (v) {
                    _defer(() {
                      setSB(() => isPm = false);
                      onChanged(TimeOfDay(
                          hour: hour == 12 ? 0 : hour, minute: minute));
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                RadioListTile<bool>(
                  title: Text('PM', style: TextStyle(fontSize: fontSize - 4)),
                  value: true,
                  groupValue: isPm,
                  onChanged: (v) {
                    _defer(() {
                      setSB(() => isPm = true);
                      onChanged(TimeOfDay(
                          hour: hour == 12 ? 12 : hour + 12, minute: minute));
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ---------- Picker CUPERTINO (desktop/web) 12h con AM/PM ----------
  Widget _cupertinoRangePicker({
    required TimeOfDay initialFrom,
    required TimeOfDay initialTo,
    required void Function(TimeOfDay from, TimeOfDay to) onAceptar,
  }) {
    DateTime fromDT =
        DateTime(2000, 1, 1, initialFrom.hour, initialFrom.minute);
    DateTime toDT = DateTime(2000, 1, 1, initialTo.hour, initialTo.minute);

    TimeOfDay _toTOD(DateTime d) => TimeOfDay(hour: d.hour, minute: d.minute);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Selecciona el rango de horas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Desde:', style: TextStyle(fontSize: 16))),
        SizedBox(
          height: 160,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: false, // 12 h con AM/PM
            initialDateTime: fromDT,
            onDateTimeChanged: (d) => fromDT = d,
          ),
        ),
        const SizedBox(height: 8),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Hasta:', style: TextStyle(fontSize: 16))),
        SizedBox(
          height: 160,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: false,
            initialDateTime: toDT,
            onDateTimeChanged: (d) => toDT = d,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              child: const Text('Aceptar'),
              onPressed: () {
                if (fromDT.isAfter(toDT)) {
                  final tmp = fromDT;
                  fromDT = toDT;
                  toDT = tmp;
                }
                onAceptar(_toTOD(fromDT), _toTOD(toDT));
                Navigator.pop(context);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _showDoubleTimePicker() async {
    if (_isDesktopLike) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: _cupertinoRangePicker(
              initialFrom:
                  _selectedTimeFrom ?? const TimeOfDay(hour: 8, minute: 0),
              initialTo:
                  _selectedTimeTo ?? const TimeOfDay(hour: 18, minute: 0),
              onAceptar: (from, to) {
                setState(() {
                  _selectedTimeFrom = from;
                  _selectedTimeTo = to;
                  _timeText = '${from.format(context)} - ${to.format(context)}';
                });
              },
            ),
          );
        },
      );
      return;
    }

    // En móvil (Android/iOS), rueda Material con AM/PM
    TimeOfDay tempFrom =
        _selectedTimeFrom ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay tempTo = _selectedTimeTo ?? const TimeOfDay(hour: 18, minute: 0);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecciona el rango de horas',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Desde:', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _hourMinutePicker(
                      initial: tempFrom,
                      onChanged: (t) => tempFrom = t,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Hasta:', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _hourMinutePicker(
                      initial: tempTo,
                      onChanged: (t) => tempTo = t,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    child: const Text('Aceptar'),
                    onPressed: () {
                      final fromMin = tempFrom.hour * 60 + tempFrom.minute;
                      final toMin = tempTo.hour * 60 + tempTo.minute;
                      if (fromMin > toMin) {
                        final t = tempFrom;
                        tempFrom = tempTo;
                        tempTo = t;
                      }
                      _defer(() {
                        setState(() {
                          _selectedTimeFrom = tempFrom;
                          _selectedTimeTo = tempTo;
                          _timeText =
                              '${tempFrom.format(context)} - ${tempTo.format(context)}';
                        });
                        Navigator.pop(context);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMonthlyTasksView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MonthlyTasksView(),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar Notas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar en notas...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                // Aquí puedes implementar la búsqueda en notas
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEF7F0), // Beige igual al fondo
        elevation: 0, // Sin sombra
        shadowColor: Colors.transparent,
        leading: _selectedIndex == 0
            ? IconButton(
                icon: Image.asset('assets/mas.png', width: 32, height: 32),
                onPressed: () {
                  final now = DateTime.now();
                  final newNote = Note(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: '',
                    date: now.toIso8601String(),
                    categoria: '',
                    skin: 'grid',
                    color: Colors.white,
                    titleFontSize: 22.0,
                    contentFontSize: 18.0,
                    contentParts: const [],
                    floatingImages: const [],
                    drawingStrokes: const [], // 🎨 Inicializar lista de trazos
                  );
                  context.read<NoteProvider>().addNote(newNote);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditScreen(note: newNote),
                    ),
                  );
                },
                tooltip: 'Nueva enseñanza',
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            final offsetAnimation =
                Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero)
                    .animate(animation);
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            _selectedIndex == 0 ? 'Notas' : 'Agenda',
            key: ValueKey(_selectedIndex),
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Image.asset('assets/lupa.png', width: 28, height: 28),
            onPressed:
                _selectedIndex == 0 ? _showSearchDialog : _showMonthlyTasksView,
            tooltip:
                _selectedIndex == 0 ? 'Buscar notas' : 'Ver tareas del mes',
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 500;
                      final filterWidth = isNarrow ? double.infinity : 220.0;
                      final filterSpacing = isNarrow ? 8.0 : 12.0;
                      return Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: filterWidth,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Filtrar por fecha',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                child: Row(
                                  children: [
                                    const Text('📅 ',
                                        style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedDate != null
                                            ? "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                                            : 'Fechas',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: _selectedDate != null
                                                ? Colors.black87
                                                : Colors.grey),
                                      ),
                                    ),
                                    if (_selectedDate != null)
                                      IconButton(
                                        icon: const Text('🧹',
                                            style: TextStyle(fontSize: 18)),
                                        onPressed: () => setState(
                                            () => _selectedDate = null),
                                        splashRadius: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: filterSpacing, height: filterSpacing),
                          SizedBox(
                            width: filterWidth,
                            child: Column(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _showDoubleTimePicker,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Rango de horas',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('🕓 ',
                                            style: TextStyle(fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            (_selectedTimeFrom != null &&
                                                    _selectedTimeTo != null)
                                                ? '${_selectedTimeFrom!.format(context)} - ${_selectedTimeTo!.format(context)}'
                                                : 'Horas',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: (_selectedTimeFrom !=
                                                          null &&
                                                      _selectedTimeTo != null)
                                                  ? Colors.black87
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        if (_selectedTimeFrom != null ||
                                            _selectedTimeTo != null)
                                          IconButton(
                                            icon: const Text('🧹',
                                                style: TextStyle(fontSize: 18)),
                                            onPressed: () => setState(() {
                                              _selectedTimeFrom = null;
                                              _selectedTimeTo = null;
                                              _timeText = '';
                                            }),
                                            splashRadius: 16,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: NoteListScreen(
                    searchQuery: _searchQuery,
                    searchCategory: _searchCategory,
                    selectedDate: _selectedDate,
                    selectedTimeFrom: _selectedTimeFrom,
                    selectedTimeTo: _selectedTimeTo,
                    timeText: _timeText,
                  ),
                ),
              ],
            )
          : const CalendarScreen(),
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
            icon: Image.asset('assets/nota.gif', width: 28, height: 28),
            activeIcon: Image.asset('assets/nota.gif', width: 32, height: 32),
            label: 'Notas',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/pendientes.gif', width: 28, height: 28),
            activeIcon:
                Image.asset('assets/pendientes.gif', width: 32, height: 32),
            label: 'Agenda',
          ),
        ],
      ),
    );
  }
}

// --- Pantalla de notas ---
class NoteListScreen extends StatelessWidget {
  const NoteListScreen({
    Key? key,
    this.searchQuery = '',
    this.searchCategory = '',
    this.selectedDate,
    this.selectedTimeFrom,
    this.selectedTimeTo,
    this.timeText = '',
  }) : super(key: key);

  final String searchQuery;
  final String searchCategory;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTimeFrom;
  final TimeOfDay? selectedTimeTo;
  final String timeText;

  String _formatDateTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (_) {
      return dateStr;
    }
  }

  DateTime? _parseNoteDate(String s) {
    s = s.trim();
    try {
      return DateTime.parse(s);
    } catch (_) {}
    try {
      final parts = s.split(' ');
      final dmy = parts[0].split('/');
      final d = int.parse(dmy[0]), m = int.parse(dmy[1]), y = int.parse(dmy[2]);
      int hh = 0, mm = 0;
      if (parts.length > 1) {
        final hm = parts[1].split(':');
        hh = int.parse(hm[0]);
        mm = int.parse(hm[1]);
      }
      return DateTime(y, m, d, hh, mm);
    } catch (_) {}
    try {
      final dmy = s.split('/');
      final d = int.parse(dmy[0]), m = int.parse(dmy[1]), y = int.parse(dmy[2]);
      return DateTime(y, m, d);
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, provider, child) {
        final filtered = provider.notes.where((note) {
          final q = searchQuery.toLowerCase();
          final cat = searchCategory;
          final matchesCategory = cat.isEmpty || note.categoria == cat;
          final matchesQuery = q.isEmpty ||
              note.title.toLowerCase().contains(q) ||
              note.date.toLowerCase().contains(q) ||
              (note.categoria.isNotEmpty &&
                  note.categoria.toLowerCase().contains(q));

          bool matchesDate = true;
          final parsed = _parseNoteDate(note.date);
          if (selectedDate != null) {
            if (parsed == null) {
              matchesDate = false;
            } else {
              matchesDate = parsed.year == selectedDate!.year &&
                  parsed.month == selectedDate!.month &&
                  parsed.day == selectedDate!.day;
            }
          }

          bool matchesTime = true;
          if (selectedTimeFrom != null && selectedTimeTo != null) {
            if (parsed == null) {
              matchesTime = false;
            } else {
              final mins = parsed.hour * 60 + parsed.minute;
              final fromM =
                  selectedTimeFrom!.hour * 60 + selectedTimeFrom!.minute;
              final toM = selectedTimeTo!.hour * 60 + selectedTimeTo!.minute;
              final low = fromM <= toM ? fromM : toM;
              final high = fromM <= toM ? toM : fromM;
              matchesTime = (mins >= low && mins <= high);
            }
          } else if (timeText.isNotEmpty) {
            matchesTime = note.date.contains(timeText);
          }

          return matchesCategory && matchesQuery && matchesDate && matchesTime;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No hay resultados.',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          );
        }

        const categoriaColores = {
          'Sermón': Color(0xFFD6FFF0),
          'Estudio Bíblico': Color(0xFFD6EFFF),
          'Reflexión': Color(0xFFFFF9D6),
          'Devocional': Color(0xFFB2E2B2),
          'Testimonio': Color(0xFFEAD6FF),
          'Apuntes Generales': Color(0xFFB2C7E2),
          'Discipulado': Color(0xFFFFD6D6),
          'Conexion': Color(0xFFB2FFD6),
          'Música': Color(0xFFE0F7FA),
          'Cita': Color(0xFFFFF3E0),
          'Versículo': Color(0xFFE8F5E9),
          'Oración': Color(0xFFF3E5F5),
          'Culto': Color(0xFFE1F8FF),
          'Otro': Color(0xFFD7CCC8),
        };

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final note = filtered[index];
            final pastelColor =
                categoriaColores[note.categoria] ?? Colors.white;
            return Card(
              color: pastelColor,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onTap: () {
                  Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        NoteEditScreen(note: note),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ));
                },
                leading: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child:
                      Image.asset('assets/agenda.png', width: 15, height: 15),
                ),
                title: Text(
                  note.title.isEmpty ? 'Sin título' : note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 15),
                ),
                subtitle: Row(
                  children: [
                    Text(_formatDateTime(note.date),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (note.categoria.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _categoriaAbreviatura(note.categoria),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Text('🗑️', style: TextStyle(fontSize: 15)),
                  onSelected: (value) {
                    if (value == 'delete') {
                      context.read<NoteProvider>().deleteNote(note);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
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

// --- Pantalla de agenda ---
class PendingScreen extends StatelessWidget {
  const PendingScreen(
      {Key? key, this.searchQuery = '', this.searchCategory = ''})
      : super(key: key);

  final String searchQuery;
  final String searchCategory;

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingProvider>(
      builder: (context, provider, _) {
        final pending = provider.tasks.where((t) => !t.completed).toList();
        final done = provider.tasks.where((t) => t.completed).toList();
        return Scaffold(
          backgroundColor: const Color(0xFFFEF7F0),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
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
                  child: AddTaskForm(pendingProvider: provider),
                ),
              );
            },
            child: const Icon(Icons.add),
            tooltip: 'Nueva tarea',
          ),
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Text('No tienes tareas en tu agenda.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ...pending.map((task) => TaskCard(
                        task: task,
                        onComplete: provider.completeTask,
                        onDelete: provider.deleteTask)),
                    if (done.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 8),
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

// --- Formulario para agregar tarea ---
class AddTaskForm extends StatefulWidget {
  const AddTaskForm({required this.pendingProvider, super.key});

  final PendingProvider pendingProvider;

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
  bool _isAllDay = false;
  String _repeatType = 'none';
  List<int> _customDays = [];

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

  void _showCustomDaysDialog() async {
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    List<int> tempSelected = List.from(_customDays);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Seleccionar días'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: days.asMap().entries.map((entry) {
              final index = entry.key + 1; // 1=Lunes, 7=Domingo
              final day = entry.value;
              return CheckboxListTile(
                title: Text(day),
                value: tempSelected.contains(index),
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      tempSelected.add(index);
                    } else {
                      tempSelected.remove(index);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _customDays = tempSelected;
                });
                Navigator.pop(context);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
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
        isAllDay: _isAllDay,
        repeatType: _isAllDay && _repeatType != 'none' ? _repeatType : null,
        customDays: _repeatType == 'custom' ? _customDays : null,
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
          const Text('Nueva tarea',
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
                  onPressed: _isAllDay ? null : _showTimePicker,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isAllDay ? Colors.grey : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Checkbox Todo el día con dropdown
          Row(
            children: [
              Checkbox(
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value ?? false;
                    if (_isAllDay) {
                      _selectedTime = const TimeOfDay(hour: 0, minute: 0);
                    }
                  });
                },
              ),
              const Text('Todo el día'),
            ],
          ),
          if (_isAllDay)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Row(
                children: [
                  const Icon(Icons.repeat, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _repeatType,
                      isExpanded: true,
                      underline: Container(),
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(
                            value: 'none', child: Text('Sin repetir')),
                        DropdownMenuItem(
                            value: 'daily', child: Text('Todos los días')),
                        DropdownMenuItem(
                            value: 'saturday', child: Text('Los sábados')),
                        DropdownMenuItem(
                            value: 'sunday', child: Text('Los domingos')),
                        DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Este día todas las semanas')),
                        DropdownMenuItem(
                            value: 'weekdays',
                            child: Text('De lunes a viernes')),
                        DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Anualmente este día')),
                        DropdownMenuItem(
                            value: 'custom', child: Text('Personalizado')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _repeatType = value ?? 'none';
                          if (_repeatType == 'custom') {
                            _showCustomDaysDialog();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
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

// --- Tarjeta de tarea ---
class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    this.onComplete,
    required this.onDelete,
    this.completed = false,
    super.key,
  });

  final PendingTask task;
  final void Function(String id)? onComplete;
  final void Function(String id) onDelete;
  final bool completed;

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
              offset: const Offset(0, 2))
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
                const Icon(Icons.calendar_today,
                    size: 16, color: Colors.indigo),
                const SizedBox(width: 4),
                Text(
                    '${task.dateTime.day}/${task.dateTime.month}/${task.dateTime.year}'),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 16, color: Colors.indigo),
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

// --- Abreviaturas de categorías ---
String _categoriaAbreviatura(String categoria) {
  switch (categoria) {
    case 'Sermón':
      return 'SER';
    case 'Estudio Bíblico':
      return 'EST';
    case 'Reflexión':
      return 'REF';
    case 'Devocional':
      return 'DEV';
    case 'Testimonio':
      return 'TES';
    case 'Apuntes Generales':
      return 'APG';
    case 'Discipulado':
      return 'DIS';
    case 'Conexion':
      return 'CON';
    case 'Música':
      return 'MUS';
    case 'Cita':
      return 'CIT';
    case 'Versículo':
      return 'VER';
    case 'Oración':
      return 'ORA';
    case 'Culto':
      return 'CUL';
    case 'Otro':
      return 'OTR';
    default:
      return categoria.length >= 3
          ? categoria.substring(0, 3).toUpperCase()
          : categoria.toUpperCase();
  }
}
