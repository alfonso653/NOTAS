import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import 'note.dart';
import 'note_provider.dart';
import 'mindmap_model.dart';
import 'mindmap_board.dart';

/// Tipo de item combinado que puede convertirse en nodo
enum _ItemKind { topic, floating, paragraph }

/// Item combinado (tema inteligente, texto flotante o párrafo/linea)
class _CombinedItem {
  final String id;
  final String text;
  final _ItemKind kind;
  const _CombinedItem({
    required this.id,
    required this.text,
    required this.kind,
  });
}

class MindMapFromNoteScreen extends StatefulWidget {
  final Note note;
  const MindMapFromNoteScreen({Key? key, required this.note}) : super(key: key);

  @override
  State<MindMapFromNoteScreen> createState() => _MindMapFromNoteScreenState();
}

class _MindMapFromNoteScreenState extends State<MindMapFromNoteScreen> {
  late List<MindMapNode> nodes;
  late List<MindMapConnection> connections;

  /// Colores por nodo (id -> Color)
  final Map<String, Color> nodeColors = {};

  // 📈 EVOLUCIÓN TEMPORAL
  String?
      _lastContentHash; // hash GUARDADO en el root la última vez que se persistió
  final Set<String> _newTopics = <String>{};
  final Map<String, DateTime> _topicCreationTime = <String, DateTime>{};

