/// Modelo para subtareas dentro de los cuadernos de marcado
class SubTask {
  String id;
  String title;
  bool completed;
  DateTime createdAt;

  SubTask({
    required this.id,
    required this.title,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Crea desde JSON
  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      completed: json['completed'] ?? false,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Copia con modificaciones
  SubTask copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Modelo para los cuadernos de marcado
class NotebookEntry {
  String id;
  String
      taskId; // ID de la tarea principal (puede ser null para cuadernos del día)
  String title;
  List<SubTask> subTasks;
  DateTime createdAt;
  DateTime updatedAt;

  NotebookEntry({
    required this.id,
    required this.taskId,
    required this.title,
    List<SubTask>? subTasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : subTasks = subTasks ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Crea desde JSON
  factory NotebookEntry.fromJson(Map<String, dynamic> json) {
    return NotebookEntry(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      title: json['title'] ?? '',
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((s) => SubTask.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Copia con modificaciones
  NotebookEntry copyWith({
    String? id,
    String? taskId,
    String? title,
    List<SubTask>? subTasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotebookEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      subTasks: subTasks ?? this.subTasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Agrega una subtarea
  void addSubTask(SubTask subTask) {
    subTasks.add(subTask);
    updatedAt = DateTime.now();
  }

  /// Elimina una subtarea por ID
  void removeSubTask(String subTaskId) {
    subTasks.removeWhere((s) => s.id == subTaskId);
    updatedAt = DateTime.now();
  }

  /// Actualiza una subtarea
  void updateSubTask(SubTask updatedSubTask) {
    final index = subTasks.indexWhere((s) => s.id == updatedSubTask.id);
    if (index != -1) {
      subTasks[index] = updatedSubTask;
      updatedAt = DateTime.now();
    }
  }

  /// Obtiene el porcentaje de completitud
  double get completionPercentage {
    if (subTasks.isEmpty) return 0.0;
    final completed = subTasks.where((s) => s.completed).length;
    return completed / subTasks.length;
  }

  /// Obtiene el número de subtareas completadas
  int get completedCount {
    return subTasks.where((s) => s.completed).length;
  }
}
