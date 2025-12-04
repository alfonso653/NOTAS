import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:ui';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'platform_utils.dart' as platform;
import 'package:universal_io/io.dart' show File;
import 'notebook_provider.dart';
import 'notebook_models.dart';
import 'pending.dart';
import 'package:intl/intl.dart';

/// Formateador personalizado para números con separadores de miles
class NumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si está vacío, retornar vacío
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Obtener solo dígitos del texto
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Si no hay dígitos, retornar vacío
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Convertir a número para formatear
    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    // Formatear con separadores de miles usando formato español
    final formatted = _formatNumber(number);

    // Calcular nueva posición del cursor
    int newSelectionIndex = formatted.length;

    // Intentar mantener la posición relativa del cursor
    final oldDigitsOnly = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final newDigitsLength = digitsOnly.length;
    final oldDigitsLength = oldDigitsOnly.length;

    if (newDigitsLength > oldDigitsLength) {
      // Se agregó un dígito
      newSelectionIndex = formatted.length;
    } else if (newDigitsLength < oldDigitsLength) {
      // Se borró un dígito
      newSelectionIndex = formatted.length;
    } else {
      // Longitud igual, mantener al final
      newSelectionIndex = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }

  /// Formatea un número con separadores de miles usando puntos
  String _formatNumber(int number) {
    // Convertir número a string
    String numberStr = number.toString();

    // Si tiene menos de 4 dígitos, no necesita formateo
    if (numberStr.length <= 3) {
      return numberStr;
    }

    // Agregar puntos cada 3 dígitos desde la derecha
    String result = '';
    for (int i = 0; i < numberStr.length; i++) {
      if (i > 0 && (numberStr.length - i) % 3 == 0) {
        result += '.';
      }
      result += numberStr[i];
    }

    return result;
  }
}

/// Pantalla del cuaderno de marcado
class NotebookScreen extends StatefulWidget {
  final String notebookId;
  final String title;
  final String? description;
  final bool
  isTaskNotebook; // true para cuaderno de tarea, false para cuaderno del día
  final DateTime? date; // Fecha para cuaderno del día

  const NotebookScreen({
    Key? key,
    required this.notebookId,
    required this.title,
    this.description,
    required this.isTaskNotebook,
    this.date,
  }) : super(key: key);

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final TextEditingController _newSubTaskController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _costDescriptionController =
      TextEditingController();
  bool _showTitleField = false;
  bool _showSubTaskField = false;
  bool _showCostField = false;
  late NotebookEntry notebook;
  DateTime? _notebookDate; // Fecha para el cuaderno general

  // Variables para la calculadora
  Map<String, String> _calculatorOperations = {}; // ID -> '+' o '-'

  // Variables para edición de segmentos
  String? _editingSegmentId;
  final TextEditingController _editCostController = TextEditingController();
  final TextEditingController _editDescriptionController =
      TextEditingController();

  // Variables para edición de título y subtareas normales
  String? _editingTitleId;
  String? _editingSubTaskId;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editSubTaskController = TextEditingController();

  // Key para captura de screenshot
  final GlobalKey _notebookKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Inicializar con un notebook vacío por defecto
    final initialTitle = widget.title;

    // Inicializar fecha si es cuaderno del día
    _notebookDate = widget.date;

    notebook = NotebookEntry(
      id: widget.notebookId,
      taskId: widget.isTaskNotebook ? widget.notebookId : '',
      title: initialTitle,
      subTasks: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNotebook();

    // Escuchar cambios en PendingProvider para sincronización automática
    if (!widget.isTaskNotebook) {
      context.read<PendingProvider>().addListener(_onPendingTasksChanged);
    }
  }

