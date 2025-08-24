import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:io';
import 'dart:convert';

import 'text_format_panel.dart';
import 'note.dart';

// Variable global para controlar el Snackbar solo en guardado manual
bool _showSavedSnackbar = false;

// Bandera para controlar el inicio de edición y evitar parpadeo inicial
bool _hasStartedEditing = false;

// Clase auxiliar para simular partes de texto con o sin negrita
class _TextPart {
  final String text;
  final bool bold;
  _TextPart(this.text, this.bold);

  Map<String, dynamic> toJson() => {'text': text, 'bold': bold};
  factory _TextPart.fromJson(Map<String, dynamic> json) =>
      _TextPart(json['text'] ?? '', json['bold'] ?? false);
}

/// =======================
/// PROVIDER: Notas
/// =======================
class NoteProvider extends ChangeNotifier {
  List<Note> notes = [];

  NoteProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notes') ?? '[]';
    final List<dynamic> list = json.decode(data);
    notes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'notes',
      json.encode(notes.map((e) => e.toJson()).toList()),
    );
  }

  void addNote(Note note) {
    notes.insert(0, note);
    saveNotes();
    notifyListeners();
  }

  void updateNote(Note note) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      saveNotes();
      notifyListeners();
    }
  }

  void deleteNote(Note note) {
    notes.removeWhere((n) => n.id == note.id);
    saveNotes();
    notifyListeners();
  }
}

/// ========================================
/// PANTALLA: Edición de nota
/// ========================================
class NoteEditScreen extends StatefulWidget {
// ...existing code...
  final Note note;
  NoteEditScreen({Key? key, required this.note}) : super(key: key);

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen>
    with SingleTickerProviderStateMixin {
  // Para animación de parpadeo
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _hasUnsavedChanges = false;
  int? _editingPartIndex; // Moved to State
  final Map<int, TextEditingController> _partControllers = {}; // Moved to State
  double _titleFontSize = 22;
  static const double _minTitleFontSize = 14;
  static const double _maxTitleFontSize =
      38; // Limite seguro para evitar overflow visual
  TextFormatValue _contentFormat = const TextFormatValue();
  TextFormatValue _lastFormat = const TextFormatValue();

  List<_TextPart> _contentParts = [];
  final TextEditingController _hiddenController = TextEditingController();
  final FocusNode _hiddenFocus = FocusNode();

  late TextEditingController _titleController;
  late TextEditingController _categoriaController;
  late Color _noteColor;
  late String _skin;

  final GlobalKey _noteKey = GlobalKey();
  bool _editingTitle = false;

  /// Fecha y hora legible
  String _formatDateTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (e) {
      return '';
    }
  }

  Future<void> _shareAsText() async {
    // Compartir el texto concatenado de _contentParts
    final text = _contentParts.map((e) => e.text).join('\n');
    await Share.share(text.isEmpty ? 'Nota sin contenido' : text);
  }

