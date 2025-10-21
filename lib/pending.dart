import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Modelo de tarea pendiente
class PendingTask {
  String id;
  String title;
  String description;
  String categoria;
  DateTime dateTime;
  DateTime? endDateTime; // Hora de finalización opcional
  bool completed;
  String colorHex; // Color de la tarea en formato hexadecimal
  bool isAllDay; // Tarea de todo el día
  String?
      repeatType; // Tipo de repetición: daily, weekly, saturday, sunday, weekdays, yearly, custom
  List<int>? customDays; // Días personalizados (1=Lunes, 7=Domingo)
  bool isAutoEndTime; // Si la hora final fue asignada automáticamente

  // Propiedades de alarma (sonido fuerte)
  bool hasAlarm;
  int? alarmMinutesBefore;
  int? alarmMinutesAfter;

  // Propiedades de notificación (silenciosa)
  bool hasNotification;
  int? notificationMinutesBefore;
  int? notificationMinutesAfter;

  PendingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.categoria,
    required this.dateTime,
    this.endDateTime,
    this.completed = false,
    this.colorHex = '#FEF7F0',
    this.isAllDay = false,
    this.repeatType,
    this.customDays = const [],
    this.isAutoEndTime = false,
    this.hasAlarm = false,
    this.alarmMinutesBefore,
    this.alarmMinutesAfter,
    this.hasNotification = false,
    this.notificationMinutesBefore,
    this.notificationMinutesAfter,
  });

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categoria': categoria,
      'dateTime': dateTime.toIso8601String(),
      'endDateTime': endDateTime?.toIso8601String(),
      'completed': completed,
      'colorHex': colorHex,
      'isAllDay': isAllDay,
      'repeatType': repeatType,
      'customDays': customDays ?? [],
      'isAutoEndTime': isAutoEndTime,
      // Propiedades de alarma (sonido fuerte)
      'hasAlarm': hasAlarm,
      'alarmMinutesBefore': alarmMinutesBefore,
      'alarmMinutesAfter': alarmMinutesAfter,
      // Propiedades de notificación (silenciosa)
      'hasNotification': hasNotification,
      'notificationMinutesBefore': notificationMinutesBefore,
      'notificationMinutesAfter': notificationMinutesAfter,
    };
  }

  /// Crea desde JSON
  factory PendingTask.fromJson(Map<String, dynamic> json) {
    return PendingTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      categoria: json['categoria'] ?? '',
      dateTime: DateTime.parse(json['dateTime']),
      endDateTime: json['endDateTime'] != null
          ? DateTime.parse(json['endDateTime'])
          : null,
      completed: json['completed'] ?? false,
      colorHex: json['colorHex'] ?? '#FEF7F0',
      isAllDay: json['isAllDay'] ?? false,
      repeatType: json['repeatType'],
      customDays:
          json['customDays'] != null ? List<int>.from(json['customDays']) : [],
      isAutoEndTime: json['isAutoEndTime'] ?? false,
      // Propiedades de alarma (sonido fuerte)
      hasAlarm: json['hasAlarm'] ?? false,
      alarmMinutesBefore: json['alarmMinutesBefore'],
      alarmMinutesAfter: json['alarmMinutesAfter'],
      // Propiedades de notificación (silenciosa)
      hasNotification: json['hasNotification'] ?? false,
      notificationMinutesBefore: json['notificationMinutesBefore'],
      notificationMinutesAfter: json['notificationMinutesAfter'],
    );
  }

  /// Duración de la tarea en minutos
  int get durationInMinutes {
    if (endDateTime == null) return 60; // Duración por defecto de 1 hora
    return endDateTime!.difference(dateTime).inMinutes;
  }

  /// Verifica si la tarea ocurre en una hora específica (considerando minutos)
  bool occursInHour(int hour) {
    final hourStart =
        DateTime(dateTime.year, dateTime.month, dateTime.day, hour);
    final hourEnd = hourStart.add(const Duration(hours: 1));

    final taskStart = dateTime;
    final taskEnd = endDateTime ?? dateTime.add(const Duration(hours: 1));

    final overlaps = taskStart.isBefore(hourEnd) && taskEnd.isAfter(hourStart);
    return overlaps;
  }

  /// Obtiene la porción de la tarea que ocurre en una hora específica (0.0 a 1.0)
  double getPortionInHour(int hour) {
    final hourStart =
        DateTime(dateTime.year, dateTime.month, dateTime.day, hour);
    final hourEnd = hourStart.add(const Duration(hours: 1));

    final taskStart = dateTime;
    final taskEnd = endDateTime ?? dateTime.add(const Duration(hours: 1));

    final start = taskStart.isAfter(hourStart) ? taskStart : hourStart;
    final end = taskEnd.isBefore(hourEnd) ? taskEnd : hourEnd;

    if (!start.isBefore(end)) return 0.0;

    final overlapMinutes = end.difference(start).inMinutes;
    return (overlapMinutes / 60.0).clamp(0.0, 1.0);
  }

  /// Obtiene el color de la tarea como objeto Color de Flutter
  Color get color => TaskColors.hexToColor(colorHex);
}