  void _onPendingTasksChanged() {
    // Solo recargar si es cuaderno del día y está montado
    if (!widget.isTaskNotebook && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadDayTasks();
        }
      });
    }
  }

  void _loadNotebook() {
    final notebookProvider = context.read<NotebookProvider>();
    final foundNotebook = notebookProvider.notebooks
        .where((n) => n.id == widget.notebookId)
        .firstOrNull;

    if (foundNotebook != null) {
      setState(() {
        notebook = foundNotebook;
      });
    }

    // Si es cuaderno del día, SIEMPRE cargar las tareas automáticamente después del build
    if (!widget.isTaskNotebook) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDayTasks();
      });
    }
  }

  void _loadDayTasks() {
    if (_notebookDate == null) return;

    final pendingProvider = context.read<PendingProvider>();
    final dayTasks = pendingProvider.tasks.where((task) {
      return task.dateTime.year == _notebookDate!.year &&
          task.dateTime.month == _notebookDate!.month &&
          task.dateTime.day == _notebookDate!.day;
    }).toList();

    // Ordenar por hora cronológicamente (más temprano primero)
    dayTasks.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final notebookProvider = context.read<NotebookProvider>();

    // Obtener las tareas manuales existentes (no automáticas)
    List<SubTask> manualTasks = notebook.subTasks
        .where((subTask) => !subTask.id.startsWith('auto_task_'))
        .toList();

    // Crear las nuevas tareas automáticas manteniendo el orden cronológico
    List<SubTask> autoTasks = [];

    for (final task in dayTasks) {
      final timeStr = DateFormat('h:mm a').format(task.dateTime);
      final taskEntry = '⏰ $timeStr - ${task.title}';
      final taskId = 'auto_task_${task.id}';

      // Buscar si ya existe esta tarea automática
      final existingTask = notebook.subTasks
          .where((s) => s.id == taskId)
          .firstOrNull;

      if (existingTask != null) {
        // Si existe, verificar si necesita sincronización
        if (existingTask.completed != task.completed) {
          autoTasks.add(existingTask.copyWith(completed: task.completed));
        } else {
          autoTasks.add(existingTask);
        }
      } else {
        // Crear nueva tarea automática
        autoTasks.add(
          SubTask(id: taskId, title: taskEntry, completed: task.completed),
        );
      }
    }

    // ORDEN FINAL FORZADO: autoTasks (ordenadas cronológicamente) + manualTasks
    final List<SubTask> finalOrderedSubTasks = [...autoTasks, ...manualTasks];

    // SIEMPRE actualizar para forzar el orden correcto
    final updatedNotebook = notebook.copyWith(
      subTasks: finalOrderedSubTasks,
      updatedAt: DateTime.now(),
    );

    notebookProvider.updateNotebook(updatedNotebook);

    setState(() {
      notebook = updatedNotebook;
    });
  }

  @override
  void dispose() {
    // Remover listener de PendingProvider si es cuaderno del día
    if (!widget.isTaskNotebook) {
      context.read<PendingProvider>().removeListener(_onPendingTasksChanged);
    }

    _newSubTaskController.dispose();
    _titleController.dispose();
    _costController.dispose();
    _costDescriptionController.dispose();
    _editCostController.dispose();
    _editDescriptionController.dispose();
    _editTitleController.dispose();
    _editSubTaskController.dispose();
    super.dispose();
  }

  void _addSubTask() {
    if (_newSubTaskController.text.trim().isNotEmpty) {
      final notebookProvider = context.read<NotebookProvider>();
      final subTaskEntry = '✅ ${_newSubTaskController.text.trim()}';
      notebookProvider.addSubTaskToNotebook(notebook.id, subTaskEntry);
      _newSubTaskController.clear();
      setState(() {
        _showSubTaskField = false;
      });
      _loadNotebook();
    }
  }

  void _saveTitle() {
    if (_titleController.text.trim().isNotEmpty) {
      final notebookProvider = context.read<NotebookProvider>();
      final titleEntry = '📝 ${_titleController.text.trim()}';
      notebookProvider.addSubTaskToNotebook(notebook.id, titleEntry);
      _titleController.clear();
      setState(() {
        _showTitleField = false;
      });
      _loadNotebook(); // Recargar para asegurar sincronización
    }
  }

  void _saveCost() {
    if (_costController.text.trim().isNotEmpty &&
        _costDescriptionController.text.trim().isNotEmpty) {
      final notebookProvider = context.read<NotebookProvider>();
      final costEntry =
          '🟦 ${_costController.text.trim()} / ${_costDescriptionController.text.trim()}';
      notebookProvider.addSubTaskToNotebook(notebook.id, costEntry);
      _costController.clear();
      _costDescriptionController.clear();
      setState(() {
        _showCostField = false;
      });
      _loadNotebook();
    }
  }

  void _toggleSubTask(SubTask subTask) {
    final notebookProvider = context.read<NotebookProvider>();
    notebookProvider.toggleSubTaskCompletion(notebook.id, subTask.id);

    // Si es una tarea automática del día, sincronizar con PendingProvider
    if (subTask.id.startsWith('auto_task_')) {
      final taskId = subTask.id.replaceFirst('auto_task_', '');
      final pendingProvider = context.read<PendingProvider>();
      pendingProvider.toggleTaskCompletion(taskId);
    }

    _loadNotebook();
  }

  void _deleteSubTask(SubTask subTask) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar subtarea'),
        content: Text('¿Eliminar "${subTask.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final notebookProvider = context.read<NotebookProvider>();
              notebookProvider.deleteSubTask(notebook.id, subTask.id);
              // Remover de calculadora si existía
              _calculatorOperations.remove(subTask.id);
              Navigator.pop(context);
              _loadNotebook();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Funciones para editar segmentos
  void _startEditingSegment(SubTask subTask) {
    if (subTask.title.startsWith('🟦')) {
      final parts = subTask.title.substring(2).split(' / ');
      final cost = parts[0].trim();
      final description = parts.length > 1 ? parts[1].trim() : '';

      setState(() {
        _editingSegmentId = subTask.id;
        _editCostController.text = cost;
        _editDescriptionController.text = description;
      });
    }
  }

  void _saveEditedSegment() {
    if (_editingSegmentId != null &&
        _editCostController.text.trim().isNotEmpty &&
        _editDescriptionController.text.trim().isNotEmpty) {
      final notebookProvider = context.read<NotebookProvider>();
      final newTitle =
          '🟦 ${_editCostController.text.trim()} / ${_editDescriptionController.text.trim()}';

      // Encontrar la subtarea actual y crear una actualizada
      final currentSubTask = notebook.subTasks.firstWhere(
        (s) => s.id == _editingSegmentId!,
      );
      final updatedSubTask = currentSubTask.copyWith(title: newTitle);

      notebookProvider.updateSubTask(notebook.id, updatedSubTask);

      setState(() {
        _editingSegmentId = null;
        _editCostController.clear();
        _editDescriptionController.clear();
      });

      _loadNotebook();
    }
  }

  void _cancelEditingSegment() {
    setState(() {
      _editingSegmentId = null;
      _editCostController.clear();
      _editDescriptionController.clear();
    });
  }

  // Funciones para editar título
  void _startEditingTitle([SubTask? subTask]) {
    if (subTask != null && subTask.title.startsWith('📝')) {
      // Editar título específico de subtarea
      setState(() {
        _editingTitleId = subTask.id;
        _editTitleController.text = subTask.title
            .substring(2)
            .trim(); // Quitar emoji 📝
        _showTitleField = true;
      });
    } else {
      // Editar título general del notebook
      setState(() {
        _editingTitleId = 'notebook_title';
        _editTitleController.text = notebook.title;
        _showTitleField = true;
      });
    }
  }

  void _saveEditedTitle() {
    if (_editTitleController.text.trim().isNotEmpty) {
      final notebookProvider = context.read<NotebookProvider>();

      if (_editingTitleId == 'notebook_title') {
        // Editar título general del notebook
        final updatedNotebook = notebook.copyWith(
          title: _editTitleController.text.trim(),
          updatedAt: DateTime.now(),
        );
        notebookProvider.updateNotebook(updatedNotebook);
      } else {
        // Editar título específico de subtarea
        final currentSubTask = notebook.subTasks.firstWhere(
          (s) => s.id == _editingTitleId!,
        );
        final updatedSubTask = currentSubTask.copyWith(
          title: '📝 ${_editTitleController.text.trim()}',
        );
        notebookProvider.updateSubTask(notebook.id, updatedSubTask);
      }

      setState(() {
        _editingTitleId = null;
        _editTitleController.clear();
        _showTitleField = false;
      });
      _loadNotebook();
    }
  }

  void _cancelEditingTitle() {
    setState(() {
      _editingTitleId = null;
      _editTitleController.clear();
      _showTitleField = false;
    });
  }

  // Funciones para editar subtarea normal
  void _startEditingSubTask(SubTask subTask) {
    setState(() {
      _editingSubTaskId = subTask.id;
      _editSubTaskController.text = subTask.title;
      _showSubTaskField = true;
    });
  }

  void _saveEditedSubTask() {
    if (_editingSubTaskId != null &&
        _editSubTaskController.text.trim().isNotEmpty) {
      final notebookProvider = context.read<NotebookProvider>();
      final currentSubTask = notebook.subTasks.firstWhere(
        (s) => s.id == _editingSubTaskId!,
      );
      final updatedSubTask = currentSubTask.copyWith(
        title: _editSubTaskController.text.trim(),
      );
      notebookProvider.updateSubTask(notebook.id, updatedSubTask);

      setState(() {
        _editingSubTaskId = null;
        _editSubTaskController.clear();
        _showSubTaskField = false;
      });
      _loadNotebook();
    }
  }

  void _cancelEditingSubTask() {
    setState(() {
      _editingSubTaskId = null;
      _editSubTaskController.clear();
      _showSubTaskField = false;
    });
  }

  // Función para mostrar opciones de edición de subtareas
  void _showSubTaskEditOptions() {
    final nonCostSubTasks = notebook.subTasks
        .where((subTask) => !subTask.title.startsWith('🟦'))
        .toList();

    if (nonCostSubTasks.isEmpty) {
      // Si no hay subtareas, simplemente mostrar el campo para agregar
      setState(() => _showSubTaskField = !_showSubTaskField);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Selecciona una tarea para editar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...nonCostSubTasks
                .map(
                  (subTask) => ListTile(
                    title: Text(subTask.title),
                    leading: const Icon(Icons.edit),
                    onTap: () {
                      Navigator.pop(context);
                      _startEditingSubTask(subTask);
                    },
                  ),
                )
                .toList(),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _showSubTaskField = !_showSubTaskField);
              },
              child: const Text('Agregar nueva tarea'),
            ),
          ],
        ),
      ),
    );
  }

  // Funciones para la calculadora
  void _setCalculatorOperation(SubTask subTask, String operation) {
    setState(() {
      if (_calculatorOperations[subTask.id] == operation) {
        // Si ya está seleccionada la misma operación, la quita
        _calculatorOperations.remove(subTask.id);
      } else {
        // Establece la nueva operación
        _calculatorOperations[subTask.id] = operation;
      }
    });
  }

  double _getCalculatorTotal() {
    double total = 0;
    for (final subTask in notebook.subTasks) {
      if (subTask.title.startsWith('🟦') &&
          _calculatorOperations.containsKey(subTask.id)) {
        final operation = _calculatorOperations[subTask.id]!;
        final costText = subTask.title.substring(2).split(' / ')[0].trim();
        final cost =
            double.tryParse(costText.replaceAll('.', '').replaceAll(',', '')) ??
            0;
        if (operation == '+') {
          total += cost;
        } else {
          total -= cost;
        }
      }
    }
    return total;
  }

  List<SubTask> _getCalculatorItems() {
    return notebook.subTasks
        .where(
          (task) =>
              task.title.startsWith('🟦') &&
              _calculatorOperations.containsKey(task.id),
        )
        .toList();
  }

  // Funciones para compartir
  Future<void> _shareAsImage() async {
    try {
      // Capturar screenshot del cuaderno
      RenderRepaintBoundary boundary =
          _notebookKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        // En web, descargar directamente
        platform.downloadFile(
          pngBytes,
          'cuaderno_${widget.title.replaceAll(' ', '_')}.png',
          'image/png',
        );
      } else {
        // Guardar imagen temporalmente
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/cuaderno_${widget.title.replaceAll(' ', '_')}.png',
        );
        await file.writeAsBytes(pngBytes);

        // Compartir imagen
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Cuaderno: ${widget.title}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al compartir imagen: $e')));
    }
  }

  Future<void> _shareAsPDF() async {
    try {
      // Crear contenido de texto para PDF

      // Crear contenido de texto para PDF
      String textContent = _generateTextContent();

      if (kIsWeb) {
        // En web, descargar directamente
        platform.downloadTextFile(
          textContent,
          'cuaderno_${widget.title.replaceAll(' ', '_')}.txt',
        );
      } else {
        // Guardar como archivo de texto temporalmente (simula PDF)
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/cuaderno_${widget.title.replaceAll(' ', '_')}.txt',
        );
        await file.writeAsString(textContent);

        // Compartir archivo
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Cuaderno PDF: ${widget.title}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al compartir PDF: $e')));
    }
  }

  String _generateTextContent() {
    StringBuffer content = StringBuffer();
    content.writeln('CUADERNO: ${widget.title}');
    if (widget.description != null && widget.description!.isNotEmpty) {
      content.writeln('Descripción: ${widget.description}');
    }
    content.writeln('Fecha: ${DateTime.now().toString().split(' ')[0]}');
    content.writeln(
      'Progreso: ${notebook.completedCount}/${notebook.subTasks.length}',
    );
    content.writeln('');
    content.writeln('ELEMENTOS:');
    content.writeln('=' * 50);

    for (int i = 0; i < notebook.subTasks.length; i++) {
      final task = notebook.subTasks[i];
      String status = task.completed ? '[✓]' : '[ ]';
      content.writeln('$status ${task.title}');
    }

    // Agregar resumen de gastos si hay operaciones
    if (_calculatorOperations.isNotEmpty) {
      content.writeln('');
      content.writeln('RESUMEN DE GASTOS:');
      content.writeln('=' * 50);
      final items = _getCalculatorItems();
      for (final item in items) {
        final operation = _calculatorOperations[item.id]!;
        final parts = item.title.substring(2).split(' / ');
        final cost = parts[0].trim();
        final description = parts.length > 1 ? parts[1].trim() : '';
        content.writeln(
          '${operation == '+' ? '+' : '-'} $description: \$${cost}',
        );
      }
      final total = _getCalculatorTotal();
      content.writeln('');
      content.writeln(
        'TOTAL: \$${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}',
      );
    }

    return content.toString();
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Compartir Cuaderno',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF10B981)),
              title: const Text('Compartir como Imagen'),
              subtitle: const Text('Imagen completa para WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _shareAsImage();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Color(0xFFEF4444),
              ),
              title: const Text('Compartir como Documento'),
              subtitle: const Text('Archivo de texto con todo el contenido'),
              onTap: () {
                Navigator.pop(context);
                _shareAsPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCalculatorModal() {
    final items = _getCalculatorItems();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Text('📊', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Resumen de Gastos'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...items.map((item) {
                final operation = _calculatorOperations[item.id]!;
                final parts = item.title.substring(2).split(' / ');
                final cost = parts[0].trim();
                final description = parts.length > 1 ? parts[1].trim() : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        operation == '+' ? '➕' : '➖',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$description: \$${cost}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              if (items.isNotEmpty) ...[
                const Divider(thickness: 1, height: 20),
                Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total: \$${_getCalculatorTotal().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _calculatorOperations.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RepaintBoundary(
        key: _notebookKey,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.grey.shade50.withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header con botón cerrar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF374151),
                          size: 28,
                        ),
                      ),
                      // Botón de compartir
                      IconButton(
                        onPressed: _showShareOptions,
                        icon: const Icon(
                          Icons.share,
                          color: Color(0xFF374151),
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.isTaskNotebook
                            ? '📋 Subtareas'
                            : '📅 Tareas del Día',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const Spacer(),
                      // Contador de progreso
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${notebook.completedCount}/${notebook.subTasks.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido del cuaderno
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width > 600
                          ? 40
                          : 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título y descripción de la tarea
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título en negrilla
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width > 600
                                      ? 20
                                      : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF374151),
                                  height: 1.2,
                                ),
                              ),
                              // Descripción debajo (si existe)
                              if (widget.description != null &&
                                  widget.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.description!,
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width > 600
                                        ? 16
                                        : 14,
                                    fontWeight: FontWeight.normal,
                                    color: const Color(0xFF6B7280),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Lista de subtareas
                        Expanded(
                          child: ListView.builder(
                            itemCount: notebook.subTasks.length,
                            itemBuilder: (context, index) {
                              final subTask = notebook.subTasks[index];
                              return _buildSubTaskItem(subTask, index);
                            },
                          ),
                        ),

                        // Botones de acción organizados horizontalmente
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              // Campos dinámicos
                              if (_showTitleField) _buildTitleField(),
                              if (_showSubTaskField) _buildSubTaskField(),
                              if (_showCostField) _buildCostField(),
                              const SizedBox(height: 16),
                              // Botones organizados responsivamente
                              MediaQuery.of(context).size.width > 400
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: _buildActionButtons(),
                                    )
                                  : Wrap(
                                      alignment: WrapAlignment.spaceEvenly,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _buildActionButtons(),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final buttonSize = MediaQuery.of(context).size.width > 600 ? 20.0 : 18.0;

    return [
      _buildActionButton(
        onTap: () => setState(() => _showTitleField = !_showTitleField),
        onLongPress: notebook.title.isNotEmpty
            ? () => _startEditingTitle()
            : null,
        child: Text('📝', style: TextStyle(fontSize: buttonSize)),
      ),
      _buildActionButton(
        onTap: () => setState(() => _showSubTaskField = !_showSubTaskField),
        onLongPress: () => _showSubTaskEditOptions(),
        child: Text('✅', style: TextStyle(fontSize: buttonSize)),
      ),
      _buildActionButton(
        onTap: () => setState(() => _showCostField = !_showCostField),
        child: Text('🧮', style: TextStyle(fontSize: buttonSize)),
      ),
      _buildActionButton(
        onTap: _showCalculatorModal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('💰', style: TextStyle(fontSize: buttonSize * 0.8)),
            Text(
              _calculatorOperations.isEmpty
                  ? '\$0'
                  : '\$${_getCalculatorTotal().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}',
              style: TextStyle(
                fontSize: buttonSize * 0.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Widget child,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 12,
          vertical: isSmallScreen ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF374151).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildTitleField() {
    final hasText = _titleController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text(
            'Título:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'Escribir título...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _saveTitle,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTaskField() {
    final hasText = _newSubTaskController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _newSubTaskController,
              onSubmitted: (_) => _addSubTask(),
              onChanged: (_) => setState(() {}),
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'Nueva subtarea... (Enter para agregar)',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addSubTask,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostField() {
    final hasText =
        _costController.text.trim().isNotEmpty &&
        _costDescriptionController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('🟦', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _costController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              inputFormatters: [NumberFormatter()],
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: '2.500.000',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '/',
            style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _costDescriptionController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'concepto',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _saveCost,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTaskItem(SubTask subTask, int index) {
    // Verificar si la subtarea tiene emoji especial (📝, 🟦, ✅)
    final hasSpecialEmoji =
        subTask.title.startsWith('📝') ||
        subTask.title.startsWith('🟦') ||
        subTask.title.startsWith('✅');

    // Si está en modo edición, mostrar el campo de edición en lugar del texto normal
    if (_editingSegmentId == subTask.id && subTask.title.startsWith('🟦')) {
      return _buildEditingField(subTask);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solo mostrar checkbox si NO tiene emoji especial
          if (!hasSpecialEmoji) ...[
            // Checkbox normal
            GestureDetector(
              onTap: () => _toggleSubTask(subTask),
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: subTask.completed
                      ? const Color(0xFF10B981)
                      : Colors.transparent,
                  border: Border.all(
                    color: subTask.completed
                        ? const Color(0xFF10B981)
                        : const Color(0xFF374151).withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: subTask.completed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ] else ...[
            // Márgenes diferentes según el tipo de emoji
            SizedBox(
              width: subTask.title.startsWith('📝')
                  ? 10 // Título más a la izquierda
                  : subTask.title.startsWith('✅')
                  ? 50 // Subtarea más a la derecha
                  : 60, // Costo más a la derecha
            ),
          ],

          // Texto de la subtarea
          Expanded(
            child: GestureDetector(
              onTap: hasSpecialEmoji && subTask.title.startsWith('✅')
                  ? () => _toggleSubTask(subTask)
                  : null,
              child: Text(
                subTask.title,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                  color: subTask.completed
                      ? const Color(0xFF374151).withOpacity(0.6)
                      : const Color(0xFF374151),
                  decoration: subTask.completed
                      ? TextDecoration.lineThrough
                      : null,
                  height: 1.4,
                ),
              ),
            ),
          ),

          // Controles de acción (checkbox, calculadora y basura)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de edición para títulos (📝)
              if (subTask.title.startsWith('📝')) ...[
                GestureDetector(
                  onTap: () => _startEditingTitle(subTask),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    margin: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width > 600 ? 8 : 6,
                      right: 4,
                      top: 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _editingTitleId != null
                          ? const Color(0xFF3B82F6).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.05),
                      border: Border.all(
                        color: _editingTitleId != null
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF374151).withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
              ],

              // Botón de edición para subtareas normales (no de costo)
              if (!subTask.title.startsWith('🟦') &&
                  hasSpecialEmoji &&
                  subTask.title.startsWith('✅')) ...[
                GestureDetector(
                  onTap: () => _startEditingSubTask(subTask),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    margin: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width > 600 ? 8 : 6,
                      right: 4,
                      top: 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _editingSubTaskId == subTask.id
                          ? const Color(0xFF3B82F6).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.05),
                      border: Border.all(
                        color: _editingSubTaskId == subTask.id
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF374151).withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
              ],

              // Botones de operación matemática (solo para costos 🟦)
              if (subTask.title.startsWith('🟦')) ...[
                // Botón de suma (+)
                GestureDetector(
                  onTap: () => _setCalculatorOperation(subTask, '+'),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    margin: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width > 600 ? 8 : 6,
                      right: 4,
                      top: 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _calculatorOperations[subTask.id] == '+'
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.05),
                      border: Border.all(
                        color: _calculatorOperations[subTask.id] == '+'
                            ? const Color(0xFF10B981)
                            : const Color(0xFF374151).withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                ),
                // Botón de resta (-)
                GestureDetector(
                  onTap: () => _setCalculatorOperation(subTask, '-'),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    margin: EdgeInsets.only(
                      left: 2,
                      right: MediaQuery.of(context).size.width > 600 ? 6 : 4,
                      top: 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _calculatorOperations[subTask.id] == '-'
                          ? const Color(0xFFEF4444).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.05),
                      border: Border.all(
                        color: _calculatorOperations[subTask.id] == '-'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF374151).withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '−',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ),
                // Botón de editar
                GestureDetector(
                  onTap: () => _startEditingSegment(subTask),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                    margin: EdgeInsets.only(
                      left: 2,
                      right: MediaQuery.of(context).size.width > 600 ? 6 : 4,
                      top: 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _editingSegmentId == subTask.id
                          ? const Color(0xFF3B82F6).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.05),
                      border: Border.all(
                        color: _editingSegmentId == subTask.id
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF374151).withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
              ],

              // Canequita de basura mejorada
              GestureDetector(
                onTap: () => _deleteSubTask(subTask),
                child: Container(
                  width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                  height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
                  margin: EdgeInsets.only(left: 4, top: 2, bottom: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    border: Border.all(
                      color: const Color(0xFF374151).withOpacity(0.2),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: const Color(0xFFEF4444).withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditingField(SubTask subTask) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✏️ Editando segmento:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🟦', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _editCostController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumberFormatter()],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    hintText: '2.500.000',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '/',
                style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _editDescriptionController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    hintText: 'descripción',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelEditingSegment,
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_editCostController.text.trim().isNotEmpty &&
                      _editDescriptionController.text.trim().isNotEmpty) {
                    _saveEditedSegment();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Función helper para mostrar el cuaderno de marcado
void showNotebook(
  BuildContext context, {
  String? taskId,
  String? taskTitle,
  String? taskDescription,
  DateTime? date,
}) {
  final notebookProvider = context.read<NotebookProvider>();

  late NotebookEntry notebook;
  late String notebookId;
  late String title;
  late bool isTaskNotebook;

  if (taskId != null && taskTitle != null) {
    // Cuaderno de tarea específica
    notebook = notebookProvider.getOrCreateTaskNotebook(taskId, taskTitle);
    notebookId = notebook.id;
    title = taskTitle;
    isTaskNotebook = true;
  } else if (date != null) {
    // Cuaderno del día
    notebook = notebookProvider.getOrCreateDayNotebook(date);
    notebookId = notebook.id;
    title = notebook.title;
    isTaskNotebook = false;
  } else {
    return; // No se pueden crear cuadernos sin parámetros
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.3),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: MediaQuery.of(context).size.width > 600
                ? 600 // Máximo en tablets/desktop
                : MediaQuery.of(context).size.width * 0.9, // 90% en móviles
            height: MediaQuery.of(context).size.height > 800
                ? MediaQuery.of(context).size.height * 0.8
                : MediaQuery.of(context).size.height *
                      0.9, // Más alto en pantallas pequeñas
            child: NotebookScreen(
              notebookId: notebookId,
              title: title,
              description: taskDescription,
              isTaskNotebook: isTaskNotebook,
              date: date,
            ),
          ),
        ),
      ),
    ),
  );
}
