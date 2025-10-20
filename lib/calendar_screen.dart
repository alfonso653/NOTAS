import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pending.dart';
import 'day_view_screen.dart';
import 'daily_verse_widget.dart';

// 🌍 Funciones globales para formateo en español (sin afectar selectores)
String formatMonthYearSpanish(DateTime date) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre'
  ];
  final monthName = months[date.month - 1];
  return '${monthName[0].toUpperCase()}${monthName.substring(1)} ${date.year}';
}

String formatFullDateSpanish(DateTime date) {
  const days = [
    'domingo',
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado'
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre'
  ];

  final dayName = days[date.weekday % 7];
  final monthName = months[date.month - 1];

  return '${dayName[0].toUpperCase()}${dayName.substring(1)}, ${date.day} de $monthName de ${date.year}';
}

/// Pantalla principal del calendario infinito
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late ScrollController _scrollController;
  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selectedDate = _today; // Siempre empezar con la fecha actual seleccionada
    _focusedMonth = DateTime(_today.year, _today.month, 1);
    _scrollController = ScrollController();

    // Fecha actualizada solo cuando es necesario para mejor rendimiento
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Navegar al mes siguiente
  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  /// Navegar al mes anterior
  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  /// Obtiene las tareas para una fecha específica (optimizado)
  List<PendingTask> _getTasksForDate(
      DateTime date, List<PendingTask> allTasks) {
    // Optimización: comparación más eficiente
    final targetYear = date.year;
    final targetMonth = date.month;
    final targetDay = date.day;

    final dayTasks = allTasks.where((task) {
      final taskDate = task.dateTime;
      return taskDate.year == targetYear &&
          taskDate.month == targetMonth &&
          taskDate.day == targetDay;
    }).toList();

    // Ordenar las tareas por hora y minuto
    dayTasks.sort((a, b) {
      final aTime = a.dateTime.hour * 60 + a.dateTime.minute;
      final bTime = b.dateTime.hour * 60 + b.dateTime.minute;
      return aTime.compareTo(bTime);
    });

    return dayTasks;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingProvider>(
      builder: (context, provider, _) {
        // Obtener información del teclado
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        return Scaffold(
          backgroundColor: const Color(0xFFFEF7F0),
          // Evitar que el Scaffold se redimensione automáticamente
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: GestureDetector(
              onTap: () => _showMonthYearSelector(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMonthYearSpanish(_focusedMonth),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3A59),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF2E3A59),
                    size: 28,
                  ),
                ],
              ),
            ),
            actions: [
              // Indicador de fecha actual
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Text(
                    'Hoy: ${_today.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151).withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.today,
                      color: Color(0xFF374151), size: 20),
                ),
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _today = now;
                    _selectedDate = now;
                    _focusedMonth = DateTime(now.year, now.month, 1);
                  });
                },
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: Column(
              children: [
                // Header con días de la semana
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Expanded(
                          child: Center(
                              child: Text('Dom',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                      Expanded(
                          child: Center(
                              child: Text('Lun',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                      Expanded(
                          child: Center(
                              child: Text('Mar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                      Expanded(
                          child: Center(
                              child: Text('Mié',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                      Expanded(
                          child: Center(
                              child: Text('Jue',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                      Expanded(
                          child: Center(
                              child: Text('Vie',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                      Expanded(
                          child: Center(
                              child: Text('Sáb',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      fontSize: 14)))),
                    ],
                  ),
                ),
                // Controles de navegación de mes
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Color(0xFF374151)),
                        onPressed: _previousMonth,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Color(0xFF374151)),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),

                // Calendario - Ahora más compacto para hacer espacio al versículo
                Expanded(
                  flex: 3, // 3/5 del espacio disponible para el calendario
                  child: _buildCalendarGrid(_focusedMonth, provider.tasks),
                ),

                // Área para versículo diario (el área roja que marcaste)
                Expanded(
                  flex: 2, // 2/5 del espacio disponible para el versículo
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    child: DailyVerseWidget(
                      selectedDate: _selectedDate,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construye la grilla del calendario para un mes específico
  Widget _buildCalendarGrid(DateTime monthDate, List<PendingTask> allTasks) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // Domingo = 0
    final daysInMonth = lastDayOfMonth.day;

    // Mes calculado correctamente

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular dimensiones dinámicamente para responsividad
        final availableWidth = constraints.maxWidth - 16;
        final cellWidth = availableWidth / 7;
        final aspectRatio = (cellWidth / (cellWidth * 0.85)).clamp(0.75, 1.1);
        
        return GridView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 0, // Sin espacio - las líneas harán la separación
            mainAxisSpacing: 0,  // Sin espacio - las líneas harán la separación
          ),
      itemCount: 42, // Optimizado: 6 semanas * 7 días (constante)
      itemBuilder: (context, index) {
        if (index < firstDayWeekday) {
          // Días del mes anterior
          final prevMonth = DateTime(monthDate.year, monthDate.month - 1, 1);
          final lastDayPrevMonth =
              DateTime(monthDate.year, monthDate.month, 0).day;
          final day = lastDayPrevMonth - (firstDayWeekday - index - 1);
          final date = DateTime(prevMonth.year, prevMonth.month, day);
          return _buildCalendarDay(date, allTasks, isOtherMonth: true);
        } else if (index - firstDayWeekday >= daysInMonth) {
          // Días del mes siguiente
          final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
          final day = index - firstDayWeekday - daysInMonth + 1;
          final date = DateTime(nextMonth.year, nextMonth.month, day);
          return _buildCalendarDay(date, allTasks, isOtherMonth: true);
        } else {
          // Días del mes actual
          final day = index - firstDayWeekday + 1;
          final date = DateTime(monthDate.year, monthDate.month, day);
          return _buildCalendarDay(date, allTasks);
        }
      },
    );
      },
    );
  }

  /// Construye un día individual del calendario
  Widget _buildCalendarDay(DateTime date, List<PendingTask> allTasks,
      {bool isOtherMonth = false}) {
    final tasks = _getTasksForDate(date, allTasks);
    final isSelected = _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;
    final isToday = _today.year == date.year &&
        _today.month == date.month &&
        _today.day == date.day;

    return GestureDetector(
      onTap: () {
        // Abrir vista diaria al tocar cualquier día
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DayViewScreen(selectedDate: date),
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellHeight = constraints.maxHeight;
          final isSmallCell = cellHeight < 60;
          
          return Container(
            padding: EdgeInsets.all(isSmallCell ? 2 : 4),
            decoration: BoxDecoration(
              color: isSelected && isToday
                  ? const Color(0xFF374151).withOpacity(0.2)
                  : isSelected
                      ? const Color(0xFF374151).withOpacity(0.1)
                      : isToday
                          ? const Color(0xFF374151).withOpacity(0.15)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              
              // Líneas divisorias más evidentes para crear cuadrícula
              border: Border(
                right: BorderSide(
                  color: Colors.grey.withOpacity(0.4), // Más opacidad
                  width: 1.0, // Más grosor
                ),
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.4), // Más opacidad
                  width: 1.0, // Más grosor
                ),
              ),
              
              // Sombra solo para día actual
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: const Color(0xFF374151).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número del día
            Container(
              decoration: isToday
                  ? BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              padding: isToday
                  ? EdgeInsets.symmetric(
                      horizontal: isSmallCell ? 3 : 6,
                      vertical: isSmallCell ? 1 : 2)
                  : EdgeInsets.zero,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: isSmallCell ? 11 : (isToday ? 13 : 12),
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: isOtherMonth
                        ? Colors.grey.withOpacity(0.4)
                        : isToday
                            ? Colors.white
                            : const Color(0xFF2E3A59),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Sistema de semáforo para tareas - SIEMPRE mostrar contador
            Expanded(
              child: tasks.isEmpty
                  ? const SizedBox()
                  : LayoutBuilder(
                      builder: (context, taskConstraints) {
                        final taskCount = tasks.length;
                        
                        // SIEMPRE mostrar contador con semáforo (sin importar si es 1 o más tareas)
                        Color getTaskCountColor(int count) {
                          if (count <= 3) return Colors.green[600]!;      // Verde: 1-3 tareas
                          if (count <= 7) return Colors.orange[600]!;     // Naranja: 4-7 tareas
                          return Colors.red[600]!;                       // Rojo: 8+ tareas
                        }
                        
                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$taskCount',
                              style: TextStyle(
                                fontSize: isSmallCell ? 16.0 : 18.0,
                                color: getTaskCountColor(taskCount),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }

  /// Selector de mes y año
  void _showMonthYearSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => MonthYearSelector(
        selectedDate: _focusedMonth,
        onDateSelected: (DateTime newDate) {
          setState(() {
            _focusedMonth = DateTime(newDate.year, newDate.month, 1);
            _selectedDate = newDate;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// Selector de mes y año
class MonthYearSelector extends StatefulWidget {
  const MonthYearSelector({
    required this.selectedDate,
    required this.onDateSelected,
    super.key,
  });

  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  @override
  State<MonthYearSelector> createState() => _MonthYearSelectorState();
}

class _MonthYearSelectorState extends State<MonthYearSelector> {
  late int selectedYear;
  late int selectedMonth;
  bool showingMonths = true;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.selectedDate.year;
    selectedMonth = widget.selectedDate.month;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    showingMonths = !showingMonths;
                  });
                },
                child: Text(
                  showingMonths ? '$selectedYear' : 'Seleccionar año',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: showingMonths ? _buildMonthGrid() : _buildYearGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid() {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];

    return GridView.builder(
      physics:
          const ClampingScrollPhysics(), // Optimizado: physics más eficientes
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final isSelected = month == selectedMonth;

        return GestureDetector(
          onTap: () {
            widget.onDateSelected(DateTime(selectedYear, month, 1));
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF374151) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                months[index],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF2E3A59),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearGrid() {
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 10; // Optimizado: menos años hacia atrás
    final endYear = currentYear +
        10; // Optimizado: menos años hacia adelante (total ~20 años)

    return GridView.builder(
      physics:
          const ClampingScrollPhysics(), // Optimizado: physics más eficientes
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: endYear - startYear + 1,
      itemBuilder: (context, index) {
        final year = startYear + index;
        final isSelected = year == selectedYear;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedYear = year;
              showingMonths = true;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF374151) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$year',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF2E3A59),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Formulario para agregar tareas con fecha específica
class AddTaskCalendarForm extends StatefulWidget {
  const AddTaskCalendarForm({
    required this.pendingProvider,
    required this.selectedDate,
    super.key,
  });

  final PendingProvider pendingProvider;
  final DateTime selectedDate;

  @override
  State<AddTaskCalendarForm> createState() => _AddTaskCalendarFormState();
}

class _AddTaskCalendarFormState extends State<AddTaskCalendarForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _selectedDate;
  bool _isAllDay = false;
  String _repeatType = 'none';
  List<int> _customDays = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nueva Tarea',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3A59),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF374151)),
            const SizedBox(width: 8),
            Text(
              formatFullDateSpanish(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              child: const Text('Cambiar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Checkbox Todo el día con dropdown
        Row(
          children: [
            Checkbox(
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value ?? false;
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
                const Icon(Icons.repeat, size: 16, color: Color(0xFF374151)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _repeatType,
                    isExpanded: true,
                    underline: Container(),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
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
                          value: 'weekdays', child: Text('De lunes a viernes')),
                      DropdownMenuItem(
                          value: 'yearly', child: Text('Anualmente este día')),
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
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF374151),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (_titleController.text.isNotEmpty) {
                    final dateTime = _selectedDate;
                    final task = PendingTask(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: _titleController.text,
                      description: _descriptionController.text,
                      categoria: 'General',
                      dateTime: dateTime,
                      isAllDay: _isAllDay,
                      repeatType: _isAllDay && _repeatType != 'none'
                          ? _repeatType
                          : null,
                      customDays: _repeatType == 'custom' ? _customDays : null,
                    );
                    widget.pendingProvider.addTask(task);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Agregar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