  @override
  void initState() {
    super.initState();

    // --- Cargar nodos previos (posiciones + colores) y contentHash guardado en root ---
    final prevNodes = <String, MindMapNode>{};
    String? savedContentHash;

    if (widget.note.mindMapNodes != null) {
      for (final e in widget.note.mindMapNodes!) {
        prevNodes[e['id']] = MindMapNode(
          id: e['id'],
          text: e['text'],
          position: Offset(
            (e['x'] as num).toDouble(),
            (e['y'] as num).toDouble(),
          ),
          children:
              (e['children'] as List?)?.map((c) => c.toString()).toList() ??
                  <String>[],
        );
        if (e['color'] != null) {
          final intVal = (e['color'] as num).toInt();
          nodeColors[e['id']] = Color(intVal);
        }
        if ((e['id'] == 'root') && e['contentHash'] != null) {
          savedContentHash = (e['contentHash'] as Object).toString();
        }
      }
    }

    _initializeTemporalEvolution(savedContentHash: savedContentHash);

    // Generamos SIEMPRE (conserva posiciones por id estable)
    nodes = _generateIntelligentNodes(prevNodes);
    connections = _generateConnections(nodes);

    // Guardar el estado inicial (incluye contentHash en root)
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveMindMap());
  }

  /// Si la nota inyectada en el widget cambia en caliente, revalidamos.
  @override
  void didUpdateWidget(covariant MindMapFromNoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    String? savedContentHash;
    final prevNodes = <String, MindMapNode>{};

    if (widget.note.mindMapNodes != null) {
      for (final e in widget.note.mindMapNodes!) {
        prevNodes[e['id']] = MindMapNode(
          id: e['id'],
          text: e['text'],
          position: Offset(
            (e['x'] as num).toDouble(),
            (e['y'] as num).toDouble(),
          ),
          children:
              (e['children'] as List?)?.map((c) => c.toString()).toList() ??
                  <String>[],
        );
        if ((e['id'] == 'root') && e['contentHash'] != null) {
          savedContentHash = (e['contentHash'] as Object).toString();
        }
      }
    }

    _initializeTemporalEvolution(savedContentHash: savedContentHash);

    final String currentContent = _extractFullTextContent();
    final String currentHash = _generateContentHash(currentContent);

    if (_lastContentHash != currentHash) {
      setState(() {
        nodes = _generateIntelligentNodes(prevNodes);
        connections = _generateConnections(nodes);
        _lastContentHash = currentHash;
      });
      _saveMindMap();
      if (mounted && _newTopics.isNotEmpty) {
        _showNewTopicsNotification();
      }
    }
  }

  // ====== 🔐 IDs ESTABLES (evita descalibración por reordenamientos) ======
  int _djb2Hash(String s) {
    var hash = 5381;
    for (final cu in s.codeUnits) {
      hash = ((hash << 5) + hash) + cu;
    }
    return hash & 0x7fffffff;
  }

  String _stableId(String prefix, String text, {int? occurrence}) {
    final norm = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final h = _djb2Hash(norm).toRadixString(36);
    // ✅ usar llaves para evitar que Dart lea "$h__" como "h__"
    return occurrence == null
        ? '${prefix}_$h'
        : '${prefix}_${h}__${occurrence}';
  }

  // 🧠 GENERADOR DE NODOS INTELIGENTES
  List<MindMapNode> _generateIntelligentNodes(
    Map<String, MindMapNode> prevNodes,
  ) {
    final result = <MindMapNode>[];

    // Nodo raíz
    const rootId = 'root';
    final String rootText =
        widget.note.title.isEmpty ? 'Mi Nota' : widget.note.title;
    final MindMapNode rootNode = (prevNodes[rootId]?.copyWith(
          text: rootText,
          children: const <String>[],
        )) ??
        MindMapNode(
          id: rootId,
          text: rootText,
          position: const Offset(200, 250),
          children: <String>[],
        );
    result.add(rootNode);

    // 🧠 ANÁLISIS INTELIGENTE DE CONTENIDO + ENTRADAS DE PÁRRAFOS + FLOTANTES
    final String fullContent = _extractFullTextContent();
    final List<String> intelligentTopics =
        _analyzeContentForTopics(fullContent);
    final List<String> paragraphEntries = _extractParagraphEntries();

    // Flotantes normalizados
    final List<Map<String, dynamic>> floatingTexts =
        (widget.note.floatingTexts ?? <Map<String, dynamic>>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    // Si no hay nada, fallback
    if (intelligentTopics.isEmpty &&
        floatingTexts.isEmpty &&
        paragraphEntries.isEmpty) {
      return _generateFallbackNodes(prevNodes, result);
    }

    // 🔄 Construir lista combinada (temas + flotantes + párrafos) con IDs ESTABLES
    final combined = <_CombinedItem>[];

    // Temas inteligentes
    for (final topic in intelligentTopics) {
      final id = _stableId('topic', topic);
      combined.add(_CombinedItem(id: id, text: topic, kind: _ItemKind.topic));
    }

    // Flotantes
    for (final ftx in floatingTexts) {
      final full = (ftx['text'] ?? '').toString().trim();
      if (full.isEmpty) continue;
      final id = _stableId('floating', full);
      combined.add(_CombinedItem(id: id, text: full, kind: _ItemKind.floating));
    }

    // Párrafos / líneas (un nodo por línea no vacía)
    final counts = <String, int>{};
    for (final entry in paragraphEntries) {
      final normKey =
          entry.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final occ = (counts[normKey] ?? 0);
      counts[normKey] = occ + 1;

      final id = _stableId('para', entry, occurrence: occ);
      combined
          .add(_CombinedItem(id: id, text: entry, kind: _ItemKind.paragraph));
    }

    // 📏 Distribución uniforme en círculo
    final int totalNodes = combined.length;
    final double baseRadius = 180;
    final double radius =
        totalNodes <= 10 ? baseRadius : baseRadius + (totalNodes - 10) * 8.0;
    const double startAngle = -math.pi / 2; // Arriba

    for (int i = 0; i < combined.length; i++) {
      final item = combined[i];
      final angle = startAngle + (2 * math.pi * i / totalNodes);

      // Respetar posición previa si existe (mismo id)
      final prev = prevNodes[item.id];

      // Texto a mostrar
      String displayText = item.text;
      if (item.kind == _ItemKind.floating && displayText.length > 30) {
        displayText = '${displayText.substring(0, 30)}...';
      }

      final node = MindMapNode(
        id: item.id,
        text: displayText,
        position: prev?.position ??
            Offset(
              rootNode.position.dx + radius * math.cos(angle),
              rootNode.position.dy + radius * math.sin(angle),
            ),
        children: const <String>[],
      );

      result.add(node);

      // ⏱️ marca tiempo de creación si es nuevo
      _topicCreationTime.putIfAbsent(item.id, () => DateTime.now());

      // 🎨 Color por tipo
      if (item.kind == _ItemKind.floating) {
        nodeColors.putIfAbsent(item.id, () => const Color(0xFF00BCD4)); // cian
      } else if (item.kind == _ItemKind.topic) {
        nodeColors.putIfAbsent(item.id, () => _getThemeColor(item.text));
      } else {
        // párrafo / línea: blanco
        nodeColors.putIfAbsent(item.id, () => Colors.white);
      }
    }

    // Hijos del root = todos los nodos (temas + flotantes + párrafos)
    final childrenIds = result.skip(1).map((n) => n.id).toList();
    final rootIndex = result.indexWhere((n) => n.id == 'root');
    if (rootIndex != -1) {
      result[rootIndex] = result[rootIndex].copyWith(children: childrenIds);
    }

    // Color por defecto del root si no existe
    nodeColors.putIfAbsent('root', () => const Color(0xFF6C63FF));

    // Actualizamos el hash actual (para guardarlo en root)
    _lastContentHash = _generateContentHash(_extractFullTextContent());

    return result;
  }

  // 🧠 EXTRACTOR DE CONTENIDO COMPLETO (para hashing)
  String _extractFullTextContent() {
    final buffer = StringBuffer();

    if (widget.note.title.isNotEmpty) {
      buffer.writeln(widget.note.title);
    }

    for (final part in widget.note.contentParts) {
      final isImage = (part['isImage'] ?? false) == true;
      if (!isImage) {
        final text = (part['text'] ?? '').toString().trim();
        if (text.isNotEmpty) buffer.writeln(text);
      }
    }

    final ftList = widget.note.floatingTexts;
    if (ftList != null) {
      for (final floatingText in ftList) {
        final text = (floatingText['text'] ?? '').toString().trim();
        if (text.isNotEmpty) buffer.writeln(text);
      }
    }

    return buffer.toString().trim();
  }

  // 🧵 EXTRACTOR DE PÁRRAFOS/LÍNEAS PARA NODOS (uno por línea)
  List<String> _extractParagraphEntries() {
    final entries = <String>[];

    for (final part in widget.note.contentParts) {
      final isImage = (part['isImage'] ?? false) == true;
      if (isImage) continue;

      final raw = (part['text'] ?? '').toString();
      if (raw.trim().isEmpty) continue;

      // Cortar por líneas (permite párrafos y bullets)
      final lines = raw.split(RegExp(r'\r?\n'));
      for (var line in lines) {
        var s = line.trim();
        if (s.isEmpty) continue;

        // Quitar bullets si hay
        s = s.replaceFirst(RegExp(r'^(\s*[-*•]\s+|\s*\d+\.\s+)'), '');

        if (s.trim().isEmpty) continue;

        entries.add(s);
      }
    }

    return entries;
  }

  // 🧠 ANALIZADOR INTELIGENTE DE TEMAS
  List<String> _analyzeContentForTopics(String content) {
    if (content.isEmpty) return [];

    final topics = <String>[];
    final words = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúüñ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    final Map<String, List<String>> themeKeywords = {
      'Fe y Creencias': [
        'dios',
        'jesús',
        'cristo',
        'señor',
        'padre',
        'espíritu',
        'santo',
        'fe',
        'creer',
        'iglesia',
        'biblia'
      ],
      'Oración y Adoración': [
        'oración',
        'orar',
        'adorar',
        'alabar',
        'adoración',
        'alabanza',
        'culto',
        'bendición'
      ],
      'Amor y Relaciones': [
        'amor',
        'amar',
        'familia',
        'hermanos',
        'prójimo',
        'matrimonio',
        'hijos',
        'padres'
      ],
      'Enseñanzas': [
        'enseñar',
        'aprender',
        'lección',
        'sabiduría',
        'conocimiento',
        'verdad',
        'palabra'
      ],
      'Valores Cristianos': [
        'perdón',
        'perdonar',
        'paciencia',
        'humildad',
        'servir',
        'servicio',
        'bondad',
        'paz'
      ],
      'Vida Espiritual': [
        'crecimiento',
        'madurez',
        'caminar',
        'seguir',
        'discípulo',
        'testimonio',
        'fruto'
      ],
      'Esperanza y Futuro': [
        'esperanza',
        'promesa',
        'futuro',
        'eternidad',
        'cielo',
        'reino',
        'salvación'
      ],
    };

    final Map<String, int> themeScores = {};
    for (final entry in themeKeywords.entries) {
      final theme = entry.key;
      final keywords = entry.value;
      int score = 0;
      for (final keyword in keywords) {
        score += words.where((w) => w.contains(keyword)).length;
      }
      if (score > 0) themeScores[theme] = score;
    }

    final sortedThemes = themeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topics.addAll(sortedThemes.take(6).map((e) => e.key));

    final specificConcepts = _extractSpecificConcepts(content);
    topics.addAll(specificConcepts.take(3));

    if (topics.length < 4) {
      final keyPhrases = _extractKeyPhrases(content);
      final int needed = math.max(0, 5 - topics.length);
      topics.addAll(keyPhrases.take(needed));
    }

    return topics.take(8).toList(); // Máximo 8 nodos principales
  }

  // 🔍 EXTRACTOR DE CONCEPTOS ESPECÍFICOS
  List<String> _extractSpecificConcepts(String content) {
    final concepts = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final properNouns = RegExp(r'\b[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]+\b')
          .allMatches(line)
          .map((m) => m.group(0)!)
          .where((w) => w.length > 3)
          .toList();
      concepts.addAll(properNouns);

      if (line.contains(RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}')) ||
          line.contains(RegExp(r'\d{1,2}\s+de\s+\w+'))) {
        concepts.add('Fechas Importantes');
      }
    }
    return concepts.toSet().take(4).toList();
  }

  // 📝 EXTRACTOR DE FRASES CLAVE
  List<String> _extractKeyPhrases(String content) {
    final phrases = <String>[];
    final sentences = content.split(RegExp(r'[.!?]+'));

    for (final sentence in sentences) {
      final cleanSentence = sentence.trim();
      if (cleanSentence.length > 20 && cleanSentence.length < 60) {
        final words = cleanSentence.split(' ').take(4).join(' ');
        if (words.isNotEmpty) phrases.add(words);
      }
    }
    return phrases.take(5).toList();
  }

  // 🎨 COLORES INTELIGENTES POR TIPO DE TEMA
  Color _getThemeColor(String topic) {
    if (_newTopics.contains(topic)) {
      return const Color(0xFFFF6B6B); // Rojo brillante para nuevos
    }

    final Map<String, Color> themeColors = {
      'Fe y Creencias': const Color(0xFF4CAF50),
      'Oración y Adoración': const Color(0xFF9C27B0),
      'Amor y Relaciones': const Color(0xFFE91E63),
      'Enseñanzas': const Color(0xFF2196F3),
      'Valores Cristianos': const Color(0xFFFF9800),
      'Vida Espiritual': const Color(0xFF00BCD4),
      'Esperanza y Futuro': const Color(0xFFFFEB3B),
    };

    for (final entry in themeColors.entries) {
      if (topic.contains(entry.key)) return entry.value;
    }

    if (topic.contains('Fechas') || topic.contains('Tiempo')) {
      return const Color(0xFF795548);
    }

    final colors = [
      const Color(0xFFFFCDD2),
      const Color(0xFFC8E6C9),
      const Color(0xFFBBDEFB),
      const Color(0xFFFFF9C4),
      const Color(0xFFE1BEE7),
    ];
    return colors[topic.hashCode % colors.length];
  }

  // 🔄 MÉTODO FALLBACK (comportamiento anterior)
  List<MindMapNode> _generateFallbackNodes(
      Map<String, MindMapNode> prevNodes, List<MindMapNode> result) {
    final textParts = widget.note.contentParts.where((p) {
      final isImage = (p['isImage'] ?? false) == true;
      final text = (p['text'] ?? '').toString().trim();
      return !isImage && text.isNotEmpty;
    }).toList();

    final double radius = 160;
    final total = textParts.isEmpty ? 1 : textParts.length;
    final rootNode = result.first;

    int idx = 0;
    for (final part in textParts) {
      final text = (part['text'] ?? '').toString().trim();
      final id = 'n$idx';
      final angle = 2 * math.pi * idx / total;

      final prev = prevNodes[id];
      final node = MindMapNode(
        id: id,
        text: text.length > 40 ? '${text.substring(0, 40)}...' : text,
        position: prev?.position ??
            Offset(
              rootNode.position.dx + radius * math.cos(angle),
              rootNode.position.dy + radius * math.sin(angle),
            ),
        children: const <String>[],
      );

      result.add(node);
      idx++;
      nodeColors.putIfAbsent(id, () => Colors.white);
    }

    final childrenIds = result.skip(1).map((n) => n.id).toList();
    final rootIndex = result.indexWhere((n) => n.id == 'root');
    if (rootIndex != -1) {
      result[rootIndex] = result[rootIndex].copyWith(children: childrenIds);
    }

    nodeColors.putIfAbsent('root', () => Colors.white);
    return result;
  }

  List<MindMapConnection> _generateConnections(List<MindMapNode> nodes) {
    if (nodes.isEmpty) return <MindMapConnection>[];
    final root =
        nodes.firstWhere((n) => n.id == 'root', orElse: () => nodes.first);
    return root.children
        .map((id) =>
            MindMapConnection(fromId: root.id, toId: id, color: Colors.indigo))
        .toList();
  }

  // 📈 INICIALIZAR EVOLUCIÓN TEMPORAL
  void _initializeTemporalEvolution({String? savedContentHash}) {
    if (widget.note.mindMapNodes != null) {
      for (final nodeData in widget.note.mindMapNodes!) {
        final id = nodeData['id'] as String;
        final creationTime = nodeData['creationTime'];
        if (creationTime != null) {
          _topicCreationTime[id] = DateTime.parse(creationTime as String);
        }
      }
    }
    _lastContentHash =
        savedContentHash ?? _generateContentHash(_extractFullTextContent());
  }

  // 📊 GENERAR HASH DEL CONTENIDO
  String _generateContentHash(String content) {
    return content.replaceAll(RegExp(r'\s+'), ' ').trim().hashCode.toString();
  }

  // 🔍 DETECTAR CONTENIDO NUEVO
  bool _hasContentChanged() {
    final currentContent = _extractFullTextContent();
    final currentHash = _generateContentHash(currentContent);
    return currentHash != _lastContentHash;
  }

  // 🆕 DETECTAR TEMAS NUEVOS
  void _detectNewTopics(
      List<String> currentTopics, List<String> previousTopics) {
    _newTopics.clear();
    for (final topic in currentTopics) {
      if (!previousTopics.contains(topic)) {
        _newTopics.add(topic);
      }
    }
  }

  // ⚡ ACTUALIZACIÓN INTELIGENTE DEL MAPA (para botón manual)
  void _updateMindMapIfNeeded() {
    if (_hasContentChanged()) {
      final currentContent = _extractFullTextContent();
      final currentTopics = _analyzeContentForTopics(currentContent);
      final previousTopics =
          nodes.where((n) => n.id != 'root').map((n) => n.text).toList();

      _detectNewTopics(currentTopics, previousTopics);

      final prevNodes = <String, MindMapNode>{};
      for (final node in nodes) {
        prevNodes[node.id] = node;
      }

      setState(() {
        nodes = _generateIntelligentNodes(prevNodes);
        connections = _generateConnections(nodes);
      });

      _lastContentHash = _generateContentHash(currentContent);
      _saveMindMap();

      if (_newTopics.isNotEmpty) {
        _showNewTopicsNotification();
      }
    }
  }

  // 🎉 NOTIFICACIÓN DE TEMAS NUEVOS
  void _showNewTopicsNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🆕 ${_newTopics.length} temas nuevos agregados'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: _highlightNewTopics,
        ),
      ),
    );
  }

  // ✨ RESALTAR TEMAS NUEVOS
  void _highlightNewTopics() {
    // Hook para futuras animaciones
  }

  void _saveMindMap() {
    try {
      widget.note.mindMapNodes = nodes.map((n) {
        final map = {
          'id': n.id,
          'text': n.text,
          'x': n.position.dx.isFinite ? n.position.dx : 0.0,
          'y': n.position.dy.isFinite ? n.position.dy : 0.0,
          'children': List<String>.from(n.children),
          'color': nodeColors[n.id]?.value,
          'creationTime': _topicCreationTime[n.id]?.toIso8601String(),
        };
        if (n.id == 'root') {
          map['contentHash'] = _lastContentHash;
        }
        return map;
      }).toList();

      widget.note.mindMapConnections = connections
          .map((c) => {
                'fromId': c.fromId,
                'toId': c.toId,
              })
          .toList();

      Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
    } catch (e) {
      // ignore: avoid_print
      print('Error saving mind map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el mapa mental'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📊 MOSTRAR INFORMACIÓN TEMPORAL
  Widget _buildTemporalInfo() {
    if (_newTopics.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_new, color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Text(
            '${_newTopics.length} temas nuevos detectados',
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Mapa Mental IA'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '📈 Sincronizar cambios',
            onPressed: _updateMindMapIfNeeded,
            icon: const Icon(Icons.sync, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Regenerar con IA',
            onPressed: () {
              setState(() {
                _newTopics.clear();
                nodes = _generateIntelligentNodes({});
                connections = _generateConnections(nodes);
              });
              _lastContentHash =
                  _generateContentHash(_extractFullTextContent());
              _saveMindMap();
            },
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saveMindMap,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F8FF),
              Color(0xFFE8E8FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            MindMapBoard(
              key: ValueKey('intelligent_board_${widget.note.id}'),
              nodes: nodes,
              connections: connections,
              nodeColors: nodeColors,
              onNodeMoved: (updatedNode) {
                setState(() {
                  final idx = nodes.indexWhere((n) => n.id == updatedNode.id);
                  if (idx != -1) {
                    nodes[idx] = updatedNode;
                  }
                  _saveMindMap();
                });
              },
              onNodeColorChanged: (nodeId, color) {
                setState(() {
                  nodeColors[nodeId] = color;
                  _saveMindMap();
                });
              },
              onNodeTextChanged: (nodeId, newText) {
                setState(() {
                  final idx = nodes.indexWhere((n) => n.id == nodeId);
                  if (idx != -1) {
                    nodes[idx] = nodes[idx].copyWith(text: newText);
                    _saveMindMap();
                  }
                });
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _buildTemporalInfo(),
            ),
          ],
        ),
      ),
    );
  }
}
