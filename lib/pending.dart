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

  PendingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.categoria,
    required this.dateTime,
    this.endDateTime,
    this.completed = false,
    this.colorHex = '#6B73FF', // Color azul por defecto
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'categoria': categoria,
        'dateTime': dateTime.toIso8601String(),
        'endDateTime': endDateTime?.toIso8601String(),
        'completed': completed,
        'colorHex': colorHex,
      };

  factory PendingTask.fromJson(Map<String, dynamic> json) => PendingTask(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        categoria: json['categoria'] as String? ?? '',
        dateTime: DateTime.parse(json['dateTime'] as String),
        endDateTime: json['endDateTime'] != null ? DateTime.parse(json['endDateTime'] as String) : null,
        completed: (json['completed'] as bool?) ?? false,
        colorHex: json['colorHex'] as String? ?? '#6B73FF',
      );

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
    return dateTime.hour <= hour && endDateTime!.hour > hour;
  }

  /// Obtiene la porción de la tarea que ocurre en una hora específica (0.0 a 1.0)
  double getPortionInHour(int hour) {
    if (endDateTime == null) {
      return dateTime.hour == hour ? 1.0 : 0.0;
    }

    final hourStart = DateTime(dateTime.year, dateTime.month, dateTime.day, hour);
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
    tasks.insert(0, task);
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

  void updateTask(PendingTask updatedTask) {
    final idx = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (idx != -1) {
      tasks[idx] = updatedTask;
      _saveTasks();
      notifyListeners();
    }
  }
}

/// Paleta de colores pasteles para las tareas
class TaskColors {
  static const List<String> pastelColors = [
    '#6B73FF', // Azul (default)
    '#FF4757', // Rojo vibrante
    '#2ED573', // Verde lima
    '#FFA502', // Naranja brillante
    '#FF6B9D', // Rosa fucsia
    '#5352ED', // Púrpura
    '#FF3838', // Rojo coral
    '#00D2D3', // Turquesa
    '#FFD32A', // Amarillo sol
    '#FF9F43', // Mandarina
    '#A4B0BE', // Gris azulado
    '#8B5CF6', // Violeta
    '#06FFA5', // Verde neón
    '#F8B500', // Ámbar
    '#E056FD', // Magenta
    '#26C6DA', // Cian
    '#FF7675', // Salmón claro
    '#74B9FF', // Azul cielo
    '#FDCB6E', // Dorado suave
    '#6C5CE7', // Índigo
  ];

  static const List<String> colorNames = [
    'Azul', 'Rojo', 'Lima', 'Naranja', 'Fucsia',
    'Púrpura', 'Coral', 'Turquesa', 'Sol', 'Mandarina',
    'Gris', 'Violeta', 'Neón', 'Ámbar', 'Magenta',
    'Cian', 'Salmón', 'Cielo', 'Dorado', 'Índigo'
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
