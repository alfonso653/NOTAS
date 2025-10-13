import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notebook_models.dart';

class NotebookProvider extends ChangeNotifier {
  List<NotebookEntry> _notebooks = [];
  static const String _storageKey = 'notebooks_data';

  List<NotebookEntry> get notebooks => _notebooks;

  /// Inicializar y cargar datos
  Future<void> initialize() async {
    await loadNotebooks();
  }

  /// Cargar cuadernos desde SharedPreferences
  Future<void> loadNotebooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notebooksJson = prefs.getString(_storageKey);
      
      if (notebooksJson != null) {
        final List<dynamic> notebooksList = json.decode(notebooksJson);
        _notebooks = notebooksList
            .map((notebook) => NotebookEntry.fromJson(notebook as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error al cargar cuadernos: $e');
    }
  }

  /// Guardar cuadernos en SharedPreferences
  Future<void> saveNotebooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notebooksJson = json.encode(_notebooks.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, notebooksJson);
    } catch (e) {
      debugPrint('❌ Error al guardar cuadernos: $e');
    }
  }

  /// Obtener cuaderno por ID de tarea (para cuadernos específicos de tarea)
  NotebookEntry? getNotebookByTaskId(String taskId) {
    try {
      return _notebooks.firstWhere((n) => n.taskId == taskId);
    } catch (e) {
      return null;
    }
  }

  /// Obtener cuaderno del día (taskId vacío y fecha específica)
  NotebookEntry? getDayNotebook(DateTime date) {
    final dayId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      return _notebooks.firstWhere((n) => n.taskId == dayId && n.id.startsWith('day_'));
    } catch (e) {
      return null;
    }
  }

  /// Crear o obtener cuaderno para una tarea específica
  NotebookEntry getOrCreateTaskNotebook(String taskId, String taskTitle) {
    var notebook = getNotebookByTaskId(taskId);
    
    if (notebook == null) {
      notebook = NotebookEntry(
        id: 'task_$taskId',
        taskId: taskId,
        title: taskTitle,
      );
      _notebooks.add(notebook);
      saveNotebooks();
      notifyListeners();
    }
    
    return notebook;
  }

  /// Crear o obtener cuaderno para un día específico
  NotebookEntry getOrCreateDayNotebook(DateTime date) {
    var notebook = getDayNotebook(date);
    
    if (notebook == null) {
      final dayId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      notebook = NotebookEntry(
        id: 'day_$dayId',
        taskId: dayId,
        title: 'Tareas del ${date.day}/${date.month}/${date.year}',
      );
      _notebooks.add(notebook);
      saveNotebooks();
      notifyListeners();
    }
    
    return notebook;
  }

  /// Actualizar cuaderno
  void updateNotebook(NotebookEntry updatedNotebook) {
    final index = _notebooks.indexWhere((n) => n.id == updatedNotebook.id);
    if (index != -1) {
      _notebooks[index] = updatedNotebook;
      saveNotebooks();
      notifyListeners();
    }
  }

  /// Eliminar cuaderno
  void deleteNotebook(String notebookId) {
    _notebooks.removeWhere((n) => n.id == notebookId);
    saveNotebooks();
    notifyListeners();
  }

  /// Agregar subtarea a un cuaderno
  void addSubTaskToNotebook(String notebookId, String subTaskTitle) {
    final notebook = _notebooks.firstWhere((n) => n.id == notebookId);
    final subTask = SubTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: subTaskTitle,
    );
    
    notebook.addSubTask(subTask);
    updateNotebook(notebook);
  }

  /// Actualizar subtarea
  void updateSubTask(String notebookId, SubTask updatedSubTask) {
    final notebook = _notebooks.firstWhere((n) => n.id == notebookId);
    notebook.updateSubTask(updatedSubTask);
    updateNotebook(notebook);
  }

  /// Eliminar subtarea
  void deleteSubTask(String notebookId, String subTaskId) {
    final notebook = _notebooks.firstWhere((n) => n.id == notebookId);
    notebook.removeSubTask(subTaskId);
    updateNotebook(notebook);
  }

  /// Alternar completitud de subtarea
  void toggleSubTaskCompletion(String notebookId, String subTaskId) {
    final notebook = _notebooks.firstWhere((n) => n.id == notebookId);
    final subTask = notebook.subTasks.firstWhere((s) => s.id == subTaskId);
    final updatedSubTask = subTask.copyWith(completed: !subTask.completed);
    
    notebook.updateSubTask(updatedSubTask);
    updateNotebook(notebook);
  }
}