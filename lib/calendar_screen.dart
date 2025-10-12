import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pending.dart';
import 'day_view_screen.dart';
import 'daily_verse_widget.dart';

// 🌍 Funciones globales para formateo en español (sin afectar selectores)
String formatMonthYearSpanish(DateTime date) {
  const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  final monthName = months[date.month - 1];
  return '${monthName[0].toUpperCase()}${monthName.substring(1)} ${date.year}';
}

String formatFullDateSpanish(DateTime date) {
  const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
  const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  
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

    // Actualizar la fecha actual cada minuto
    _startDateUpdateTimer();
  }

  void _startDateUpdateTimer() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        final newToday = DateTime.now();
        if (_today.day != newToday.day ||
            _today.month != newToday.month ||
            _today.year != newToday.year) {
          setState(() {
            _today = newToday;
          });
        }
      } else {
        timer.cancel();
      }
    });
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

  /// Obtiene las tareas para una fecha específica
  List<PendingTask> _getTasksForDate(
      DateTime date, List<PendingTask> allTasks) {
    return allTasks.where((task) {
      return task.dateTime.year == date.year &&
          task.dateTime.month == date.month &&
          task.dateTime.day == date.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFEF7F0),
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
                      color: const Color(0xFF6B73FF).withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B73FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.today,
                      color: Color(0xFF6B73FF), size: 20),
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
          body: Column(
            children: [
              // Header con días de la semana
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
                      .map((day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B73FF),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
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
                          color: Color(0xFF6B73FF)),
                      onPressed: _previousMonth,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Color(0xFF6B73FF)),
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

    // Debug: Verificar que el mes se está calculando correctamente
    print(
        '📅 Mostrando: ${DateFormat('MMMM yyyy').format(monthDate)} - Días: $daysInMonth');

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8, // Más alto para mostrar tareas
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: 42, // 6 semanas * 7 días
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
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected && isToday
              ? const Color(0xFF6B73FF).withOpacity(0.2)
              : isSelected
                  ? const Color(0xFF6B73FF).withOpacity(0.1)
                  : isToday
                      ? const Color(0xFF6B73FF).withOpacity(0.15)
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected && isToday
              ? Border.all(color: const Color(0xFF6B73FF), width: 2.5)
              : isSelected
                  ? Border.all(color: const Color(0xFF6B73FF), width: 2)
                  : isToday
                      ? Border.all(color: const Color(0xFF6B73FF), width: 2)
                      : null,
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: const Color(0xFF6B73FF).withOpacity(0.3),
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
                      color: const Color(0xFF6B73FF),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              padding: isToday
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                  : EdgeInsets.zero,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: isToday ? 13 : 12,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                  color: isOtherMonth
                      ? Colors.grey.withOpacity(0.4)
                      : isToday
                          ? Colors.white
                          : const Color(0xFF2E3A59),
                ),
              ),
            ),
            // Tareas como etiquetas pequeñas
            Expanded(
              child: tasks.isEmpty
                  ? const SizedBox()
                  : SingleChildScrollView(
                      child: Column(
                        children: tasks.take(3).map((task) {
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 1),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1),
                                decoration: BoxDecoration(
                                  color: task.completed
                                      ? Colors.grey.withOpacity(0.3)
                                      : const Color(0xFF6B73FF)
                                          .withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: task.completed
                                        ? Colors.grey[600]
                                        : Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList() +
                            (tasks.length > 3
                                ? [
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 1),
                                      child: Text(
                                        '+${tasks.length - 3} más',
                                        style: const TextStyle(
                                          fontSize: 7,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ]
                                : []),
                      ),
                    ),
            ),
          ],
        ),
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
                    color: Color(0xFF6B73FF),
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
              color: isSelected ? const Color(0xFF6B73FF) : Colors.grey[100],
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
    final startYear = currentYear - 20; // Más años hacia atrás
    final endYear =
        currentYear + 20; // Más años hacia adelante (total ~40 años)

    return GridView.builder(
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
              color: isSelected ? const Color(0xFF6B73FF) : Colors.grey[100],
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
            const Icon(Icons.calendar_today, color: Color(0xFF6B73FF)),
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
                  backgroundColor: const Color(0xFF6B73FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (_titleController.text.isNotEmpty) {
                    final task = PendingTask(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: _titleController.text,
                      description: _descriptionController.text,
                      categoria: 'General',
                      dateTime: _selectedDate,
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