/// Provider para gestionar tareas de la agenda
class PendingProvider extends ChangeNotifier {
  List<PendingTask> tasks = [];

  PendingProvider() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('pending_tasks') ?? '[]';
    final List list = json.decode(data) as List;
    tasks = list
        .map((e) => PendingTask.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pending_tasks',
      json.encode(tasks.map((e) => e.toJson()).toList()),
    );
  }

  void addTask(PendingTask task) {
    tasks.add(task);

    if (task.repeatType != null && task.repeatType != 'none') {
      _generateRepeatedTasks(task);
    }

    _saveTasks();
    notifyListeners();
  }

  void completeTask(String id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      tasks[idx].completed = true;
      _saveTasks();
      notifyListeners();
    }
  }

  void toggleTaskCompletion(String id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      tasks[idx].completed = !tasks[idx].completed;
      _saveTasks();
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _saveTasks();
    notifyListeners();
  }

  /// Encuentra todas las tareas relacionadas (repetidas) de una tarea específica
  List<PendingTask> getRelatedTasks(PendingTask task) {
    final List<PendingTask> relatedTasks = [];

    String normalizeDesc(String d) => d.trim();

    final baseTitle = task.title.trim();
    final baseDescription = normalizeDesc(task.description);

    for (final t in tasks) {
      if (t.id == task.id) continue;

      final tTitle = t.title.trim();
      final tDesc = normalizeDesc(t.description);

      if (tTitle == baseTitle && tDesc == baseDescription) {
        relatedTasks.add(t);
      }
    }

    // Fallback: si no encontró por título+descripción, usar coincidencia por hora/minuto del task original
    if (relatedTasks.isEmpty) {
      for (final t in tasks) {
        if (t.id == task.id) continue;

        if (t.dateTime.hour == task.dateTime.hour &&
            t.dateTime.minute == task.dateTime.minute) {
          relatedTasks.add(t);
        }
      }
    }

    return relatedTasks;
  }

  void deleteSingleTask(String id) {
    deleteTask(id);
  }

  void deleteAllRelatedTasks(PendingTask mainTask) {
    final relatedTasks = getRelatedTasks(mainTask);
    final allTaskIds = [mainTask.id] + relatedTasks.map((t) => t.id).toList();

    tasks.removeWhere((t) => allTaskIds.contains(t.id));
    _saveTasks();
    notifyListeners();
  }

  void updateTask(PendingTask updatedTask) {
    final idx = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (idx != -1) {
      tasks[idx] = updatedTask;
      _saveTasks();
      notifyListeners();
    }
  }

  void updateTaskInPlace(
    String taskId, {
    String? title,
    String? description,
    String? categoria,
    DateTime? dateTime,
    DateTime? endDateTime,
    bool? completed,
    String? colorHex,
    bool? isAllDay,
    String? repeatType,
    List<int>? customDays,
    bool? hasAlarm,
    int? alarmMinutesBefore,
    int? alarmMinutesAfter,
    bool? hasNotification,
    int? notificationMinutesBefore,
    int? notificationMinutesAfter,
    bool suppressNotification = false, // Nuevo parámetro para optimización
  }) {
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = tasks[idx];

      if (title != null) task.title = title;
      if (description != null) task.description = description;
      if (categoria != null) task.categoria = categoria;
      if (dateTime != null) task.dateTime = dateTime;
      if (endDateTime != null ||
          (endDateTime == null && task.endDateTime != null)) {
        task.endDateTime = endDateTime;
      }
      if (completed != null) task.completed = completed;
      if (colorHex != null) task.colorHex = colorHex;
      if (isAllDay != null) task.isAllDay = isAllDay;
      if (repeatType != null) task.repeatType = repeatType;
      if (customDays != null) task.customDays = customDays;
      if (hasAlarm != null) task.hasAlarm = hasAlarm;
      if (alarmMinutesBefore != null)
        task.alarmMinutesBefore = alarmMinutesBefore;
      if (alarmMinutesAfter != null) task.alarmMinutesAfter = alarmMinutesAfter;
      if (hasNotification != null) task.hasNotification = hasNotification;
      if (notificationMinutesBefore != null) {
        task.notificationMinutesBefore = notificationMinutesBefore;
      }
      if (notificationMinutesAfter != null) {
        task.notificationMinutesAfter = notificationMinutesAfter;
      }

      _saveTasks();
      // Solo notificar si no está suprimido
      if (!suppressNotification) {
        notifyListeners();
      }
    }
  }

  /// Aplica los cambios de `updatedTask` a la tarea original y a TODAS sus relacionadas,
  /// buscando las relacionadas en base a la tarea ORIGINAL (antes de editar).
  Future<void> updateAllRelatedTasksFromOriginal({
    required PendingTask originalTask,
    required PendingTask updatedTask,
  }) async {
    // 1) Actualiza la original
    updateTaskInPlace(
      originalTask.id,
      title: updatedTask.title,
      description: updatedTask.description,
      categoria: updatedTask.categoria,
      dateTime: updatedTask.dateTime,
      endDateTime: updatedTask.endDateTime,
      colorHex: updatedTask.colorHex,
      isAllDay: updatedTask.isAllDay,
      repeatType: updatedTask.repeatType,
      customDays: updatedTask.customDays,
      hasAlarm: updatedTask.hasAlarm,
      alarmMinutesBefore: updatedTask.alarmMinutesBefore,
      alarmMinutesAfter: updatedTask.alarmMinutesAfter,
      hasNotification: updatedTask.hasNotification,
      notificationMinutesBefore: updatedTask.notificationMinutesBefore,
      notificationMinutesAfter: updatedTask.notificationMinutesAfter,
    );

    // 2) Calcula relacionadas usando la ORIGINAL (antes de editar)
    final relatedTasks = getRelatedTasks(originalTask);

    // 3) Procesar en lotes más grandes para mayor velocidad
    const int batchSize = 10; // Aumentado de 3 a 10
    final List<Future<void>> updateFutures = [];

    for (int i = 0; i < relatedTasks.length; i++) {
      final related = relatedTasks[i];
      final newDescription = updatedTask.description;

      // Crear una función asíncrona para cada actualización
      updateFutures.add(
        Future.microtask(() {
          updateTaskInPlace(
            related.id,
            title: updatedTask.title,
            description: newDescription,
            categoria: updatedTask.categoria,
            dateTime: DateTime(
              related.dateTime.year,
              related.dateTime.month,
              related.dateTime.day,
              updatedTask.dateTime.hour,
              updatedTask.dateTime.minute,
            ),
            endDateTime: updatedTask.endDateTime != null
                ? DateTime(
                    related.dateTime.year,
                    related.dateTime.month,
                    related.dateTime.day,
                    updatedTask.endDateTime!.hour,
                    updatedTask.endDateTime!.minute,
                  )
                : null,
            colorHex: updatedTask.colorHex,
            isAllDay: updatedTask.isAllDay,
            hasAlarm: updatedTask.hasAlarm,
            alarmMinutesBefore: updatedTask.alarmMinutesBefore,
            alarmMinutesAfter: updatedTask.alarmMinutesAfter,
            hasNotification: updatedTask.hasNotification,
            notificationMinutesBefore: updatedTask.notificationMinutesBefore,
            notificationMinutesAfter: updatedTask.notificationMinutesAfter,
          );
        }),
      );

      // Procesar en lotes más grandes
      if (updateFutures.length >= batchSize || i == relatedTasks.length - 1) {
        await Future.wait(updateFutures);
        updateFutures.clear();
        // Pausa más corta para mayor velocidad
        if (i < relatedTasks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
    }
  }

  Future<void> updateAllRelatedTasks(PendingTask updatedTask) async {
    final relatedTasks = getRelatedTasks(updatedTask);

    // Actualizar la tarea original sin notificación
    updateTaskInPlace(
      updatedTask.id,
      title: updatedTask.title,
      description: updatedTask.description,
      categoria: updatedTask.categoria,
      dateTime: updatedTask.dateTime,
      endDateTime: updatedTask.endDateTime,
      colorHex: updatedTask.colorHex,
      isAllDay: updatedTask.isAllDay,
      repeatType: updatedTask.repeatType,
      customDays: updatedTask.customDays,
      hasAlarm: updatedTask.hasAlarm,
      alarmMinutesBefore: updatedTask.alarmMinutesBefore,
      alarmMinutesAfter: updatedTask.alarmMinutesAfter,
      hasNotification: updatedTask.hasNotification,
      notificationMinutesBefore: updatedTask.notificationMinutesBefore,
      notificationMinutesAfter: updatedTask.notificationMinutesAfter,
      suppressNotification: true,
    );

    // Procesar TODAS las tareas relacionadas en paralelo sin delays
    final List<Future<void>> updateFutures = relatedTasks.map((relatedTask) {
      final newDescription = updatedTask.description;

      return Future.microtask(() {
        updateTaskInPlace(
          relatedTask.id,
          title: updatedTask.title,
          description: newDescription,
          categoria: updatedTask.categoria,
          dateTime: DateTime(
            relatedTask.dateTime.year,
            relatedTask.dateTime.month,
            relatedTask.dateTime.day,
            updatedTask.dateTime.hour,
            updatedTask.dateTime.minute,
          ),
          endDateTime: updatedTask.endDateTime != null
              ? DateTime(
                  relatedTask.dateTime.year,
                  relatedTask.dateTime.month,
                  relatedTask.dateTime.day,
                  updatedTask.endDateTime!.hour,
                  updatedTask.endDateTime!.minute,
                )
              : null,
          colorHex: updatedTask.colorHex,
          isAllDay: updatedTask.isAllDay,
          hasAlarm: updatedTask.hasAlarm,
          alarmMinutesBefore: updatedTask.alarmMinutesBefore,
          alarmMinutesAfter: updatedTask.alarmMinutesAfter,
          hasNotification: updatedTask.hasNotification,
          notificationMinutesBefore: updatedTask.notificationMinutesBefore,
          notificationMinutesAfter: updatedTask.notificationMinutesAfter,
          suppressNotification: true, // Suprimir notificaciones individuales
        );
      });
    }).toList();

    // Ejecutar todas las actualizaciones en paralelo
    await Future.wait(updateFutures);

    // Una sola notificación al final
    notifyListeners();
  }

  void _generateRepeatedTasks(PendingTask originalTask) {
    final List<DateTime> futureDates = _calculateRepeatDates(originalTask);

    for (final date in futureDates) {
      if (!_taskExistsOnDate(originalTask.title, date)) {
        final repeatedTask = PendingTask(
          id: '${DateTime.now().millisecondsSinceEpoch}_${date.millisecondsSinceEpoch}',
          title: originalTask.title,
          description: originalTask.description,
          categoria: originalTask.categoria,
          dateTime: DateTime(
            date.year,
            date.month,
            date.day,
            originalTask.dateTime.hour,
            originalTask.dateTime.minute,
          ),
          endDateTime: originalTask.endDateTime != null
              ? DateTime(
                  date.year,
                  date.month,
                  date.day,
                  originalTask.endDateTime!.hour,
                  originalTask.endDateTime!.minute,
                )
              : null,
          completed: false,
          colorHex: originalTask.colorHex,
          isAllDay: originalTask.isAllDay,
          repeatType: null,
          customDays: null,
          hasAlarm: originalTask.hasAlarm,
          alarmMinutesBefore: originalTask.alarmMinutesBefore,
          alarmMinutesAfter: originalTask.alarmMinutesAfter,
          hasNotification: originalTask.hasNotification,
          notificationMinutesBefore: originalTask.notificationMinutesBefore,
          notificationMinutesAfter: originalTask.notificationMinutesAfter,
        );

        tasks.add(repeatedTask);
        _scheduleRepeatedTaskNotifications(repeatedTask);
      }
    }
  }

  bool _taskExistsOnDate(String title, DateTime date) {
    return tasks.any((task) =>
        task.title == title &&
        task.dateTime.year == date.year &&
        task.dateTime.month == date.month &&
        task.dateTime.day == date.day);
  }

  List<DateTime> _calculateRepeatDates(PendingTask task) {
    final List<DateTime> dates = [];
    final startDate = task.dateTime;
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 365)); // hasta 1 año

    switch (task.repeatType) {
      case 'daily':
        dates.addAll(_generateDailyDates(startDate, maxDate));
        break;
      case 'saturday':
        dates.addAll(
            _generateWeeklyDates(startDate, maxDate, DateTime.saturday));
        break;
      case 'sunday':
        dates.addAll(_generateWeeklyDates(startDate, maxDate, DateTime.sunday));
        break;
      case 'weekly':
        dates.addAll(
            _generateWeeklyDates(startDate, maxDate, startDate.weekday));
        break;
      case 'weekdays':
        dates.addAll(_generateWeekdaysDates(startDate, maxDate));
        break;
      case 'yearly':
        dates.addAll(_generateYearlyDates(startDate, maxDate));
        break;
      case 'custom':
        if (task.customDays != null) {
          dates.addAll(
              _generateCustomDates(startDate, maxDate, task.customDays!));
        }
        break;
    }

    return dates;
  }

  List<DateTime> _generateDailyDates(DateTime startDate, DateTime maxDate) {
    final List<DateTime> dates = [];
    DateTime currentDate = startDate.add(const Duration(days: 1));

    while (currentDate.isBefore(maxDate)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return dates;
  }

  List<DateTime> _generateWeeklyDates(
      DateTime startDate, DateTime maxDate, int targetWeekday) {
    final List<DateTime> dates = [];
    DateTime nextDate = _findNextWeekday(startDate, targetWeekday);

    while (nextDate.isBefore(maxDate)) {
      dates.add(nextDate);
      nextDate = nextDate.add(const Duration(days: 7));
    }
    return dates;
  }

  DateTime _findNextWeekday(DateTime startDate, int targetWeekday) {
    DateTime nextDate = startDate.add(const Duration(days: 1));
    while (nextDate.weekday != targetWeekday) {
      nextDate = nextDate.add(const Duration(days: 1));
    }
    return nextDate;
  }

  List<DateTime> _generateWeekdaysDates(DateTime startDate, DateTime maxDate) {
    final List<DateTime> dates = [];
    DateTime currentDate = startDate.add(const Duration(days: 1));

    while (currentDate.isBefore(maxDate)) {
      if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
        dates.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return dates;
  }

  List<DateTime> _generateYearlyDates(DateTime startDate, DateTime maxDate) {
    final List<DateTime> dates = [];
    DateTime currentDate =
        DateTime(startDate.year + 1, startDate.month, startDate.day);

    while (currentDate.isBefore(maxDate)) {
      dates.add(currentDate);
      currentDate =
          DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
    }
    return dates;
  }

  List<DateTime> _generateCustomDates(
      DateTime startDate, DateTime maxDate, List<int> customDays) {
    final List<DateTime> dates = [];
    DateTime currentDate = startDate.add(const Duration(days: 1));

    while (currentDate.isBefore(maxDate)) {
      if (customDays.contains(currentDate.weekday)) {
        dates.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return dates;
  }

  Future<void> _scheduleRepeatedTaskNotifications(PendingTask task) async {
    try {
      if (task.hasAlarm &&
          (task.alarmMinutesBefore != null || task.alarmMinutesAfter != null)) {
        await NotificationService.scheduleTaskAlarm(
          taskId: task.id,
          taskTitle: task.title,
          taskDateTime: task.dateTime,
          minutesBefore: task.alarmMinutesBefore,
          minutesAfter: task.alarmMinutesAfter,
        );
      }

      if (task.hasNotification &&
          (task.notificationMinutesBefore != null ||
              task.notificationMinutesAfter != null)) {
        await NotificationService.scheduleTaskNotification(
          taskId: task.id,
          taskTitle: task.title,
          taskDateTime: task.dateTime,
          minutesBefore: task.notificationMinutesBefore,
          minutesAfter: task.notificationMinutesAfter,
        );
      }
    } catch (e) {
      debugPrint('❌ Error al programar notificaciones para tarea repetida: $e');
    }
  }
}

/// Paleta de colores pasteles para las tareas
class TaskColors {
  static const List<String> pastelColors = [
    '#7FB3D3',
    '#E8999A',
    '#8FBC8F',
    '#DAA520',
    '#9370DB',
    '#4682B4',
    '#CD853F',
    '#5F9EA0',
    '#A0522D',
    '#8B7AC7',
    '#FF8C00',
    '#9966CC',
    '#2F4F4F',
    '#B8860B',
    '#DC143C',
    '#2E8B57',
    '#D2691E',
    '#708090',
    '#8B7355',
    '#6A5ACD',
  ];

  static const List<String> colorNames = [
    'Azul Elegante',
    'Rosa Profesional',
    'Verde Bosque',
    'Dorado Rico',
    'Púrpura Real',
    'Azul Profundo',
    'Terracota',
    'Verde Jade',
    'Canela Rica',
    'Lila Intenso',
    'Naranja Vibrante',
    'Ciruela Profunda',
    'Verde Pizarra',
    'Oro Antiguo',
    'Carmesí Elegante',
    'Verde Esmeralda',
    'Chocolate Claro',
    'Gris Profesional',
    'Beige Elegante',
    'Violeta Pizarra'
  ];

  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
