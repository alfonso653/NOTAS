import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? repeatType; // Tipo de repetición
  List<int>? customDays; // Días personalizados (1=Lunes, 7=Domingo)

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
      'customDays': customDays,
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

  /// Verifica si la tarea ocurre en una hora específica
  bool occursInHour(int hour) {
    if (endDateTime == null) {
      return dateTime.hour == hour;
    }

    // Una tarea ocurre en una hora si:
    // 1. Empieza en esa hora, O
    // 2. Termina en esa hora (incluso si es el mismo minuto), O
    // 3. Atraviesa esa hora completamente
    return (dateTime.hour <= hour && endDateTime!.hour >= hour);
  }

  /// Obtiene la porción de la tarea que ocurre en una hora específica (0.0 a 1.0)
  double getPortionInHour(int hour) {
    if (endDateTime == null) {
      return dateTime.hour == hour ? 1.0 : 0.0;
    }

    final hourStart =
        DateTime(dateTime.year, dateTime.month, dateTime.day, hour);
    final hourEnd = hourStart.add(const Duration(hours: 1));

    final taskStart = dateTime.isAfter(hourStart) ? dateTime : hourStart;
    final taskEnd = endDateTime!.isBefore(hourEnd) ? endDateTime! : hourEnd;

    if (taskEnd.isBefore(taskStart) || taskStart.isAfter(hourEnd)) {
      return 0.0;
    }

    final overlapMinutes = taskEnd.difference(taskStart).inMinutes;
    return overlapMinutes / 60.0;
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

    // Si tiene repetición, generar tareas adicionales
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
    // Buscar tareas con el mismo título y descripción base (sin el emoji de repetición)
    final baseDescription = task.description.startsWith('🔄 ')
        ? task.description.substring(2)
        : task.description;

    return tasks
        .where((t) =>
            t.id != task.id && // No incluir la tarea actual
            t.title == task.title &&
            (t.description == baseDescription ||
                t.description == '🔄 $baseDescription' ||
                (t.description.startsWith('🔄 ') &&
                    t.description.substring(2) == baseDescription)))
        .toList();
  }

  /// Elimina solo una tarea específica
  void deleteSingleTask(String id) {
    deleteTask(id);
  }

  /// Elimina todas las tareas relacionadas (repetidas) incluyendo la actual
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

  /// Genera tareas repetidas según el patrón especificado
  void _generateRepeatedTasks(PendingTask originalTask) {
    final List<DateTime> futureDates = _calculateRepeatDates(originalTask);

    for (final date in futureDates) {
      // Evitar duplicados: verificar si ya existe una tarea similar en esa fecha
      if (!_taskExistsOnDate(originalTask.title, date)) {
        final repeatedTask = PendingTask(
          id: '${DateTime.now().millisecondsSinceEpoch}_${date.millisecondsSinceEpoch}',
          title: originalTask.title,
          description:
              '🔄 ${originalTask.description}', // Indicador de repetición
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
          repeatType: null, // Las tareas generadas no se repiten a su vez
          customDays: null,
        );

        tasks.insert(0, repeatedTask);
      }
    }
  }

  /// Verifica si ya existe una tarea con el mismo título en la fecha especificada
  bool _taskExistsOnDate(String title, DateTime date) {
    return tasks.any((task) =>
        task.title == title &&
        task.dateTime.year == date.year &&
        task.dateTime.month == date.month &&
        task.dateTime.day == date.day);
  }

  /// Calcula las fechas futuras según el tipo de repetición
  List<DateTime> _calculateRepeatDates(PendingTask task) {
    final List<DateTime> dates = [];
    final startDate = task.dateTime;
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 365)); // Generar hasta 1 año

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

  /// Genera fechas para repetición diaria
  List<DateTime> _generateDailyDates(DateTime startDate, DateTime maxDate) {
    final List<DateTime> dates = [];
    DateTime currentDate = startDate.add(const Duration(days: 1));

    while (currentDate.isBefore(maxDate)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Genera fechas para repetición semanal en un día específico
  List<DateTime> _generateWeeklyDates(
      DateTime startDate, DateTime maxDate, int targetWeekday) {
    final List<DateTime> dates = [];

    // Para 'weekly': siguiente ocurrencia del mismo día de la semana
    // Para 'saturday'/'sunday': siguiente ocurrencia de ese día específico
    DateTime nextDate = _findNextWeekday(startDate, targetWeekday);

    while (nextDate.isBefore(maxDate)) {
      dates.add(nextDate);
      nextDate = nextDate.add(const Duration(days: 7));
    }

    return dates;
  }

  /// Encuentra la próxima ocurrencia de un día de la semana específico
  DateTime _findNextWeekday(DateTime startDate, int targetWeekday) {
    DateTime nextDate = startDate.add(const Duration(days: 1));

    while (nextDate.weekday != targetWeekday) {
      nextDate = nextDate.add(const Duration(days: 1));
    }

    return nextDate;
  }

  /// Genera fechas para días laborables (lunes a viernes)
  List<DateTime> _generateWeekdaysDates(DateTime startDate, DateTime maxDate) {
    final List<DateTime> dates = [];
    DateTime currentDate = startDate.add(const Duration(days: 1));

    while (currentDate.isBefore(maxDate)) {
      // Solo días laborables (1=Lunes, 5=Viernes)
      if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
        dates.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Genera fechas para repetición anual
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

  /// Genera fechas para días personalizados
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
}

/// Paleta de colores pasteles para las tareas
class TaskColors {
  static const List<String> pastelColors = [
    '#A8C8FF', // Azul pastel suave
    '#FFB3BA', // Rosa pastel coral
    '#B5E48C', // Verde pastel mint
    '#FFD93D', // Amarillo pastel mantequilla
    '#DDA0DD', // Púrpura pastel lavenda
    '#87CEEB', // Azul cielo pastel
    '#F0A0A0', // Durazno pastel suave
    '#98E4D6', // Verde agua pastel
    '#C4A484', // Café pastel canela
    '#B19CD9', // Lavanda pastel medio
    '#FFB347', // Naranja pastel cálido
    '#D8BFD8', // Ciruela pastel
    '#AFEEEE', // Turquesa pastel pálido
    '#F0E68C', // Khaki pastel dorado
    '#FFC0CB', // Rosa pastel clásico
    '#B0E0E6', // Azul pólvora pastel
    '#E6D35C', // Amarillo pastel mostaza
    '#A8A8A8', // Gris pastel medio
    '#D4B996', // Beige pastel cálido
    '#7FCDCD', // Cian pastel medio
  ];

  static const List<String> colorNames = [
    'Azul Suave',
    'Rosa Coral',
    'Verde Mint',
    'Mantequilla',
    'Lavanda',
    'Cielo',
    'Durazno',
    'Agua Marina',
    'Canela',
    'Lila',
    'Naranja',
    'Ciruela',
    'Turquesa',
    'Dorado',
    'Rosa Clásico',
    'Pólvora',
    'Mostaza',
    'Gris Medio',
    'Beige Cálido',
    'Cian Medio'
  ];

  /// Convierte color hex a Color de Flutter
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convierte Color de Flutter a hex
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
