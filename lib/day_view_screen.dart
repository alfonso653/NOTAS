import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pending.dart';

/// Pantalla de vista diaria con franjas horarias
class DayViewScreen extends StatefulWidget {
  final DateTime selectedDate;
  
  const DayViewScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends State<DayViewScreen> {
  late ScrollController _scrollController1;
  late ScrollController _scrollController2;
  
  @override
  void initState() {
    super.initState();
    _scrollController1 = ScrollController();
    _scrollController2 = ScrollController();
    
    // Auto-scroll a la hora actual si es hoy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday()) {
        _scrollToCurrentHour();
      }
    });
  }

  @override
  void dispose() {
    _scrollController1.dispose();
    _scrollController2.dispose();
    super.dispose();
  }

  bool _isToday() {
    final now = DateTime.now();
    return widget.selectedDate.year == now.year &&
           widget.selectedDate.month == now.month &&
           widget.selectedDate.day == now.day;
  }

  void _scrollToCurrentHour() {
    final now = DateTime.now();
    final currentHour = now.hour;
    // Cada franja horaria tiene 60px de altura
    final scrollOffset = (currentHour * 60.0) - 100; // -100 para centrar mejor
    
    _scrollController1.animateTo(
      scrollOffset.clamp(0.0, _scrollController1.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    
    _scrollController2.animateTo(
      scrollOffset.clamp(0.0, _scrollController2.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingProvider>(
      builder: (context, provider, _) {
        final dayTasks = _getTasksForDay(provider.tasks);
        
        return Scaffold(
          backgroundColor: const Color(0xFFFEF7F0),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3A59)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM').format(widget.selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A59),
                  ),
                ),
                if (_isToday())
                  const Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B73FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF6B73FF)),
                onPressed: () => _showAddTaskDialog(context, provider),
              ),
            ],
          ),
          body: _buildHourlyView(dayTasks, provider),
        );
      },
    );
  }

  List<PendingTask> _getTasksForDay(List<PendingTask> allTasks) {
    return allTasks.where((task) {
      return task.dateTime.year == widget.selectedDate.year &&
             task.dateTime.month == widget.selectedDate.month &&
             task.dateTime.day == widget.selectedDate.day;
    }).toList();
  }

  Widget _buildHourlyView(List<PendingTask> dayTasks, PendingProvider provider) {
    return Row(
      children: [
        // Columna de horas (lado izquierdo)
        Container(
          width: 60,
          color: Colors.grey[50],
          child: ListView.builder(
            controller: _scrollController1,
            itemCount: 24, // 24 horas
            itemBuilder: (context, index) {
              final hour = index;
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      _formatHour(hour),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Línea divisoria
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        
        // Área de tareas (lado derecho)
        Expanded(
          child: ListView.builder(
            controller: _scrollController2,
            itemCount: 24,
            itemBuilder: (context, index) {
              final hour = index;
              final hourTasks = _getTasksForHour(dayTasks, hour);
              final isCurrentHour = _isCurrentHour(hour);
              
              return GestureDetector(
                onTap: () => _showAddTaskForHour(context, provider, hour),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: isCurrentHour 
                        ? const Color(0xFF6B73FF).withOpacity(0.05)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                    ),
                  ),
                  child: hourTasks.isEmpty 
                      ? _buildEmptyHourSlot(hour, isCurrentHour)
                      : _buildTasksForHour(hourTasks),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<PendingTask> _getTasksForHour(List<PendingTask> tasks, int hour) {
    return tasks.where((task) => task.dateTime.hour == hour).toList();
  }

  bool _isCurrentHour(int hour) {
    if (!_isToday()) return false;
    return DateTime.now().hour == hour;
  }

  Widget _buildEmptyHourSlot(int hour, bool isCurrentHour) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrentHour 
              ? const Color(0xFF6B73FF).withOpacity(0.3)
              : Colors.grey[300]!,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          Icons.add,
          color: Colors.grey[400],
          size: 16,
        ),
      ),
    );
  }

  Widget _buildTasksForHour(List<PendingTask> tasks) {
    return Column(
      children: tasks.map((task) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: task.completed 
                  ? Colors.grey[300]
                  : const Color(0xFF6B73FF).withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.completed ? Colors.grey[600] : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    style: TextStyle(
                      color: task.completed 
                          ? Colors.grey[500] 
                          : Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  void _showAddTaskForHour(BuildContext context, PendingProvider provider, int hour) {
    _showAddTaskDialog(context, provider, hour: hour);
  }

  void _showAddTaskDialog(BuildContext context, PendingProvider provider, {int? hour}) {
    showDialog(
      context: context,
      builder: (context) => AddTaskHourlyForm(
        pendingProvider: provider,
        selectedDate: widget.selectedDate,
        selectedHour: hour,
      ),
    );
  }
}

/// Formulario para agregar tareas con hora específica
class AddTaskHourlyForm extends StatefulWidget {
  final PendingProvider pendingProvider;
  final DateTime selectedDate;
  final int? selectedHour;

  const AddTaskHourlyForm({
    super.key,
    required this.pendingProvider,
    required this.selectedDate,
    this.selectedHour,
  });

  @override
  State<AddTaskHourlyForm> createState() => _AddTaskHourlyFormState();
}

class _AddTaskHourlyFormState extends State<AddTaskHourlyForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late int _selectedHour;
  late int _selectedMinute;
  int? _endHour;
  int? _endMinute;
  bool _hasEndTime = false;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.selectedHour ?? DateTime.now().hour;
    _selectedMinute = 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nueva Tarea',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A59),
              ),
            ),
            const SizedBox(height: 16),
            
            // Título
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
            // Descripción
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Fecha
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF6B73FF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(widget.selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Hora de inicio
            _buildTimePicker('Hora de inicio', _selectedHour, _selectedMinute, (hour, minute) {
              setState(() {
                _selectedHour = hour;
                _selectedMinute = minute;
              });
            }),
            
            // Checkbox para hora final
            Row(
              children: [
                Checkbox(
                  value: _hasEndTime,
                  onChanged: (value) {
                    setState(() {
                      _hasEndTime = value ?? false;
                      if (_hasEndTime && _endHour == null) {
                        _endHour = _selectedHour + 1;
                        _endMinute = _selectedMinute;
                      }
                    });
                  },
                ),
                const Text('Agregar hora final'),
              ],
            ),
            
            // Hora final (si está habilitada)
            if (_hasEndTime)
              _buildTimePicker('Hora final', _endHour!, _endMinute!, (hour, minute) {
                setState(() {
                  _endHour = hour;
                  _endMinute = minute;
                });
              }),
            
            const SizedBox(height: 20),
            
            // Botones
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
                    onPressed: _addTask,
                    child: const Text('Agregar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, int hour, int minute, Function(int, int) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showTimePicker(hour, minute, onChanged),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6B73FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatTime(hour, minute),
                style: const TextStyle(
                  color: Color(0xFF6B73FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimePicker(int currentHour, int currentMinute, Function(int, int) onChanged) {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
    ).then((time) {
      if (time != null) {
        onChanged(time.hour, time.minute);
      }
    });
  }

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }

  void _addTask() {
    if (_titleController.text.isNotEmpty) {
      final taskDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );

      final task = PendingTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        categoria: 'Agenda',
        dateTime: taskDateTime,
      );

      widget.pendingProvider.addTask(task);
      Navigator.of(context).pop();
    }
  }
}