  Future<void> _shareAsPdf() async {
    try {
      final pdf = pw.Document();
      final note = widget.note;

      // Calcular márgenes dinámicos
      final double baseMargin = 18.0;
      final double textScaleFactor = 1.2;

      // Margen superior mayor para el título
      double titleMargin = baseMargin * 2;

      // Contenido del PDF
      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.only(
            top: titleMargin,
            bottom: baseMargin,
            left: baseMargin,
            right: baseMargin,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Título
                pw.Text(
                  note.title,
                  style: pw.TextStyle(
                    fontSize: 24 * textScaleFactor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 12),
                // Contenido
                pw.Text(
                  note.contentParts.map((e) => e['text'] ?? '').join('\n'),
                  style: pw.TextStyle(
                    fontSize: 16 * textScaleFactor,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Guardar y compartir
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nota.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: 'nota.pdf')],
        text: _titleController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir como PDF: $e')),
      );
    }
  }

  // Acepta pop opcional para compatibilidad con las llamadas existentes
  void _saveNote({bool pop = false}) {
    final note = widget.note;
    note.title = _titleController.text;
    note.categoria = _categoriaController.text;
    note.date = DateTime.now().toLocal().toString();
    note.color = _noteColor;
    note.skin = _skin.isEmpty ? 'grid' : _skin;
    note.titleFontSize = _titleFontSize;
    // Si hay texto pendiente en el campo de edición, agrégalo como bloque temporal (sin duplicar si ya está al final)
    List<_TextPart> partsToSave = List<_TextPart>.from(_contentParts);
    String pendingText = _hiddenController.text.trim();
    if (pendingText.isNotEmpty) {
      // Si el último bloque ya es igual, no lo dupliques
      if (partsToSave.isEmpty || partsToSave.last.text != pendingText) {
        partsToSave.add(_TextPart(pendingText, _contentFormat.bold));
      }
    }
    note.contentParts = partsToSave.map((e) => e.toJson()).toList();
    context.read<NoteProvider>().updateNote(note);
    // Solo mostrar el Snackbar si se guarda manualmente (desde el botón)
    if (_showSavedSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota guardada'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showSavedSnackbar = false;
    }
    if (pop) {
      Navigator.pop(context);
    }
  }

  Widget _buildIconBox({required Widget icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  @override
  void initState() {
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _blinkController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _blinkController.forward();
      }
    });
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _categoriaController = TextEditingController(text: widget.note.categoria);
    _noteColor = widget.note.color;
    _skin = widget.note.skin.isEmpty ? 'grid' : widget.note.skin;
    _titleFontSize = widget.note.titleFontSize;
    _contentFormat = const TextFormatValue();
    _lastFormat = _contentFormat;

    // Cargar partes desde el modelo
    _contentParts =
        (widget.note.contentParts).map((e) => _TextPart.fromJson(e)).toList();
    _hiddenController.clear();

    // Detectar cambios para activar el color naranja
    _titleController.addListener(_onAnyChange);
    _categoriaController.addListener(_onAnyChange);
    _hiddenController.addListener(_onAnyChange);
  }

