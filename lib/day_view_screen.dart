import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pending.dart';

/// Clase auxiliar para manejar información de rangos de tiempo
class TaskRangeInfo {
  final PendingTask task;
  final bool isStart;
  final bool isEnd;
  final bool isMiddle;
  
  TaskRangeInfo({
    required this.task,
    required this.isStart,
    required this.isEnd,
    required this.isMiddle,
  });
}

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
  late ScrollController _scrollController;
  final Set<int> _expandedHours = <int>{}; // Tracking de horas expandidas

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll a la hora actual si es hoy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday()) {
        _scrollToCurrentHour();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

    _scrollController.animateTo(
      scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
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
                  _formatDateSpanish(widget.selectedDate),
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

  Widget _buildHourlyView(
      List<PendingTask> dayTasks, PendingProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: 24, // 24 horas
      itemBuilder: (context, index) {
        final hour = index;
        final hourTasks = _getTasksForHour(dayTasks, hour);
        final isCurrentHour = _isCurrentHour(hour);

        final isExpanded = _expandedHours.contains(hour);
        final isEvenHour = hour % 2 == 0; // Para alternar fondos sutilmente
        
        return Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                color: isCurrentHour
                    ? const Color(0xFF6B73FF).withOpacity(0.05)
                    : isEvenHour 
                        ? Colors.transparent
                        : Colors.grey.withOpacity(0.06), // Más evidente para mejor separación
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Hora (lado izquierdo) - Ahora clickeable
                  GestureDetector(
                    onTap: () => _toggleHourExpansion(hour),
                    child: Container(
                      width: 60,
                      color: Colors.transparent, // Fondo completamente transparente
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatHour(hour),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isCurrentHour
                                          ? const Color(0xFF6B73FF)
                                          : Colors.grey[600],
                                      fontWeight: isCurrentHour 
                                          ? FontWeight.w700 
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded 
                                        ? Icons.keyboard_arrow_up 
                                        : Icons.keyboard_arrow_down,
                                    size: 14,
                                    color: isCurrentHour
                                        ? const Color(0xFF6B73FF)
                                        : Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

              // Línea divisoria
              Container(
                width: 1,
                color: isCurrentHour
                    ? const Color(0xFF6B73FF).withOpacity(0.3)
                    : Colors.grey[300],
              ),

              // Área de tareas (lado derecho)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      // Tareas existentes (no táctiles excepto por sus botones)
                      if (hourTasks.isNotEmpty) _buildTasksForHour(hourTasks, hour),
                      
                      // Botón "Agregar tarea" siempre visible
                      _buildAddTaskButton(hour, isCurrentHour, provider),
                    ],
                  ),
                ),
              ),
                ],
              ),
            ),
            
            // Minutos expandidos (si está expandida la hora)
            if (isExpanded) _buildExpandedMinutes(hour, dayTasks, provider),
          ],
        );
      },
    );
  }

  List<PendingTask> _getTasksForHour(List<PendingTask> tasks, int hour) {
    return tasks.where((task) => task.occursInHour(hour)).toList();
  }

  bool _isCurrentHour(int hour) {
    if (!_isToday()) return false;
    return DateTime.now().hour == hour;
  }

  // Método para alternar expansión de horas
  void _toggleHourExpansion(int hour) {
    setState(() {
      if (_expandedHours.contains(hour)) {
        _expandedHours.remove(hour);
      } else {
        _expandedHours.add(hour);
      }
    });
  }

  // Widget para mostrar minutos expandidos
  Widget _buildExpandedMinutes(int hour, List<PendingTask> dayTasks, PendingProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6B73FF).withOpacity(0.02),
        border: Border(
          left: BorderSide(
            color: const Color(0xFF6B73FF).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: List.generate(60, (minuteIndex) {
          final minute = minuteIndex;
          final minuteTasks = _getTasksForMinute(dayTasks, hour, minute);
          final isCurrentMinute = _isCurrentMinute(hour, minute);
          
          // Obtener información de rangos de tareas para este minuto
          final timeRangeInfo = _getTimeRangeInfoForMinute(dayTasks, hour, minute);
          
          return Container(
            height: 30,
            decoration: BoxDecoration(
              color: isCurrentMinute 
                  ? const Color(0xFF6B73FF).withOpacity(0.1)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[100]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              children: [
                // Contenido principal
                Row(
                  children: [
                // Minuto (lado izquierdo)
                Container(
                  width: 60,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${_formatHour(hour).split(' ')[0]}:${minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 9,
                          color: isCurrentMinute
                              ? const Color(0xFF6B73FF)
                              : Colors.grey[500],
                          fontWeight: isCurrentMinute
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Línea divisoria
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey[200],
                ),
                
                // Área de tareas del minuto
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 18, right: 4), // Aún más espacio para múltiples líneas
                    child: Row(
                      children: [
                        // Tareas existentes (si las hay)
                        if (minuteTasks.isNotEmpty) 
                          Expanded(child: _buildTasksForMinute(minuteTasks)),
                        
                        // Botón agregar tarea (siempre visible pero más pequeño en minutos)
                        GestureDetector(
                          onTap: () => _showAddTaskForMinute(context, provider, hour, minute),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              minuteTasks.isEmpty ? 'Agregar tarea' : '+',
                              style: TextStyle(
                                fontSize: 8,
                                color: isCurrentMinute 
                                    ? const Color(0xFF6B73FF).withOpacity(0.7)
                                    : Colors.grey[400],
                                fontStyle: minuteTasks.isEmpty ? FontStyle.italic : FontStyle.normal,
                                fontWeight: minuteTasks.isEmpty ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                  ],
                ),
                
                // Indicadores visuales de rango de tiempo
                if (timeRangeInfo.isNotEmpty) 
                  _buildTimeRangeIndicators(timeRangeInfo, hour, minute),
              ],
            ),
          );
        }),
      ),
    );
  }

  // Obtener tareas para un minuto específico
  List<PendingTask> _getTasksForMinute(List<PendingTask> tasks, int hour, int minute) {
    return tasks.where((task) {
      return task.dateTime.hour == hour && task.dateTime.minute == minute;
    }).toList();
  }

  // Verificar si es el minuto actual
  bool _isCurrentMinute(int hour, int minute) {
    if (!_isToday()) return false;
    final now = DateTime.now();
    return now.hour == hour && now.minute == minute;
  }

  // Mostrar diálogo para agregar tarea en minuto específico
  void _showAddTaskForMinute(BuildContext context, PendingProvider provider, int hour, int minute) {
    // Pasar tanto la hora como el minuto exacto
    _showAddTaskDialog(context, provider, hour: hour, minute: minute);
  }

  // Widget para mostrar tareas en un minuto
  Widget _buildTasksForMinute(List<PendingTask> tasks) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: tasks.map((task) => Container(
          margin: const EdgeInsets.symmetric(vertical: 0.5), // Menos margen
          child: _buildTaskInMinute(task), // Nueva función para manejar el estado
        )).toList(),
      ),
    );
  }

  // 🎯 ALTERNATIVA 1: TEXTO TACHADO CON OPACIDAD (ELEGANTE)
  Widget _buildTaskInMinute_Alternative1(PendingTask task) {
    return Flexible(
      child: Text(
        task.title,
        style: TextStyle(
          fontFamily: 'Georgia', // 🎨 PRUEBA 24H: Fuente Georgia para tareas
          fontSize: 7, // Reducido para evitar overflow
          color: task.completed ? task.color.withOpacity(0.4) : task.color,
          fontWeight: FontWeight.w500, // Menos bold para mejor fit
          decoration: task.completed ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: task.color.withOpacity(0.6),
          decorationThickness: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  // 🎯 ALTERNATIVA 2: ÍCONO DE CHECK PEQUEÑO
  Widget _buildTaskInMinute_Alternative2(PendingTask task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.completed) 
          Icon(
            Icons.check_circle,
            size: 6,
            color: Colors.green[400],
          ),
        if (task.completed) const SizedBox(width: 2),
        Expanded(
          child: Text(
            task.title,
            style: TextStyle(
              fontFamily: 'Georgia', // 🎨 PRUEBA 24H: Fuente Georgia para tareas
              fontSize: 7, // Reducido para evitar overflow
              color: task.completed ? task.color.withOpacity(0.6) : task.color,
              fontWeight: FontWeight.w500, // Menos bold
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  // 🎯 ALTERNATIVA 3: CAMBIO DE COLOR A GRIS SUAVE
  Widget _buildTaskInMinute_Alternative3(PendingTask task) {
    return Flexible(
      child: Text(
        task.title,
        style: TextStyle(
          fontFamily: 'Georgia', // 🎨 PRUEBA 24H: Fuente Georgia para tareas
          fontSize: 7, // Reducido para evitar overflow
          color: task.completed ? Colors.grey[400] : task.color,
          fontWeight: task.completed ? FontWeight.w400 : FontWeight.w500,
          fontStyle: task.completed ? FontStyle.italic : FontStyle.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  // 🎯 ALTERNATIVA 4: BORDE IZQUIERDO CON OPACIDAD
  Widget _buildTaskInMinute_Alternative4(PendingTask task) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: task.completed ? Colors.grey[300]! : task.color,
            width: task.completed ? 1.0 : 2.0,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 3),
      child: Text(
        task.title,
        style: TextStyle(
          fontSize: 8,
          color: task.completed ? task.color.withOpacity(0.5) : task.color,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // 🎯 ALTERNATIVA 5: COMBINACIÓN SÚPER ELEGANTE (RECOMENDADA)
  Widget _buildTaskInMinute_Alternative5(PendingTask task) {
    return Flexible(
      child: Text(
        task.title,
        style: TextStyle(
          fontFamily: 'Georgia', // 🎨 PRUEBA 24H: Fuente Georgia para tareas
          fontSize: 7, // Reducido para evitar overflow
          color: task.completed ? Colors.grey[400] : task.color,
          fontWeight: task.completed ? FontWeight.w400 : FontWeight.w500,
          decoration: task.completed ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: Colors.grey[400],
          decorationThickness: 0.8,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  // 🎯 FUNCIÓN ACTIVA - Cambia aquí el número para probar diferentes alternativas
  Widget _buildTaskInMinute(PendingTask task) {
    return _buildTaskInMinute_Alternative5(task); // 🔥 ACTUALMENTE USANDO ALTERNATIVA 5
  }

  // Obtener información de rangos de tiempo para un minuto específico
  List<TaskRangeInfo> _getTimeRangeInfoForMinute(List<PendingTask> tasks, int hour, int minute) {
    List<TaskRangeInfo> rangeInfos = [];
    
    for (var task in tasks) {
      if (task.endDateTime != null && task.occursInHour(hour)) {
        final currentMinuteTime = DateTime(2025, 1, 1, hour, minute);
        final taskStart = DateTime(2025, 1, 1, task.dateTime.hour, task.dateTime.minute);
        final taskEnd = DateTime(2025, 1, 1, task.endDateTime!.hour, task.endDateTime!.minute);
        
        // Verificar si este minuto está dentro del rango de la tarea
        if (currentMinuteTime.isAtSameMomentAs(taskStart) || 
            currentMinuteTime.isAtSameMomentAs(taskEnd) ||
            (currentMinuteTime.isAfter(taskStart) && currentMinuteTime.isBefore(taskEnd))) {
          
          // Determinar el tipo de posición en el rango
          bool isStart = currentMinuteTime.isAtSameMomentAs(taskStart);
          bool isEnd = currentMinuteTime.isAtSameMomentAs(taskEnd);
          bool isMiddle = !isStart && !isEnd;
          
          rangeInfos.add(TaskRangeInfo(
            task: task,
            isStart: isStart,
            isEnd: isEnd,
            isMiddle: isMiddle,
          ));
        }
      }
    }
    
    return rangeInfos;
  }

  // Widget para mostrar indicadores visuales de rangos de tiempo
  Widget _buildTimeRangeIndicators(List<TaskRangeInfo> rangeInfos, int hour, int minute) {
    return Positioned(
      left: 61, // Posición perfectamente centrada
      top: 2,
      bottom: 2,
      child: Container(
        width: 12, // Más ancho para acomodar múltiples tareas sin superposición
        child: Stack(
          children: rangeInfos.asMap().entries.map((entry) {
            int index = entry.key;
            TaskRangeInfo info = entry.value;
            
            return Positioned(
              left: index * 2.5, // Mayor separación entre líneas
              top: 0,
              bottom: 0,
              child: Container(
                width: 2.5, // Líneas más delgadas pero claras
                decoration: BoxDecoration(
                  color: info.task.completed 
                      ? info.task.color.withOpacity(0.3) // Opacidad para tareas completadas
                      : info.task.color, // Color sólido para tareas activas
                  borderRadius: BorderRadius.circular(1.25),
                  boxShadow: [
                    BoxShadow(
                      color: info.task.completed 
                          ? info.task.color.withOpacity(0.1) // Sombra más sutil para completadas
                          : info.task.color.withOpacity(0.3),
                      blurRadius: 2,
                      offset: const Offset(0.5, 0),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Punto de inicio más prominente y claro
                    if (info.isStart)
                      Positioned(
                        top: -2,
                        left: -2,
                        right: -2,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: info.task.completed 
                                ? info.task.color.withOpacity(0.4) // Punto inicio opaco si completada
                                : info.task.color,
                            borderRadius: BorderRadius.circular(3.5),
                            border: Border.all(
                              color: Colors.white,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: info.task.completed 
                                    ? info.task.color.withOpacity(0.2) // Sombra más sutil si completada
                                    : info.task.color.withOpacity(0.7),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Punto de fin más prominente y claro
                    if (info.isEnd)
                      Positioned(
                        bottom: -2,
                        left: -2,
                        right: -2,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: info.task.completed 
                                ? info.task.color.withOpacity(0.4) // Punto fin opaco si completada
                                : info.task.color,
                            borderRadius: BorderRadius.circular(3.5),
                            border: Border.all(
                              color: Colors.white,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: info.task.completed 
                                    ? info.task.color.withOpacity(0.2) // Sombra más sutil si completada
                                    : info.task.color.withOpacity(0.7),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Línea intermedia más clara y continua
                    if (info.isMiddle)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: info.task.completed 
                              ? info.task.color.withOpacity(0.25) // Línea intermedia muy sutil si completada
                              : info.task.color.withOpacity(0.9), // Más opaco para mayor claridad si activa
                          borderRadius: BorderRadius.circular(1.25),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Botón para agregar tarea - siempre visible
  Widget _buildAddTaskButton(int hour, bool isCurrentHour, PendingProvider provider) {
    return GestureDetector(
      onTap: () => _showAddTaskForHour(context, provider, hour),
      child: Container(
        width: double.infinity, // Ocupar todo el ancho disponible
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Más padding
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrentHour
                ? const Color(0xFF6B73FF).withOpacity(0.4)
                : Colors.grey[300]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
          color: isCurrentHour
              ? const Color(0xFF6B73FF).withOpacity(0.02)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: isCurrentHour
                  ? const Color(0xFF6B73FF).withOpacity(0.7)
                  : Colors.grey[400],
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Agregar tarea',
              style: TextStyle(
                color: isCurrentHour
                    ? const Color(0xFF6B73FF).withOpacity(0.7)
                    : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksForHour(List<PendingTask> tasks, int hour) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: tasks.map((task) {
          final portion = task.getPortionInHour(hour);

          // Calcular altura basada en la duración en esta hora
          final baseHeight = 50.0; // Altura base
          final durationHeight = baseHeight * portion;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            height: durationHeight.clamp(35.0, 80.0), // Altura mínima y máxima
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: task.completed ? Colors.grey[300] : task.color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Indicador de tiempo
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTimeRangeForTask(task, hour),
                      style: TextStyle(
                        color: task.completed ? Colors.grey[600] : Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Contenido de la tarea
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontFamily: 'Georgia', // 🎨 PRUEBA 24H: Fuente Georgia para tareas
                            color: task.completed
                                ? Colors.grey[600]
                                : Colors.white,
                            fontWeight: FontWeight.w500, // Menos bold para mejor fit
                            fontSize: 10, // Reducido para evitar overflow
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description.isNotEmpty && durationHeight > 50)
                          Text(
                            task.description,
                            style: TextStyle(
                              color: task.completed
                                  ? Colors.grey[500]
                                  : Colors.white.withOpacity(0.8),
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Botones de acción
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🎯 BOTONES CON VISIBILIDAD GARANTIZADA
                      _buildVisibleEditButton(task),
                      const SizedBox(width: 2),
                      _buildVisibleDeleteButton(task), 
                      const SizedBox(width: 4),
                      _buildVisibleCompleteButton(task),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getTimeRangeForTask(PendingTask task, int hour) {
    if (task.endDateTime == null) {
      return _formatTime12Hour(task.dateTime.hour, task.dateTime.minute);
    }

    if (task.dateTime.hour == hour && task.endDateTime!.hour == hour) {
      // Tarea completa en esta hora
      return '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}-${_formatTime12Hour(task.endDateTime!.hour, task.endDateTime!.minute)}';
    } else if (task.dateTime.hour == hour) {
      // Tarea comienza en esta hora
      if (task.endDateTime!.hour > hour + 1) {
        // La tarea continúa más allá de la siguiente hora - mostrar hasta el final de esta hora
        return '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}-${_formatTime12Hour(hour + 1, 0)}';
      } else {
        // La tarea termina en la siguiente hora - mostrar hora final real con minutos
        return '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}-${_formatTime12Hour(task.endDateTime!.hour, task.endDateTime!.minute)}';
      }
    } else if (task.endDateTime!.hour == hour + 1 &&
        task.endDateTime!.minute > 0) {
      // Tarea termina en la siguiente hora con minutos - mostrar hora final real
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(task.endDateTime!.hour, task.endDateTime!.minute)}';
    } else if (task.endDateTime!.hour == hour) {
      // Tarea termina exactamente en esta hora - mostrar minutos reales
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(task.endDateTime!.hour, task.endDateTime!.minute)}';
    } else if (task.endDateTime!.hour > hour) {
      // Tarea continúa más allá de esta hora (hora intermedia completa)
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(hour + 1, 0)}';
    } else {
      // Caso especial: tarea termina en esta hora pero con minutos
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(task.endDateTime!.hour, task.endDateTime!.minute)}';
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatTime12Hour(int hour, int minute) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour;
    if (hour == 0)
      displayHour = 12;
    else if (hour > 12) displayHour = hour - 12;

    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showAddTaskForHour(
      BuildContext context, PendingProvider provider, int hour) {
    _showAddTaskDialog(context, provider, hour: hour);
  }

  void _showAddTaskDialog(BuildContext context, PendingProvider provider,
      {int? hour, int? minute}) {
    showDialog(
      context: context,
      builder: (context) => AddTaskHourlyForm(
        pendingProvider: provider,
        selectedDate: widget.selectedDate,
        selectedHour: hour,
        selectedMinute: minute,
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, PendingTask task) {
    showDialog(
      context: context,
      builder: (context) => EditTaskHourlyForm(
        task: task,
        pendingProvider: context.read<PendingProvider>(),
        selectedDate: widget.selectedDate,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, PendingTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar tarea?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3A59),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontFamily: 'Georgia', // 🎨 PRUEBA 24H: Fuente Georgia para tareas
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}${task.endDateTime != null ? ' - ${_formatTime12Hour(task.endDateTime!.hour, task.endDateTime!.minute)}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF6B73FF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final provider = context.read<PendingProvider>();
              provider.deleteTask(task.id);
              Navigator.of(context).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // � Formateo manual de fechas en español (sin afectar selectores de hora)
  String _formatDateSpanish(DateTime date) {
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 
                    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    
    final dayName = days[date.weekday % 7];
    final monthName = months[date.month - 1];
    
    return '${dayName[0].toUpperCase()}${dayName.substring(1)}, ${date.day} de $monthName';
  }

  // �🎯 ALTERNATIVA 4: CONTRASTE INTELIGENTE ADAPTATIVO (SÚPER ELEGANTE Y DISCRETO)
  Widget _buildVisibleEditButton(PendingTask task) {
    // Detecta automáticamente si el color de fondo es claro u oscuro
    final bgLuminance = task.color.computeLuminance();
    final iconColor = bgLuminance > 0.5 ? Colors.black87 : Colors.white;
    
    return GestureDetector(
      onTap: () => _showEditTaskDialog(context, task),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.edit,
          color: iconColor,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildVisibleDeleteButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final iconColor = bgLuminance > 0.5 ? Colors.red[700]! : Colors.red[300]!;
    
    return GestureDetector(
      onTap: () => _showDeleteConfirmation(context, task),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.delete_outline,
          color: iconColor,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildVisibleCompleteButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final checkColor = task.completed ? Colors.green[400]! : 
                      (bgLuminance > 0.5 ? Colors.black54 : Colors.white70);
    
    return GestureDetector(
      onTap: () {
        final provider = context.read<PendingProvider>();
        provider.toggleTaskCompletion(task.id);
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Icon(
          task.completed
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: checkColor,
          size: 16,
        ),
      ),
    );
  }
}

/// Formulario para agregar tareas con hora específica
class AddTaskHourlyForm extends StatefulWidget {
  final PendingProvider pendingProvider;
  final DateTime selectedDate;
  final int? selectedHour;
  final int? selectedMinute;

  const AddTaskHourlyForm({
    super.key,
    required this.pendingProvider,
    required this.selectedDate,
    this.selectedHour,
    this.selectedMinute,
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
  String _selectedColorHex = TaskColors.pastelColors[0]; // Color por defecto

  static bool _lastEndTimePreference = false; // Recordar la última preferencia

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.selectedHour ?? DateTime.now().hour;
    _selectedMinute = widget.selectedMinute ?? 0; // Usar minuto específico si se proporciona
    _hasEndTime = _lastEndTimePreference; // Usar la última preferencia
    if (_hasEndTime) {
      _endHour = _selectedHour + 1;
      _endMinute = _selectedMinute;
    }
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

            // Color Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 50,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: TaskColors.pastelColors.length,
                    itemBuilder: (context, index) {
                      final colorHex = TaskColors.pastelColors[index];
                      final colorName = TaskColors.colorNames[index];
                      final color = TaskColors.hexToColor(colorHex);
                      final isSelected = _selectedColorHex == colorHex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorHex = colorHex;
                          });
                        },
                        child: Tooltip(
                          message: colorName,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.grey[300]!,
                                width: isSelected ? 2.5 : 0.8,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF6B73FF), size: 20),
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
            _buildTimePicker('Hora de inicio', _selectedHour, _selectedMinute,
                (hour, minute) {
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
                      _lastEndTimePreference =
                          _hasEndTime; // Guardar preferencia
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
              _buildTimePicker('Hora final', _endHour!, _endMinute!,
                  (hour, minute) {
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

  Widget _buildTimePicker(
      String label, int hour, int minute, Function(int, int) onChanged) {
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

  void _showTimePicker(
      int currentHour, int currentMinute, Function(int, int) onChanged) {
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

      DateTime? endDateTime;
      if (_hasEndTime && _endHour != null && _endMinute != null) {
        endDateTime = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          _endHour!,
          _endMinute!,
        );

        // Verificar que la hora de fin sea posterior a la hora de inicio
        if (!endDateTime.isAfter(taskDateTime)) {
          // Si la hora de fin es antes o igual a la hora de inicio, mostrar error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'La hora de finalización debe ser posterior a la hora de inicio'),
              backgroundColor: Colors.red,
            ),
          );
          return; // No guardar la tarea
        }
      }

      final task = PendingTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        categoria: 'Agenda',
        dateTime: taskDateTime,
        endDateTime: endDateTime,
        colorHex: _selectedColorHex,
      );

      // Debug: Imprimir información de la tarea
      print('🔍 GUARDANDO TAREA:');
      print('📝 Título: ${task.title}');
      print(
          '🕐 Inicio: ${taskDateTime.hour}:${taskDateTime.minute.toString().padLeft(2, '0')}');
      print(
          '🕑 Fin: ${endDateTime?.hour}:${endDateTime?.minute.toString().padLeft(2, '0')}');
      print(
          '⏱️ Duración: ${endDateTime != null ? endDateTime.difference(taskDateTime).inMinutes : 'Sin fin'} minutos');

      widget.pendingProvider.addTask(task);
      Navigator.of(context).pop();
    }
  }
}

/// Formulario para editar tareas existentes
class EditTaskHourlyForm extends StatefulWidget {
  final PendingTask task;
  final PendingProvider pendingProvider;
  final DateTime selectedDate;

  const EditTaskHourlyForm({
    super.key,
    required this.task,
    required this.pendingProvider,
    required this.selectedDate,
  });

  @override
  State<EditTaskHourlyForm> createState() => _EditTaskHourlyFormState();
}

class _EditTaskHourlyFormState extends State<EditTaskHourlyForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late int _selectedHour;
  late int _selectedMinute;
  int? _endHour;
  int? _endMinute;
  bool _hasEndTime = false;
  late String _selectedColorHex;

  @override
  void initState() {
    super.initState();
    // Cargar datos existentes de la tarea
    _titleController.text = widget.task.title;
    _descriptionController.text = widget.task.description;
    _selectedHour = widget.task.dateTime.hour;
    _selectedMinute = widget.task.dateTime.minute;
    _selectedColorHex = widget.task.colorHex;

    // Configurar hora de finalización si existe
    if (widget.task.endDateTime != null) {
      _hasEndTime = true;
      _endHour = widget.task.endDateTime!.hour;
      _endMinute = widget.task.endDateTime!.minute;
    }
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
              'Editar Tarea',
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

            // Color Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 50,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: TaskColors.pastelColors.length,
                    itemBuilder: (context, index) {
                      final colorHex = TaskColors.pastelColors[index];
                      final colorName = TaskColors.colorNames[index];
                      final color = TaskColors.hexToColor(colorHex);
                      final isSelected = _selectedColorHex == colorHex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorHex = colorHex;
                          });
                        },
                        child: Tooltip(
                          message: colorName,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.grey[300]!,
                                width: isSelected ? 2.5 : 0.8,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF6B73FF), size: 20),
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
            _buildTimePicker('Hora de inicio', _selectedHour, _selectedMinute,
                (hour, minute) {
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
              _buildTimePicker('Hora final', _endHour!, _endMinute!,
                  (hour, minute) {
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
                    onPressed: _updateTask,
                    child: const Text('Actualizar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
      String label, int hour, int minute, Function(int, int) onChanged) {
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

  void _showTimePicker(
      int currentHour, int currentMinute, Function(int, int) onChanged) {
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

  void _updateTask() {
    if (_titleController.text.isNotEmpty) {
      final taskDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );

      DateTime? endDateTime;
      if (_hasEndTime && _endHour != null && _endMinute != null) {
        endDateTime = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          _endHour!,
          _endMinute!,
        );

        // Verificar que la hora de fin sea posterior a la hora de inicio
        if (!endDateTime.isAfter(taskDateTime)) {
          // Si la hora de fin es antes o igual a la hora de inicio, mostrar error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'La hora de finalización debe ser posterior a la hora de inicio'),
              backgroundColor: Colors.red,
            ),
          );
          return; // No actualizar la tarea
        }
      }

      // Actualizar la tarea existente
      final updatedTask = PendingTask(
        id: widget.task.id, // Mantener el mismo ID
        title: _titleController.text,
        description: _descriptionController.text,
        categoria: widget.task.categoria, // Mantener la misma categoría
        dateTime: taskDateTime,
        endDateTime: endDateTime,
        completed: widget.task.completed, // Mantener el estado de completado
        colorHex: _selectedColorHex,
      );

      widget.pendingProvider.updateTask(updatedTask);
      Navigator.of(context).pop();
    }
  }
}
