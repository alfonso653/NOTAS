import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pending.dart';
import 'day_view_screen.dart';

/// Vista mensual de todas las tareas organizadas por fecha
class MonthlyTasksView extends StatefulWidget {
  const MonthlyTasksView({super.key});

  @override
  State<MonthlyTasksView> createState() => _MonthlyTasksViewState();
}

class _MonthlyTasksViewState extends State<MonthlyTasksView> {
  late DateTime _currentMonth;
  String _filterStatus = 'all'; // 'all', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const days = [
      'Domingo', 'Lunes', 'Martes', 'Miércoles', 
      'Jueves', 'Viernes', 'Sábado'
    ];
    final dayName = days[date.weekday % 7];
    return '$dayName, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<PendingTask> _getTasksForMonth(List<PendingTask> allTasks) {
    return allTasks.where((task) {
      final isSameMonth = task.dateTime.year == _currentMonth.year && 
                         task.dateTime.month == _currentMonth.month;
      
      if (!isSameMonth) return false;
      
      switch (_filterStatus) {
        case 'pending':
          return !task.completed;
        case 'completed':
          return task.completed;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, List<PendingTask>> _groupTasksByDate(List<PendingTask> tasks) {
    final Map<String, List<PendingTask>> grouped = {};
    
    for (final task in tasks) {
      final dateKey = DateFormat('yyyy-MM-dd').format(task.dateTime);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(task);
    }
    
    // Ordenar tareas por hora dentro de cada día
    grouped.forEach((key, taskList) {
      taskList.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });
    
    return grouped;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingProvider>(
      builder: (context, provider, _) {
        final monthTasks = _getTasksForMonth(provider.tasks);
        final groupedTasks = _groupTasksByDate(monthTasks);
        final sortedDates = groupedTasks.keys.toList()..sort();

        return Scaffold(
          backgroundColor: const Color(0xFFFEF7F0),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3A59)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: GestureDetector(
              onTap: _goToToday,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tareas del Mes',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3A59),
                    ),
                  ),
                  Text(
                    _formatMonth(_currentMonth),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Navegación de meses
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFF374151)),
                onPressed: _previousMonth,
                tooltip: 'Mes anterior',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFF374151)),
                onPressed: _nextMonth,
                tooltip: 'Mes siguiente',
              ),
              // Filtros
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list, color: Color(0xFF374151)),
                onSelected: (value) {
                  setState(() {
                    _filterStatus = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('Todas las tareas'),
                  ),
                  const PopupMenuItem(
                    value: 'pending',
                    child: Text('Solo pendientes'),
                  ),
                  const PopupMenuItem(
                    value: 'completed',
                    child: Text('Solo completadas'),
                  ),
                ],
              ),
            ],
          ),
          body: monthTasks.isEmpty
              ? _buildEmptyState()
              : _buildTasksList(sortedDates, groupedTasks, provider),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay tareas en ${_formatMonth(_currentMonth)}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'pending' 
                ? 'No hay tareas pendientes'
                : _filterStatus == 'completed'
                    ? 'No hay tareas completadas'
                    : 'Puedes agregar tareas desde el calendario',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList(List<String> sortedDates, Map<String, List<PendingTask>> groupedTasks, PendingProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final date = DateTime.parse(dateKey);
        final tasks = groupedTasks[dateKey]!;
        final isToday = _isToday(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isToday ? const Color(0xFF374151).withOpacity(0.05) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado de fecha
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isToday 
                      ? const Color(0xFF374151).withOpacity(0.1)
                      : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: isToday ? const Color(0xFF2E3A59) : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday ? const Color(0xFF2E3A59) : const Color(0xFF374151),
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E3A59),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HOY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '${tasks.length} tarea${tasks.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de tareas
              ...tasks.asMap().entries.map((entry) {
                final taskIndex = entry.key;
                final task = entry.value;
                final isLast = taskIndex == tasks.length - 1;
                
                return _buildTaskItem(task, isLast, provider, date);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(PendingTask task, bool isLast, PendingProvider provider, DateTime date) {
    final timeFormat = DateFormat('HH:mm');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: !isLast 
            ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          // 🎯 CHECKBOX MÁS GRANDE Y SIN INTERFERENCIA
          GestureDetector(
            onTap: () {
              provider.toggleTaskCompletion(task.id);
              // Forzar actualización inmediata
              setState(() {});
            },
            child: Container(
              width: 32, // 🔍 MÁS GRANDE (era 24)
              height: 32, // 🔍 MÁS GRANDE (era 24)
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.completed 
                      ? Colors.green 
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: task.completed ? Colors.green : Colors.transparent,
              ),
              child: task.completed
                  ? const Icon(
                        Icons.check,
                        size: 18, // Ícono también más grande
                        color: Colors.white,
                      )
                    : null,
            ),
          ),
          
          // Hora (SIN navegación)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: task.completed 
                  ? Colors.grey[200] 
                  : const Color(0xFF374151).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeFormat.format(task.dateTime),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: task.completed 
                    ? Colors.grey[600] 
                    : const Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Título de la tarea (SIN navegación)
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: task.completed 
                    ? Colors.grey[500] 
                    : const Color(0xFF2E3A59),
                decoration: task.completed 
                    ? TextDecoration.lineThrough 
                    : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Indicadores y flechita para navegar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.hasNotification)
                Icon(
                  Icons.notifications_active,
                  size: 16,
                  color: Colors.amber[700],
                ),
              if (task.hasAlarm)
                Icon(
                  Icons.alarm,
                  size: 16,
                  color: Colors.red[400],
                ),
              
              // 🎯 FLECHITA GRANDE Y VISIBLE PARA IR AL DÍA
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DayViewScreen(
                        selectedDate: date,
                        targetTaskId: task.id, // 🎯 Ir a la tarea específica
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8), // Área más grande para tocar
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 18, // Flechita más grande y visible
                    color: task.completed 
                        ? Colors.grey[400] 
                        : const Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
           date.month == today.month &&
           date.day == today.day;
  }
}