  void _onAnyChange() {
    if (!_hasStartedEditing) {
      // Solo activar después de la primera edición real
      if (_titleController.text.isNotEmpty || _categoriaController.text.isNotEmpty || _hiddenController.text.isNotEmpty) {
        _hasStartedEditing = true;
      } else {
        return;
      }
    }
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
        _blinkController.forward();
      });
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _titleController.removeListener(_onAnyChange);
    _categoriaController.removeListener(_onAnyChange);
    _hiddenController.removeListener(_onAnyChange);
    _titleController.dispose();
    _categoriaController.dispose();
    _hiddenController.dispose();
    _hiddenFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double _bottomBarHeight = 72.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _noteColor,
      appBar: AppBar(
        backgroundColor: _noteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Text('⬅️',
              style: TextStyle(fontSize: 24, color: Colors.black)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        title: const Text(
          'Editar nota',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Guardar animado solo el emoji
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                return IconButton(
                  icon: Opacity(
                    opacity: _hasUnsavedChanges ? _blinkAnimation.value : 1.0,
                    child: const Text('💾', style: TextStyle(fontSize: 26)),
                  ),
                  tooltip: 'Guardar',
                  onPressed: () {
                    _showSavedSnackbar = true;
                    setState(() {
                      _hasUnsavedChanges = false;
                    });
                    _blinkController.reset();
                    _saveNote(pop: false);
                  },
                );
              },
            ),
          ),
          // Compartir
          IconButton(
            icon: Image.asset('assets/compartir.png', width: 28, height: 28),
            tooltip: 'Compartir',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.text_fields),
                      title: const Text('Compartir como texto'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _shareAsText();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: const Text('Compartir como PDF'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _shareAsPdf();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          // Opciones
          PopupMenuButton<String>(
            icon: const Text('⚙️',
                style: TextStyle(fontSize: 22, color: Colors.black)),
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'skins':
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => SkinPanel(
                      color: _noteColor,
                      onColorSelected: (c) {
                        setState(() {
                          _noteColor = c;
                          _saveNote(pop: false);
                        });
                      },
                    ),
                  );
                  break;
                case 'delete':
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar nota'),
                      content: const Text(
                          '¿Estás seguro de que deseas eliminar esta nota?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<NoteProvider>()
                                .deleteNote(widget.note);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Eliminar',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'skins', child: Text('Skins y color')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar nota')),
            ],
          ),
        ],
      ),

      // ======= BODY =======
      body: RepaintBoundary(
        key: _noteKey,
        child: Column(
          children: [
            // Cabecera (fecha/categoría)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('⏳',
                        style: TextStyle(fontSize: 16, color: Colors.black)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDateTime(widget.note.date),
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13.5),
                        ),
                        if (_categoriaController.text.isNotEmpty)
                          Row(
                            children: [
                              Text(_categoriaIconStr(_categoriaController.text),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                      shadows: [
                                        Shadow(
                                            blurRadius: 1.5,
                                            color: Colors.black12,
                                            offset: Offset(0, 1))
                                      ])),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _categoriaController.text,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 13.5,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 1.5,
                                          color: Colors.black12,
                                          offset: Offset(0, 1))
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Text('📂',
                        style: TextStyle(fontSize: 18, color: Colors.black)),
                    onPressed: () async {
                      final selected = await showMenu<String>(
                        context: context,
                        position: const RelativeRect.fromLTRB(200, 80, 16, 0),
                        items: const [
                          PopupMenuItem(
                              value: 'Sermón', child: Text('📖  Sermón')),
                          PopupMenuItem(
                              value: 'Estudio Bíblico',
                              child: Text('📚  Estudio Bíblico')),
                          PopupMenuItem(
                              value: 'Reflexión', child: Text('🤔  Reflexión')),
                          PopupMenuItem(
                              value: 'Devocional',
                              child: Text('❤️  Devocional')),
                          PopupMenuItem(
                              value: 'Testimonio',
                              child: Text('🌟  Testimonio')),
                          PopupMenuItem(
                              value: 'Apuntes Generales',
                              child: Text('📓  Apuntes Generales')),
                          PopupMenuItem(
                              value: 'Discipulado',
                              child: Text('🏫  Discipulado')),
                        ],
                      );
                      if (selected != null) {
                        setState(() {
                          _categoriaController.text = selected;
                        });
                      }
                    },
                    tooltip: 'Seleccionar categoría',
                  ),
                ],
              ),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: Column(
                children: [
                  _editingTitle
                      ? TextField(
                          controller: _titleController,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          maxLines: null,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Encabezado',
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                          ),
                          style: TextStyle(
                            fontSize: _titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.done,
                          onChanged: (v) => _saveNote(pop: false),
                          onEditingComplete: () {
                            setState(() => _editingTitle = false);
                            _saveNote(pop: false);
                          },
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() => _editingTitle = true);
                          },
                          child: Center(
                            child: AutoSizeText(
                              _titleController.text.isEmpty
                                  ? 'Encabezado'
                                  : _titleController.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 10,
                              minFontSize: 10,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                            thumbColor: Colors.black,
                            activeTrackColor: Colors.black54,
                            inactiveTrackColor: Colors.black26,
                          ),
                          child: Slider(
                            min: _minTitleFontSize,
                            max: _maxTitleFontSize,
                            value: _titleFontSize.clamp(
                                _minTitleFontSize, _maxTitleFontSize),
                            onChanged: (v) {
                              setState(() {
                                _titleFontSize = v.clamp(
                                    _minTitleFontSize, _maxTitleFontSize);
                              });
                              _saveNote();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contenido con transición + LISTVIEW SCROLL
            Expanded(
              child: TileRevealColorTransition(
                color: _noteColor,
                duration: const Duration(milliseconds: 800),
                rows: 24,
                columns: 48,
                curve: Curves.fastOutSlowIn,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    _bottomBarHeight +
                        MediaQuery.of(context).padding.bottom +
                        16,
                  ),
                  children: [
                    // Texto ya fijado por partes
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(_contentParts.length, (i) {
                        final part = _contentParts[i];
                        if (_editingPartIndex == i) {
                          _partControllers[i] ??=
                              TextEditingController(text: part.text);
                          return Focus(
                            onFocusChange: (hasFocus) {
                              if (!hasFocus) {
                                setState(() {
                                  _contentParts[i] = _TextPart(
                                      _partControllers[i]?.text ?? part.text,
                                      part.bold);
                                  _editingPartIndex = null;
                                  _partControllers.remove(i);
                                });
                                _saveNote();
                              }
                            },
                            child: TextField(
                              controller: _partControllers[i],
                              autofocus: true,
                              maxLines: null,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: part.bold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.black87,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              onSubmitted: (value) {
                                setState(() {
                                  _contentParts[i] =
                                      _TextPart(value, part.bold);
                                  _editingPartIndex = null;
                                  _partControllers.remove(i);
                                });
                                _saveNote();
                              },
                            ),
                          );
                        } else {
                          return LongPressDraggable<int>(
                            data: i,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2.0, horizontal: 4.0),
                                child: Text(
                                  part.text,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: part.bold
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: const SizedBox.shrink(),
                            onDragCompleted: () {},
                            child: DragTarget<int>(
                              onWillAccept: (from) => from != i,
                              onAccept: (from) {
                                setState(() {
                                  final moved = _contentParts.removeAt(from);
                                  _contentParts.insert(i, moved);
                                  _saveNote();
                                });
                              },
                              builder: (context, candidateData, rejectedData) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _editingPartIndex = i;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0, horizontal: 4.0),
                                    child: Text(
                                      part.text,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: part.bold
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      }),
                    ),
                    const SizedBox(height: 8),
                    // Campo de escritura continua
                    Container(
                      decoration: const BoxDecoration(
                        border: Border.fromBorderSide(BorderSide.none),
                        color: Colors.transparent,
                      ),
                      child: TextField(
                        controller: _hiddenController,
                        focusNode: _hiddenFocus,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: Colors.amber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: _contentFormat.bold
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          hintText: 'Escribe aquí... (Enter para nueva línea)',
                          fillColor: Colors.transparent,
                          filled: true,
                        ),
                        onChanged: (v) => _saveNote(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ======= BARRA INFERIOR =======
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
        child: Container(
          height: _bottomBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconBox(
                icon: Image.asset('assets/abc.png', width: 32, height: 32),
                onTap: () async {
                  if (_hiddenController.text.isNotEmpty) {
                    setState(() {
                      _contentParts.add(
                        _TextPart(_hiddenController.text, _contentFormat.bold),
                      );
                      _hiddenController.clear();
                    });
                    _saveNote();
                  }
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Padding(
                      padding: MediaQuery.of(ctx).viewInsets,
                      child: TextFormatPanel(
                        value: _contentFormat,
                        onChanged: (val) =>
                            setState(() => _contentFormat = val),
                        onClose: () => Navigator.pop(ctx),
                      ),
                    ),
                  );
                },
              ),
              _buildIconBox(
                icon: Image.asset('assets/camara.png', width: 32, height: 32),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Foto'),
                      content:
                          const Text('Función de añadir foto próximamente.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK')),
                      ],
                    ),
                  );
                },
              ),
              _buildIconBox(
                icon: Image.asset('assets/IA.png', width: 32, height: 32),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Mapa mental/conceptual'),
                      content:
                          const Text('Función de mapa mental próximamente.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK')),
                      ],
                    ),
                  );
                },
              ),
              // ...existing code...
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================================================
/// Widget para transición de color con CustomPainter
/// =======================================================
class TileRevealColorTransition extends StatefulWidget {
  final Color color;
  final Widget child;
  final int rows;
  final int columns;
  final Duration duration;
  final Curve curve;

