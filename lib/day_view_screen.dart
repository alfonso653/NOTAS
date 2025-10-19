import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'pending.dart';
import 'notification_service.dart';
import 'notebook_screen.dart';

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
  final Set<int> _expandedHours = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

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
    final scrollOffset = (currentHour * 60.0) - 100;

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
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Text('📔', style: TextStyle(fontSize: 20)),
                onPressed: () => showNotebook(
                  context,
                  date: widget.selectedDate,
                ),
                tooltip: 'Cuaderno del día',
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF374151)),
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
    final dayTasks = allTasks.where((task) {
      return task.dateTime.year == widget.selectedDate.year &&
          task.dateTime.month == widget.selectedDate.month &&
          task.dateTime.day == widget.selectedDate.day;
    }).toList();

    dayTasks.sort((a, b) {
      final aTime = a.dateTime.hour * 60 + a.dateTime.minute;
      final bTime = b.dateTime.hour * 60 + b.dateTime.minute;
      return aTime.compareTo(bTime);
    });

    return dayTasks;
  }

  Widget _buildHourlyView(
      List<PendingTask> dayTasks, PendingProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: 24,
      itemBuilder: (context, index) {
        final hour = index;
        final hourTasks = _getTasksForHour(dayTasks, hour);
        final isCurrentHour = _isCurrentHour(hour);
        final isExpanded = _expandedHours.contains(hour);
        final isEvenHour = hour % 2 == 0;

        return Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                color: isCurrentHour
                    ? const Color(0xFF374151).withOpacity(0.05)
                    : isEvenHour
                        ? Colors.transparent
                        : Colors.grey.withOpacity(0.06),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Hora (lado izquierdo)
                  GestureDetector(
                    onTap: () => _toggleHourExpansion(hour),
                    child: Container(
                      width: _leftColumnWidth(context),
                      constraints:
                          const BoxConstraints(minWidth: 50, maxWidth: 70),
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _formatHour(hour),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isCurrentHour
                                            ? const Color(0xFF374151)
                                            : Colors.grey[600],
                                        fontWeight: isCurrentHour
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 12,
                                    color: isCurrentHour
                                        ? const Color(0xFF374151)
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
                        ? const Color(0xFF374151).withOpacity(0.3)
                        : Colors.grey[300],
                  ),

                  // Área de tareas
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          if (hourTasks.isNotEmpty)
                            _buildTasksForHour(hourTasks, hour),
                          _buildAddTaskButton(hour, isCurrentHour, provider),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded) _buildExpandedMinutes(hour, dayTasks, provider),
          ],
        );
      },
    );
  }

  double _leftColumnWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final candidate = w * 0.15;
    if (candidate < 50) return 50;
    if (candidate > 70) return 70;
    return candidate;
  }

  List<PendingTask> _getTasksForHour(List<PendingTask> tasks, int hour) {
    final hourTasks = tasks.where((task) => task.occursInHour(hour)).toList();
    hourTasks.sort((a, b) => a.dateTime.minute.compareTo(b.dateTime.minute));
    return hourTasks;
  }

  bool _isCurrentHour(int hour) {
    if (!_isToday()) return false;
    return DateTime.now().hour == hour;
  }

  void _toggleHourExpansion(int hour) {
    setState(() {
      if (_expandedHours.contains(hour)) {
        _expandedHours.remove(hour);
      } else {
        _expandedHours.add(hour);
      }
    });
  }

  Widget _buildExpandedMinutes(
      int hour, List<PendingTask> dayTasks, PendingProvider provider) {
    final leftWidth = _leftColumnWidth(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withOpacity(0.02),
        border: Border(
          left: BorderSide(
            color: const Color(0xFF374151).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: List.generate(60, (minuteIndex) {
          final minute = minuteIndex;
          final minuteTasks = _getTasksForMinute(dayTasks, hour, minute);
          final isCurrentMinute = _isCurrentMinute(hour, minute);

          final timeRangeInfo =
              _getTimeRangeInfoForMinute(dayTasks, hour, minute);

          return Container(
            height: 30,
            decoration: BoxDecoration(
              color: isCurrentMinute
                  ? const Color(0xFF374151).withOpacity(0.1)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!.withOpacity(0.6),
                  width: 0.8,
                ),
              ),
            ),
            child: Stack(
              children: [
                if (timeRangeInfo.isNotEmpty)
                  _buildTimeRangeIndicators(timeRangeInfo, leftWidth),
                Row(
                  children: [
                    // Minuto (lado izquierdo)
                    Container(
                      width: leftWidth,
                      constraints:
                          const BoxConstraints(minWidth: 50, maxWidth: 70),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${_formatHour(hour).split(' ')[0]}:${minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isCurrentMinute
                                  ? const Color(0xFF374151)
                                  : Colors.grey[600],
                              fontWeight: isCurrentMinute
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),

                    // Línea divisoria
                    Container(width: 1, height: 30, color: Colors.grey[200]),

                    // Área de tareas del minuto
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showAddTaskForMinute(
                              context, provider, hour, minute),
                          borderRadius: BorderRadius.circular(2),
                          splashColor:
                              const Color(0xFF374151).withOpacity(0.05),
                          highlightColor:
                              const Color(0xFF374151).withOpacity(0.02),
                          overlayColor:
                              MaterialStateProperty.resolveWith<Color?>(
                            (states) {
                              if (states.contains(MaterialState.pressed)) {
                                return const Color(0xFF374151)
                                    .withOpacity(0.03);
                              }
                              if (states.contains(MaterialState.hovered)) {
                                return const Color(0xFF374151)
                                    .withOpacity(0.015);
                              }
                              return null;
                            },
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(left: 18, right: 4),
                            child: Row(
                              children: [
                                if (minuteTasks.isNotEmpty)
                                  Expanded(
                                      child: _buildTasksForMinute(minuteTasks)),
                                if (minuteTasks.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 10,
                                          color: isCurrentMinute
                                              ? const Color(0xFF374151)
                                                  .withOpacity(0.6)
                                              : Colors.grey[400],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Agregar tarea',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: isCurrentMinute
                                                ? const Color(0xFF374151)
                                                    .withOpacity(0.6)
                                                : Colors.grey[400],
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<PendingTask> _getTasksForMinute(
      List<PendingTask> tasks, int hour, int minute) {
    return tasks.where((task) {
      return task.dateTime.hour == hour && task.dateTime.minute == minute;
    }).toList();
  }

  bool _isCurrentMinute(int hour, int minute) {
    if (!_isToday()) return false;
    final now = DateTime.now();
    return now.hour == hour && now.minute == minute;
  }

  void _showAddTaskForMinute(
      BuildContext context, PendingProvider provider, int hour, int minute) {
    _showAddTaskDialog(context, provider, hour: hour, minute: minute);
  }

  Widget _buildTasksForMinute(List<PendingTask> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: tasks
          .map((task) => Container(
                margin: const EdgeInsets.symmetric(vertical: 0.5),
                child: _buildTaskInMinute(task),
              ))
          .toList(),
    );
  }

  Widget _buildTaskInMinute(PendingTask task) {
    return Text(
      task.title,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 7,
        color: task.completed ? Colors.grey[400] : task.color,
        fontWeight: task.completed ? FontWeight.w400 : FontWeight.w500,
        decoration:
            task.completed ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: Colors.grey[400],
        decorationThickness: 0.8,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  List<TaskRangeInfo> _getTimeRangeInfoForMinute(
      List<PendingTask> tasks, int hour, int minute) {
    List<TaskRangeInfo> rangeInfos = [];

    for (var task in tasks) {
      final DateTime taskEnd =
          task.endDateTime ?? task.dateTime.add(const Duration(hours: 1));
      if (taskEnd.isAfter(task.dateTime) && task.occursInHour(hour)) {
        final current = DateTime(2025, 1, 1, hour, minute);
        final start =
            DateTime(2025, 1, 1, task.dateTime.hour, task.dateTime.minute);
        final end = DateTime(2025, 1, 1, taskEnd.hour, taskEnd.minute);

        if (current.isAtSameMomentAs(start) ||
            current.isAtSameMomentAs(end) ||
            (current.isAfter(start) && current.isBefore(end))) {
          final isStart = current.isAtSameMomentAs(start);
          final isEnd = current.isAtSameMomentAs(end);
          final isMiddle = !isStart && !isEnd;

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

  Widget _buildTimeRangeIndicators(
      List<TaskRangeInfo> rangeInfos, double leftColumnWidth) {
    final leftOffset = leftColumnWidth + 1 + 6;

    return Positioned(
      left: leftOffset,
      top: 2,
      bottom: 2,
      child: SizedBox(
        width: 12,
        child: Stack(
          children: rangeInfos.asMap().entries.map((entry) {
            int index = entry.key;
            TaskRangeInfo info = entry.value;

            return Positioned(
              left: index * 2.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2.5,
                decoration: BoxDecoration(
                  color: info.task.completed
                      ? info.task.color.withOpacity(0.3)
                      : info.task.color,
                  borderRadius: BorderRadius.circular(1.25),
                  boxShadow: [
                    BoxShadow(
                      color: info.task.completed
                          ? info.task.color.withOpacity(0.1)
                          : info.task.color.withOpacity(0.3),
                      blurRadius: 2,
                      offset: const Offset(0.5, 0),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (info.isStart)
                      Positioned(
                        top: -2,
                        left: -2,
                        right: -2,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: info.task.completed
                                ? info.task.color.withOpacity(0.4)
                                : info.task.color,
                            borderRadius: BorderRadius.circular(3.5),
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: info.task.completed
                                    ? info.task.color.withOpacity(0.2)
                                    : info.task.color.withOpacity(0.7),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (info.isEnd)
                      Positioned(
                        bottom: -2,
                        left: -2,
                        right: -2,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: info.task.completed
                                ? info.task.color.withOpacity(0.4)
                                : info.task.color,
                            borderRadius: BorderRadius.circular(3.5),
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: info.task.completed
                                    ? info.task.color.withOpacity(0.2)
                                    : info.task.color.withOpacity(0.7),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (info.isMiddle)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: info.task.completed
                              ? info.task.color.withOpacity(0.25)
                              : info.task.color.withOpacity(0.9),
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

  // Botón para agregar tarea
  Widget _buildAddTaskButton(
      int hour, bool isCurrentHour, PendingProvider provider) {
    return GestureDetector(
      onTap: () => _showAddTaskForHour(context, provider, hour),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrentHour
                ? const Color(0xFF374151).withOpacity(0.4)
                : Colors.grey[300]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
          color: isCurrentHour
              ? const Color(0xFF374151).withOpacity(0.02)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: isCurrentHour
                  ? const Color(0xFF374151).withOpacity(0.7)
                  : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Agregar tarea',
              style: TextStyle(
                color: isCurrentHour
                    ? const Color(0xFF374151).withOpacity(0.7)
                    : Colors.grey[500],
                fontSize: 13,
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
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: task.completed ? Colors.grey[300] : task.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: task.completed
                      ? Colors.grey[400]!.withOpacity(0.3)
                      : task.color.withOpacity(0.8),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: Hora y título
                  Row(
                    children: [
                      // Indicador de tiempo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getTimeRangeForTask(task, hour),
                          style: TextStyle(
                            color: task.completed
                                ? Colors.grey[600]
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Contenido de la tarea
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                color: task.completed
                                    ? Colors.grey[600]
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 1.3,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
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
                                      : Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Fila inferior: Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildVisibleEditButton(task),
                      _buildVisibleNotebookButton(task),
                      _buildVisibleAlarmButton(task),
                      _buildVisibleNotificationButton(task),
                      _buildVisibleDeleteButton(task),
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
    final end = task.endDateTime ?? task.dateTime.add(const Duration(hours: 1));

    if (task.dateTime.hour == hour && end.hour == hour) {
      return '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}-${_formatTime12Hour(end.hour, end.minute)}';
    } else if (task.dateTime.hour == hour) {
      if (end.hour > hour + 1) {
        return '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}-${_formatTime12Hour(hour + 1, 0)}';
      } else {
        return '${_formatTime12Hour(task.dateTime.hour, task.dateTime.minute)}-${_formatTime12Hour(end.hour, end.minute)}';
      }
    } else if (end.hour == hour + 1 && end.minute > 0) {
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(end.hour, end.minute)}';
    } else if (end.hour == hour) {
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(end.hour, end.minute)}';
    } else if (end.hour > hour) {
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(hour + 1, 0)}';
    } else {
      return '${_formatTime12Hour(hour, 0)}-${_formatTime12Hour(end.hour, end.minute)}';
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

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showAddTaskForHour(
      BuildContext context, PendingProvider provider, int hour) {
    _showAddTaskDialog(context, provider, hour: hour);
  }

  void _showAddTaskDialog(BuildContext context, PendingProvider provider,
      {int? hour, int? minute}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: AddTaskHourlyForm(
          pendingProvider: provider,
          selectedDate: widget.selectedDate,
          selectedHour: hour,
          selectedMinute: minute,
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, PendingTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: EditTaskHourlyForm(
          task: task,
          pendingProvider: context.read<PendingProvider>(),
          selectedDate: widget.selectedDate,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, PendingTask task) {
    final provider = context.read<PendingProvider>();
    final relatedTasks = provider.getRelatedTasks(task);

    final hasRelatedTasks = relatedTasks.isNotEmpty;
    final relatedTasksCount = relatedTasks.length;

    showDialog(
      context: context,
      builder: (context) => _DeleteTaskDialog(
        task: task,
        hasRelatedTasks: hasRelatedTasks,
        relatedTasksCount: relatedTasksCount,
        onDeleteSingle: () {
          Navigator.of(context).pop();
          provider.deleteSingleTask(task.id);
        },
        onDeleteAll: () {
          Navigator.of(context).pop();
          provider.deleteAllRelatedTasks(task);
        },
      ),
    );
  }

  String _formatDateSpanish(DateTime date) {
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

    return '${dayName[0].toUpperCase()}${dayName.substring(1)}, ${date.day} de $monthName';
  }

  // ========= Botones de acción visibles =========

  Widget _buildVisibleEditButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final iconColor = bgLuminance > 0.5 ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: () => _showEditTaskDialog(context, task),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(Icons.edit_outlined, color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildVisibleNotebookButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final iconColor = bgLuminance > 0.5 ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: () => showNotebook(
        context,
        taskId: task.id,
        taskTitle: task.title,
        taskDescription: task.description,
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Text('📔', style: TextStyle(fontSize: 22, color: iconColor)),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(Icons.delete_outline, color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildVisibleAlarmButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final iconColor = bgLuminance > 0.5
        ? (task.hasAlarm ? const Color(0xFFB8860B) : Colors.grey[600]!)
        : (task.hasAlarm ? const Color(0xFFFFD700) : Colors.grey[400]!);

    return GestureDetector(
      onTap: () => _showAlarmDialog(context, task),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(task.hasAlarm ? Icons.alarm_on : Icons.alarm_off,
              color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildVisibleNotificationButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final iconColor = bgLuminance > 0.5
        ? (task.hasNotification ? const Color(0xFF1E40AF) : Colors.grey[600]!)
        : (task.hasNotification ? const Color(0xFF60A5FA) : Colors.grey[400]!);

    return GestureDetector(
      onTap: () => _showNotificationDialog(context, task),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(
            task.hasNotification
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: iconColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibleCompleteButton(PendingTask task) {
    final bgLuminance = task.color.computeLuminance();
    final checkColor = task.completed
        ? Colors.green[400]!
        : (bgLuminance > 0.5 ? Colors.black54 : Colors.white70);

    return GestureDetector(
      onTap: () {
        final provider = context.read<PendingProvider>();
        provider.toggleTaskCompletion(task.id);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: checkColor.withOpacity(0.15),
          border: Border.all(color: checkColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(
            task.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: checkColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ------- Diálogo de ALARMA (sonido fuerte) -------
  void _showAlarmDialog(BuildContext context, PendingTask task) {
    final provider = context.read<PendingProvider>();
    bool hasAlarm = task.hasAlarm;
    int? before = task.alarmMinutesBefore;
    int? after = task.alarmMinutesAfter;
    bool applyToAll = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBS) {
            // Verificar si la tarea tiene relacionadas
            final relatedTasks = provider.getRelatedTasks(task);
            final hasRelatedTasks = relatedTasks.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Alarma (sonido fuerte)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: hasAlarm,
                    onChanged: (v) => setBS(() => hasAlarm = v),
                    title: const Text('Activar alarma'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasAlarm) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('En el momento',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _buildAlarmOption(
                        'Exactamente a la hora', 0, before, (v) => setBS(() => before = v)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Antes de la hora',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _buildAlarmOption(
                        '5 min', 5, before, (v) => setBS(() => before = v)),
                    _buildAlarmOption(
                        '10 min', 10, before, (v) => setBS(() => before = v)),
                    _buildAlarmOption(
                        '15 min', 15, before, (v) => setBS(() => before = v)),
                    _buildAlarmOption(
                        '30 min', 30, before, (v) => setBS(() => before = v)),
                    _buildAlarmOption(
                        '1 hora', 60, before, (v) => setBS(() => before = v)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Después de la hora',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _buildAlarmOption(
                        '5 min', 5, after, (v) => setBS(() => after = v)),
                    _buildAlarmOption(
                        '10 min', 10, after, (v) => setBS(() => after = v)),
                    _buildAlarmOption(
                        '15 min', 15, after, (v) => setBS(() => after = v)),
                  ],
                  if (hasRelatedTasks) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text('Esta tarea se repite en otros días',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: false,
                                  groupValue: applyToAll,
                                  onChanged: (v) => setBS(() => applyToAll = v!),
                                  title: const Text('Solo este día', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: true,
                                  groupValue: applyToAll,
                                  onChanged: (v) => setBS(() => applyToAll = v!),
                                  title: const Text('Todos los días', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (applyToAll && hasRelatedTasks) {
                              // Aplicar a todas las tareas relacionadas
                              final updatedTask = PendingTask(
                                id: task.id,
                                title: task.title,
                                description: task.description,
                                categoria: task.categoria,
                                dateTime: task.dateTime,
                                endDateTime: task.endDateTime,
                                completed: task.completed,
                                colorHex: task.colorHex,
                                isAllDay: task.isAllDay,
                                repeatType: task.repeatType,
                                customDays: task.customDays,
                                hasAlarm: hasAlarm,
                                alarmMinutesBefore: hasAlarm ? before : null,
                                alarmMinutesAfter: hasAlarm ? after : null,
                                hasNotification: task.hasNotification,
                                notificationMinutesBefore: task.notificationMinutesBefore,
                                notificationMinutesAfter: task.notificationMinutesAfter,
                              );
                              
                              provider.updateAllRelatedTasksFromOriginal(
                                originalTask: task,
                                updatedTask: updatedTask,
                              );
                              
                              // Programar alarmas para todas las tareas relacionadas
                              try {
                                for (final relatedTask in [...relatedTasks, task]) {
                                  if (hasAlarm) {
                                    await NotificationService.scheduleTaskAlarm(
                                      taskId: relatedTask.id,
                                      taskTitle: relatedTask.title,
                                      taskDateTime: relatedTask.dateTime,
                                      minutesBefore: before,
                                      minutesAfter: after,
                                    );
                                  } else {
                                    await NotificationService.cancelTaskAlarm(relatedTask.id);
                                  }
                                }
                              } catch (e) {
                                debugPrint('Alarm error: $e');
                              }
                            } else {
                              // Aplicar solo a esta tarea
                              provider.updateTaskInPlace(
                                task.id,
                                hasAlarm: hasAlarm,
                                alarmMinutesBefore: hasAlarm ? before : null,
                                alarmMinutesAfter: hasAlarm ? after : null,
                              );

                              try {
                                if (hasAlarm) {
                                  await NotificationService.scheduleTaskAlarm(
                                    taskId: task.id,
                                    taskTitle: task.title,
                                    taskDateTime: task.dateTime,
                                    minutesBefore: before,
                                    minutesAfter: after,
                                  );
                                } else {
                                  await NotificationService.cancelTaskAlarm(task.id);
                                }
                              } catch (e) {
                                debugPrint('Alarm error: $e');
                              }
                            }

                            if (mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ------- Diálogo de NOTIFICACIÓN (silenciosa) -------
  void _showNotificationDialog(BuildContext context, PendingTask task) {
    final provider = context.read<PendingProvider>();
    bool hasNotif = task.hasNotification;
    int? before = task.notificationMinutesBefore;
    int? after = task.notificationMinutesAfter;
    bool applyToAll = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBS) {
            // Verificar si la tarea tiene relacionadas
            final relatedTasks = provider.getRelatedTasks(task);
            final hasRelatedTasks = relatedTasks.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notificación (silenciosa)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: hasNotif,
                    onChanged: (v) => setBS(() => hasNotif = v),
                    title: const Text('Activar notificación'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasNotif) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('En el momento',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _buildNotificationOption(
                        'Exactamente a la hora', 0, before, (v) => setBS(() => before = v)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Antes de la hora',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _buildNotificationOption(
                        '5 min', 5, before, (v) => setBS(() => before = v)),
                    _buildNotificationOption(
                        '10 min', 10, before, (v) => setBS(() => before = v)),
                    _buildNotificationOption(
                        '15 min', 15, before, (v) => setBS(() => before = v)),
                    _buildNotificationOption(
                        '30 min', 30, before, (v) => setBS(() => before = v)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Después de la hora',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    _buildNotificationOption(
                        '5 min', 5, after, (v) => setBS(() => after = v)),
                    _buildNotificationOption(
                        '10 min', 10, after, (v) => setBS(() => after = v)),
                  ],
                  if (hasRelatedTasks) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text('Esta tarea se repite en otros días',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: false,
                                  groupValue: applyToAll,
                                  onChanged: (v) => setBS(() => applyToAll = v!),
                                  title: const Text('Solo este día', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: true,
                                  groupValue: applyToAll,
                                  onChanged: (v) => setBS(() => applyToAll = v!),
                                  title: const Text('Todos los días', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (applyToAll && hasRelatedTasks) {
                              // Aplicar a todas las tareas relacionadas
                              final updatedTask = PendingTask(
                                id: task.id,
                                title: task.title,
                                description: task.description,
                                categoria: task.categoria,
                                dateTime: task.dateTime,
                                endDateTime: task.endDateTime,
                                completed: task.completed,
                                colorHex: task.colorHex,
                                isAllDay: task.isAllDay,
                                repeatType: task.repeatType,
                                customDays: task.customDays,
                                hasAlarm: task.hasAlarm,
                                alarmMinutesBefore: task.alarmMinutesBefore,
                                alarmMinutesAfter: task.alarmMinutesAfter,
                                hasNotification: hasNotif,
                                notificationMinutesBefore: hasNotif ? before : null,
                                notificationMinutesAfter: hasNotif ? after : null,
                              );
                              
                              provider.updateAllRelatedTasksFromOriginal(
                                originalTask: task,
                                updatedTask: updatedTask,
                              );
                              
                              // Programar notificaciones para todas las tareas relacionadas
                              try {
                                for (final relatedTask in [...relatedTasks, task]) {
                                  if (hasNotif) {
                                    await NotificationService.scheduleTaskNotification(
                                      taskId: relatedTask.id,
                                      taskTitle: relatedTask.title,
                                      taskDateTime: relatedTask.dateTime,
                                      minutesBefore: before,
                                      minutesAfter: after,
                                    );
                                  } else {
                                    await NotificationService.cancelTaskNotification(relatedTask.id);
                                  }
                                }
                              } catch (e) {
                                debugPrint('Notification error: $e');
                              }
                            } else {
                              // Aplicar solo a esta tarea
                              provider.updateTaskInPlace(
                                task.id,
                                hasNotification: hasNotif,
                                notificationMinutesBefore: hasNotif ? before : null,
                                notificationMinutesAfter: hasNotif ? after : null,
                              );

                              try {
                                if (hasNotif) {
                                  await NotificationService.scheduleTaskNotification(
                                    taskId: task.id,
                                    taskTitle: task.title,
                                    taskDateTime: task.dateTime,
                                    minutesBefore: before,
                                    minutesAfter: after,
                                  );
                                } else {
                                  await NotificationService.cancelTaskNotification(task.id);
                                }
                              } catch (e) {
                                debugPrint('Notification error: $e');
                              }
                            }

                            if (mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ======= Widgets auxiliares para opciones (globales para reutilizar) =======
Widget _buildAlarmOption(
    String label, int minutes, int? selectedMinutes, Function(int) onSelected) {
  final isSelected = selectedMinutes == minutes;

  return GestureDetector(
    onTap: () => onSelected(minutes),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF374151).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF374151)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? const Color(0xFF374151) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF374151) : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildNotificationOption(
    String label, int minutes, int? selectedMinutes, Function(int) onSelected) {
  final isSelected = selectedMinutes == minutes;

  return GestureDetector(
    onTap: () => onSelected(minutes),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E40AF).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF1E40AF)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? const Color(0xFF1E40AF) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF1E40AF) : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Diálogo personalizado para eliminación de tareas con opciones inteligentes
class _DeleteTaskDialog extends StatefulWidget {
  final PendingTask task;
  final bool hasRelatedTasks;
  final int relatedTasksCount;
  final VoidCallback onDeleteSingle;
  final VoidCallback onDeleteAll;

  const _DeleteTaskDialog({
    required this.task,
    required this.hasRelatedTasks,
    required this.relatedTasksCount,
    required this.onDeleteSingle,
    required this.onDeleteAll,
  });

  @override
  State<_DeleteTaskDialog> createState() => _DeleteTaskDialogState();
}

class _DeleteTaskDialogState extends State<_DeleteTaskDialog> {
  String _selectedOption = 'single'; // 'single' o 'all'

  @override
  Widget build(BuildContext context) {
    final currentDate = DateFormat('d MMM').format(widget.task.dateTime);

    return AlertDialog(
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
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),

          if (widget.hasRelatedTasks) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta tarea se repite en ${widget.relatedTasksCount} días más',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Info tarea
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
                  widget.task.title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (widget.task.description.isNotEmpty)
                  Text(
                    widget.task.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTime12Hour(widget.task.dateTime.hour, widget.task.dateTime.minute)}'
                  '${widget.task.endDateTime != null ? ' - ${_formatTime12Hour(widget.task.endDateTime!.hour, widget.task.endDateTime!.minute)}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          if (widget.hasRelatedTasks) ...[
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'single',
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
              title: Text('Solo eliminar este día ($currentDate)',
                  style: const TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              value: 'all',
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
              title: const Text('Eliminar en todos los días asignados',
                  style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF374151))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            if (widget.hasRelatedTasks && _selectedOption == 'all') {
              widget.onDeleteAll();
            } else {
              widget.onDeleteSingle();
            }
          },
          child: const Text('Eliminar'),
        ),
      ],
    );
  }

  String _formatTime12Hour(int hour, int minute) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat.jm().format(dateTime);
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
  bool _isAllDay = false;
  String _repeatType = 'none';
  List<int> _customDays = [];
  String _selectedColorHex = TaskColors.pastelColors[0]; // Color por defecto

  static bool _lastEndTimePreference = false; // recordar preferencia

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.selectedHour ?? DateTime.now().hour;
    _selectedMinute = widget.selectedMinute ?? 0;
    _hasEndTime = _lastEndTimePreference;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva Tarea',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A59),
                  )),
              const SizedBox(height: 16),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Selector de color
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Color',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  SizedBox(
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
                          onTap: () =>
                              setState(() => _selectedColorHex = colorHex),
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
                        color: Color(0xFF374151), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy')
                          .format(widget.selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildTimePicker(
                  'Hora de inicio',
                  _selectedHour,
                  _selectedMinute,
                  (hour, minute) => setState(() {
                        _selectedHour = hour;
                        _selectedMinute = minute;
                      })),

              Row(
                children: [
                  Checkbox(
                    value: _hasEndTime,
                    onChanged: _isAllDay
                        ? null
                        : (value) {
                            setState(() {
                              _hasEndTime = value ?? false;
                              _lastEndTimePreference = _hasEndTime;
                              if (_hasEndTime && _endHour == null) {
                                _endHour = _selectedHour + 1;
                                _endMinute = _selectedMinute;
                              }
                            });
                          },
                  ),
                  Text('Agregar hora final',
                      style: TextStyle(
                          color: _isAllDay ? Colors.grey : Colors.black)),
                ],
              ),

              if (_hasEndTime)
                _buildTimePicker(
                    'Hora final',
                    _endHour!,
                    _endMinute!,
                    (hour, minute) => setState(() {
                          _endHour = hour;
                          _endMinute = minute;
                        })),

              Row(
                children: [
                  Checkbox(
                    value: _isAllDay,
                    onChanged: (value) {
                      setState(() {
                        _isAllDay = value ?? false;
                        if (_isAllDay) {
                          _hasEndTime = false;
                        }
                      });
                    },
                  ),
                  const Text('Todo el día'),
                ],
              ),

              const SizedBox(height: 16),
              _RepeatSection(
                repeatType: _repeatType,
                customDays: _customDays,
                onRepeatTypeChanged: (val) => setState(() => _repeatType = val),
                onEditCustomDays: () => _showCustomDaysDialog(),
              ),

              const SizedBox(height: 20),
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
                          foregroundColor: Colors.white),
                      onPressed: _addTask,
                      child: const Text('Agregar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                color: const Color(0xFF374151).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatTime(hour, minute),
                style: const TextStyle(
                    color: Color(0xFF374151), fontWeight: FontWeight.w600),
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
                child: const Text('Cancelar')),
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
    if (_titleController.text.isEmpty) return;

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

      if (!endDateTime.isAfter(taskDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La hora de finalización debe ser posterior a la hora de inicio'),
            backgroundColor: Colors.red,
          ),
        );
        return;
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
      isAllDay: _isAllDay,
      repeatType: _repeatType != 'none' ? _repeatType : null,
      customDays: _repeatType == 'custom' ? _customDays : null,
    );

    widget.pendingProvider.addTask(task);
    Navigator.of(context).pop();
  }
}

/// Formulario para editar tareas existentes (con “aplicar a todas”)
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
  bool _isAllDay = false;
  String _repeatType = 'none';
  List<int> _customDays = [];
  bool _applyToAllRelated = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.task.title;
    _descriptionController.text = widget.task.description;
    _selectedHour = widget.task.dateTime.hour;
    _selectedMinute = widget.task.dateTime.minute;
    _selectedColorHex = widget.task.colorHex;

    _isAllDay = widget.task.isAllDay;
    _repeatType = widget.task.repeatType ?? 'none';
    _customDays = widget.task.customDays ?? [];

    if (widget.task.endDateTime != null) {
      _hasEndTime = true;
      _endHour = widget.task.endDateTime!.hour;
      _endMinute = widget.task.endDateTime!.minute;
    }

    final hasRelated =
        widget.pendingProvider.getRelatedTasks(widget.task).isNotEmpty;
    _applyToAllRelated = hasRelated;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editar Tarea',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A59),
                  )),
              const SizedBox(height: 16),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Color
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Color',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  SizedBox(
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
                          onTap: () =>
                              setState(() => _selectedColorHex = colorHex),
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

              // Fecha (informativa)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Color(0xFF374151), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy')
                          .format(widget.selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildTimePicker(
                  'Hora de inicio',
                  _selectedHour,
                  _selectedMinute,
                  (hour, minute) => setState(() {
                        _selectedHour = hour;
                        _selectedMinute = minute;
                      })),

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

              if (_hasEndTime)
                _buildTimePicker(
                    'Hora final',
                    _endHour!,
                    _endMinute!,
                    (hour, minute) => setState(() {
                          _endHour = hour;
                          _endMinute = minute;
                        })),

              const SizedBox(height: 16),

              // Repetición + Todo el día
              CheckboxListTile(
                title: const Text('Todo el día'),
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value ?? false;
                    if (_isAllDay) {
                      _hasEndTime = false;
                      _endHour = null;
                      _endMinute = null;
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              _RepeatSection(
                repeatType: _repeatType,
                customDays: _customDays,
                onRepeatTypeChanged: (val) => setState(() => _repeatType = val),
                onEditCustomDays: () => _showCustomDaysDialogEdit(),
              ),

              // Aplicar a todas
              if (widget.pendingProvider
                  .getRelatedTasks(widget.task)
                  .isNotEmpty)
                SwitchListTile(
                  title: const Text(
                      'Aplicar cambios a todas las tareas relacionadas'),
                  value: _applyToAllRelated,
                  onChanged: (v) => setState(() => _applyToAllRelated = v),
                  dense: true,
                ),

              const SizedBox(height: 20),
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
                          foregroundColor: Colors.white),
                      onPressed: _saveTask,
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DUPLICADO LOCAL: para evitar el error de método no definido ---
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
                color: const Color(0xFF374151).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatTime(hour, minute),
                style: const TextStyle(
                    color: Color(0xFF374151), fontWeight: FontWeight.w600),
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

  void _showCustomDaysDialogEdit() async {
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
                child: const Text('Cancelar')),
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

  void _saveTask() {
    if (_titleController.text.isEmpty) return;

    final newStart = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedHour,
      _selectedMinute,
    );

    DateTime? newEnd;
    if (_hasEndTime && _endHour != null && _endMinute != null) {
      newEnd = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _endHour!,
        _endMinute!,
      );
      if (!newEnd.isAfter(newStart)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La hora de finalización debe ser posterior a la hora de inicio'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final updated = PendingTask(
      id: widget.task.id,
      title: _titleController.text,
      description: _descriptionController.text,
      categoria: widget.task.categoria,
      dateTime: newStart,
      endDateTime: newEnd,
      completed: widget.task.completed,
      colorHex: _selectedColorHex,
      isAllDay: _isAllDay,
      repeatType: _repeatType != 'none' ? _repeatType : null,
      customDays: _repeatType == 'custom' ? _customDays : null,
      hasAlarm: widget.task.hasAlarm,
      alarmMinutesBefore: widget.task.alarmMinutesBefore,
      alarmMinutesAfter: widget.task.alarmMinutesAfter,
      hasNotification: widget.task.hasNotification,
      notificationMinutesBefore: widget.task.notificationMinutesBefore,
      notificationMinutesAfter: widget.task.notificationMinutesAfter,
    );

    if (_applyToAllRelated) {
      // ✅ NUEVO: usa la ORIGINAL para localizar el grupo y aplica UPDATED a todas
      widget.pendingProvider.updateAllRelatedTasksFromOriginal(
        originalTask: widget.task,
        updatedTask: updated,
      );
    } else {
      widget.pendingProvider.updateTask(updated);
    }

    Navigator.of(context).pop();
  }
}

/// Sección de repetición reusada (Add/Edit)
class _RepeatSection extends StatelessWidget {
  final String repeatType;
  final List<int> customDays;
  final ValueChanged<String> onRepeatTypeChanged;
  final VoidCallback onEditCustomDays;

  const _RepeatSection({
    required this.repeatType,
    required this.customDays,
    required this.onRepeatTypeChanged,
    required this.onEditCustomDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.repeat, color: Color(0xFF374151), size: 20),
              SizedBox(width: 8),
              Text(
                'Repetir tarea',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: repeatType,
            decoration: const InputDecoration(
              labelText: 'Frecuencia',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('No repetir')),
              DropdownMenuItem(value: 'daily', child: Text('Diario')),
              DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
              DropdownMenuItem(value: 'saturday', child: Text('Los sábados')),
              DropdownMenuItem(value: 'sunday', child: Text('Los domingos')),
              DropdownMenuItem(
                  value: 'weekdays', child: Text('De lunes a viernes')),
              DropdownMenuItem(value: 'yearly', child: Text('Anualmente')),
              DropdownMenuItem(
                  value: 'custom', child: Text('Días específicos')),
            ],
            onChanged: (value) {
              if (value == null) return;
              onRepeatTypeChanged(value);
            },
          ),
          if (repeatType == 'custom') ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onEditCustomDays,
              icon: const Icon(Icons.event, size: 16),
              label: Text(customDays.isEmpty
                  ? 'Seleccionar días'
                  : '${customDays.length} días seleccionados'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF374151),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
