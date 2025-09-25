import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import 'note.dart';
import 'note_provider.dart';
import 'mindmap_model.dart';
import 'mindmap_board.dart';

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
  String? _lastContentHash;
  final Set<String> _newTopics = <String>{};
  final Map<String, DateTime> _topicCreationTime = <String, DateTime>{};

  @override
  void initState() {
    super.initState();

    // Cargar nodos previos de la nota (posiciones + colores)
    final prevNodes = <String, MindMapNode>{};
    if (widget.note.mindMapNodes != null) {
      for (final e in widget.note.mindMapNodes!) {
        // Posiciones y texto previos
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
        // Color previo si existe
        if (e['color'] != null) {
          final intVal = (e['color'] as num).toInt();
          nodeColors[e['id']] = Color(intVal);
        }
      }
    }

    // 📈 INICIALIZAR EVOLUCIÓN TEMPORAL
    _initializeTemporalEvolution();

    nodes = _generateIntelligentNodes(prevNodes);
    connections = _generateConnections(nodes);

    // Guardar el estado inicial (asegura persistencia al abrir)
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveMindMap());
  }

  // 🧠 GENERADOR DE NODOS INTELIGENTES
  List<MindMapNode> _generateIntelligentNodes(
      Map<String, MindMapNode> prevNodes) {
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

    // 🧠 ANÁLISIS INTELIGENTE DE CONTENIDO
    final String fullContent = _extractFullTextContent();
    final List<String> intelligentTopics =
        _analyzeContentForTopics(fullContent);

    // Si no hay temas inteligentes, usar método anterior como fallback
    if (intelligentTopics.isEmpty) {
      return _generateFallbackNodes(prevNodes, result);
    }

    // Generar nodos basados en análisis inteligente
    final double radius = 180;
    final total = intelligentTopics.length;

    for (int idx = 0; idx < intelligentTopics.length; idx++) {
      final topic = intelligentTopics[idx];
      final id = 'topic_$idx';
      final angle = 2 * math.pi * idx / total;

      final prev = prevNodes[id];
      final node = MindMapNode(
        id: id,
        text: topic,
        position: prev?.position ??
            Offset(
              rootNode.position.dx + radius * math.cos(angle),
              rootNode.position.dy + radius * math.sin(angle),
            ),
        children: <String>[],
      );

      result.add(node);

      // 🎨 COLORES INTELIGENTES POR TIPO DE TEMA
      nodeColors.putIfAbsent(id, () => _getThemeColor(topic));
    }

    // Hijos del root = todos los nodos de temas
    final childrenIds = result.skip(1).map((n) => n.id).toList();
    final rootIndex = result.indexWhere((n) => n.id == 'root');
    if (rootIndex != -1) {
      result[rootIndex] = result[rootIndex].copyWith(children: childrenIds);
    }

    // Color por defecto del root si no existe
    nodeColors.putIfAbsent('root', () => const Color(0xFF6C63FF));

    return result;
  }

  // 🧠 EXTRACTOR DE CONTENIDO COMPLETO
  String _extractFullTextContent() {
    final buffer = StringBuffer();

    // Agregar título si existe
    if (widget.note.title.isNotEmpty) {
      buffer.writeln(widget.note.title);
    }

    // Extraer TODO el texto de todos los nodos
    for (final part in widget.note.contentParts) {
      final isImage = (part['isImage'] ?? false) == true;
      if (!isImage) {
        final text = (part['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }
    }

    return buffer.toString().trim();
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

    // 📊 PALABRAS CLAVE RELEVANTES (temática cristiana/espiritual)
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

    // 🎯 DETECTAR TEMAS POR FRECUENCIA DE PALABRAS CLAVE
    final Map<String, int> themeScores = {};

    for (final entry in themeKeywords.entries) {
      final theme = entry.key;
      final keywords = entry.value;
      int score = 0;

      for (final keyword in keywords) {
        score += words.where((w) => w.contains(keyword)).length;
      }

      if (score > 0) {
        themeScores[theme] = score;
      }
    }

    // 📈 ORDENAR POR RELEVANCIA Y TOMAR LOS TOP 6
    final sortedThemes = themeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    topics.addAll(sortedThemes.take(6).map((e) => e.key));

    // 🔍 DETECTAR CONCEPTOS ESPECÍFICOS (nombres propios, fechas, lugares)
    final specificConcepts = _extractSpecificConcepts(content);
    topics.addAll(specificConcepts.take(3));

    // 📝 SI HAY POCOS TEMAS, AGREGAR FRASES CLAVE
    if (topics.length < 4) {
      final keyPhrases = _extractKeyPhrases(content);
      topics.addAll(keyPhrases.take(5 - topics.length));
    }

    return topics.take(8).toList(); // Máximo 8 nodos principales
  }

  // 🔍 EXTRACTOR DE CONCEPTOS ESPECÍFICOS
  List<String> _extractSpecificConcepts(String content) {
    final concepts = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      // Detectar nombres propios (palabras que empiezan con mayúscula)
      final properNouns = RegExp(r'\b[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]+\b')
          .allMatches(line)
          .map((m) => m.group(0)!)
          .where((w) => w.length > 3)
          .toList();

      concepts.addAll(properNouns);

      // Detectar fechas
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
        // Tomar las primeiras palabras como concepto
        final words = cleanSentence.split(' ').take(4).join(' ');
        if (words.isNotEmpty) {
          phrases.add(words);
        }
      }
    }

    return phrases.take(5).toList();
  }

  // 🎨 COLORES INTELIGENTES POR TIPO DE TEMA
  Color _getThemeColor(String topic) {
    // 🆕 COLORES ESPECIALES PARA TEMAS NUEVOS
    if (_newTopics.contains(topic)) {
      return const Color(0xFFFF6B6B); // Rojo brillante para nuevos
    }

    // ⏰ COLORES POR ANTIGÜEDAD
    final creationTime = _topicCreationTime[topic];
    if (creationTime != null) {
      final daysSinceCreation = DateTime.now().difference(creationTime).inDays;
      if (daysSinceCreation <= 1) {
        return const Color(0xFFFF9500); // Naranja para recientes (1 día)
      } else if (daysSinceCreation <= 7) {
        return const Color(0xFFFFD93D); // Amarillo para una semana
      }
    }

    final Map<String, Color> themeColors = {
      'Fe y Creencias': const Color(0xFF4CAF50), // Verde
      'Oración y Adoración': const Color(0xFF9C27B0), // Púrpura
      'Amor y Relaciones': const Color(0xFFE91E63), // Rosa
      'Enseñanzas': const Color(0xFF2196F3), // Azul
      'Valores Cristianos': const Color(0xFFFF9800), // Naranja
      'Vida Espiritual': const Color(0xFF00BCD4), // Cian
      'Esperanza y Futuro': const Color(0xFFFFEB3B), // Amarillo
    };

    // Buscar color por tema específico
    for (final entry in themeColors.entries) {
      if (topic.contains(entry.key)) {
        return entry.value;
      }
    }

    // Colores por defecto para conceptos específicos
    if (topic.contains('Fechas') || topic.contains('Tiempo')) {
      return const Color(0xFF795548); // Marrón
    }

    // Color aleatorio suave para otros conceptos
    final colors = [
      const Color(0xFFFFCDD2), // Rosa claro
      const Color(0xFFC8E6C9), // Verde claro
      const Color(0xFFBBDEFB), // Azul claro
      const Color(0xFFFFF9C4), // Amarillo claro
      const Color(0xFFE1BEE7), // Púrpura claro
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
        children: <String>[],
      );

      result.add(node);
      idx++;
      nodeColors.putIfAbsent(id, () => Colors.white);
    }

    // Hijos del root = todos los nodos no raíz
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
  void _initializeTemporalEvolution() {
    final currentContent = _extractFullTextContent();
    _lastContentHash = _generateContentHash(currentContent);

    // Cargar tiempos de creación previos si existen
    if (widget.note.mindMapNodes != null) {
      for (final nodeData in widget.note.mindMapNodes!) {
        final id = nodeData['id'] as String;
        final creationTime = nodeData['creationTime'];
        if (creationTime != null) {
          _topicCreationTime[id] = DateTime.parse(creationTime as String);
        }
      }
    }
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
    final now = DateTime.now();

    for (final topic in currentTopics) {
      if (!previousTopics.contains(topic)) {
        _newTopics.add(topic);
        _topicCreationTime[topic] = now;
      }
    }
  }

  // ⚡ ACTUALIZACIÓN INTELIGENTE DEL MAPA
  void _updateMindMapIfNeeded() {
    if (_hasContentChanged()) {
      final currentContent = _extractFullTextContent();
      final currentTopics = _analyzeContentForTopics(currentContent);
      final previousTopics =
          nodes.where((n) => n.id != 'root').map((n) => n.text).toList();

      // Detectar temas nuevos
      _detectNewTopics(currentTopics, previousTopics);

      // Regenerar con preservación de posiciones
      final prevNodes = <String, MindMapNode>{};
      for (final node in nodes) {
        prevNodes[node.id] = node;
      }

      setState(() {
        nodes = _generateIntelligentNodes(prevNodes);
        connections = _generateConnections(nodes);
      });

      // Actualizar hash del contenido
      _lastContentHash = _generateContentHash(currentContent);
      _saveMindMap();

      // Mostrar notificación de temas nuevos
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
          onPressed: () {
            _highlightNewTopics();
          },
        ),
      ),
    );
  }

  // ✨ RESALTAR TEMAS NUEVOS
  void _highlightNewTopics() {
    // Los temas nuevos ya se muestran con colores especiales
    // Esta función podría implementar animaciones adicionales
  }

  void _saveMindMap() {
    try {
      // Persistir nodos y conexiones en la nota (incluye color por nodo Y tiempo de creación)
      widget.note.mindMapNodes = nodes
          .map((n) => {
                'id': n.id,
                'text': n.text,
                'x': n.position.dx.isFinite ? n.position.dx : 0.0,
                'y': n.position.dy.isFinite ? n.position.dy : 0.0,
                'children': List<String>.from(n.children),
                'color': nodeColors[n.id]?.value,
                'creationTime': _topicCreationTime[n.id]?.toIso8601String(),
              })
          .toList();

      widget.note.mindMapConnections = connections
          .map((c) => {
                'fromId': c.fromId,
                'toId': c.toId,
              })
          .toList();

      Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
    } catch (e) {
      print('Error saving mind map: $e');
      // Mostrar un snackbar de error al usuario
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
                // Limpiar nodos previos y regenerar
                _newTopics.clear();
                nodes = _generateIntelligentNodes({});
                connections = _generateConnections(nodes);
              });
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
            // 📊 INFORMACIÓN TEMPORAL SUPERPUESTA
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