  const TileRevealColorTransition({
    super.key,
    required this.color,
    required this.child,
    this.rows = 16,
    this.columns = 32,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeInOutCubic,
  });

  @override
  State<TileRevealColorTransition> createState() =>
      _TileRevealColorTransitionState();
}

class _TileRevealColorTransitionState extends State<TileRevealColorTransition>
    with SingleTickerProviderStateMixin {
  late Color _oldColor;
  late Color _currentColor;
  late AnimationController _controller;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _oldColor = widget.color;
    _currentColor = widget.color;
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant TileRevealColorTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedColor = widget.color.value != _currentColor.value;
    if (changedColor) {
      _oldColor = _currentColor;
      _currentColor = widget.color;
      _animating = true;
      _controller.duration = widget.duration;
      _controller.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _animating = false);
      });
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _RevealPainter(
                  progress: _controller.value,
                  animating: _animating,
                  oldColor: _oldColor,
                  newColor: _currentColor,
                  rows: widget.rows,
                  cols: widget.columns,
                  curve: widget.curve,
                ),
              ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

class _RevealPainter extends CustomPainter {
  final double progress; // 0..1
  final bool animating;
  final Color oldColor;
  final Color newColor;
  final int rows;
  final int cols;
  final Curve curve;

  _RevealPainter({
    required this.progress,
    required this.animating,
    required this.oldColor,
    required this.newColor,
    required this.rows,
    required this.cols,
    required this.curve,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = animating ? oldColor : newColor;
    canvas.drawRect(Offset.zero & size, basePaint);

    if (!animating) return;

    final tileW = size.width / cols;
    final tileH = size.height / rows;
    final maxR = (tileW > tileH ? tileW : tileH) * 0.9;
    final paintNew = Paint()..color = newColor;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final delay = (r + c) / (rows + cols); // 0..1
        final start = delay * 0.7;
        final end = start + 0.3;

        double t;
        if (progress <= start) {
          t = 0.0;
        } else if (progress >= end) {
          t = 1.0;
        } else {
          t = (progress - start) / (end - start);
        }

        final eased = curve.transform(t);

        final cx = (c + 0.5) * tileW;
        final cy = (r + 0.5) * tileH;
        final radius = maxR * eased;

        if (radius > 0) {
          canvas.drawCircle(Offset(cx, cy), radius, paintNew);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevealPainter old) {
    return progress != old.progress ||
        animating != old.animating ||
        oldColor.value != old.oldColor.value ||
        newColor.value != old.newColor.value ||
        rows != old.rows ||
        cols != old.cols ||
        curve != old.curve;
  }
}

/// ===================
/// PANEL: Skins & Color
/// ===================
class SkinPanel extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorSelected;

  const SkinPanel({
    super.key,
    required this.color,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.white,
      Colors.grey.shade50,
      Colors.grey.shade100,
      Colors.grey.shade200,
      Colors.grey.shade300,
      Colors.yellow.shade50,
      Colors.yellow.shade100,
      Colors.yellow.shade200,
      Colors.yellow.shade300,
      Colors.yellow.shade400,
      Colors.yellow.shade500,
      Colors.amber.shade50,
      Colors.amber.shade100,
      Colors.amber.shade200,
      Colors.amber.shade300,
      Colors.amber.shade400,
      Colors.amber.shade500,
      Colors.orange.shade50,
      Colors.orange.shade100,
      Colors.orange.shade200,
      Colors.orange.shade300,
      Colors.orange.shade400,
      Colors.orange.shade500,
      Colors.pink.shade50,
      Colors.pink.shade100,
      Colors.pink.shade200,
      Colors.pink.shade300,
      Colors.pink.shade400,
      Colors.pink.shade500,
      Colors.purple.shade50,
      Colors.purple.shade100,
      Colors.purple.shade200,
      Colors.purple.shade300,
      Colors.purple.shade400,
      Colors.purple.shade500,
      Colors.deepPurple.shade50,
      Colors.deepPurple.shade100,
      Colors.deepPurple.shade200,
      Colors.deepPurple.shade300,
      Colors.deepPurple.shade400,
      Colors.deepPurple.shade500,
      Colors.blue.shade50,
      Colors.blue.shade100,
      Colors.blue.shade200,
      Colors.blue.shade300,
      Colors.blue.shade400,
      Colors.blue.shade500,
      Colors.lightBlue.shade50,
      Colors.lightBlue.shade100,
      Colors.lightBlue.shade200,
      Colors.lightBlue.shade300,
      Colors.lightBlue.shade400,
      Colors.lightBlue.shade500,
      Colors.cyan.shade50,
      Colors.cyan.shade100,
      Colors.cyan.shade200,
      Colors.cyan.shade300,
      Colors.cyan.shade400,
      Colors.cyan.shade500,
      Colors.indigo.shade50,
      Colors.indigo.shade100,
      Colors.indigo.shade200,
      Colors.indigo.shade300,
      Colors.indigo.shade400,
      Colors.indigo.shade500,
      Colors.green.shade50,
      Colors.green.shade100,
      Colors.green.shade200,
      Colors.green.shade300,
      Colors.green.shade400,
      Colors.green.shade500,
      Colors.lime.shade50,
      Colors.lime.shade100,
      Colors.lime.shade200,
      Colors.lime.shade300,
      Colors.lime.shade400,
      Colors.lime.shade500,
      Colors.teal.shade50,
      Colors.teal.shade100,
      Colors.teal.shade200,
      Colors.teal.shade300,
      Colors.teal.shade400,
      Colors.teal.shade500,
      Colors.brown.shade50,
      Colors.brown.shade100,
      Colors.brown.shade200,
      Colors.brown.shade300,
      Colors.brown.shade400,
      Colors.brown.shade500,
      const Color(0xFFf6d365),
      const Color(0xFFfda085),
      const Color(0xFFfbc2eb),
      const Color(0xFFa1c4fd),
      const Color(0xFFc2e9fb),
      const Color(0xFFd4fc79),
      const Color(0xFF96e6a1),
      const Color(0xFFf7797d),
      const Color(0xFFe0c3fc),
      const Color(0xFF8fd3f4),
      const Color(0xFFfcb69f),
      const Color(0xFFffecd2),
      const Color(0xFFa8edea),
      const Color(0xFFfed6e3),
      const Color(0xFFcfd9df),
      const Color(0xFFe2d1c3),
      const Color(0xFFf5f7fa),
      const Color(0xFFc9ffbf),
      const Color(0xFFffafbd),
      const Color(0xFFb2fefa),
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Color de fondo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                const minBox = 20.0;
                const maxBox = 32.0;
                int crossAxisCount = (maxWidth / (minBox + 6)).floor();
                double boxSize =
                    (maxWidth - (crossAxisCount - 1) * 6) / crossAxisCount;
                if (boxSize > maxBox) boxSize = maxBox;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: colors.length,
                  itemBuilder: (ctx, i) =>
                      _buildColorOption(ctx, colors[i], color, size: boxSize),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, Color c, Color selected,
      {double size = 40}) {
    final isSelected = c.value == selected.value;
    return GestureDetector(
      onTap: () {
        onColorSelected(c);
        Navigator.pop(context);
      },
      child: AnimatedScale(
        scale: isSelected ? 1.22 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c,
            border: Border.all(
              color: isSelected ? Colors.amber : Colors.grey.shade400,
              width: isSelected ? 3.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.18),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }
}

// Devuelve el emoji de la categoría como string
String _categoriaIconStr(String categoria) {
  switch (categoria) {
    case 'Sermón':
      return '📖';
    case 'Estudio Bíblico':
      return '📚';
    case 'Reflexión':
      return '🤔';
    case 'Devocional':
      return '❤️';
    case 'Testimonio':
      return '🌟';
    case 'Apuntes Generales':
      return '📓';
    case 'Discipulado':
      return '🏫';
    default:
      return '';
  }
}
