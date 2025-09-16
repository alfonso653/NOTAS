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

    nodes = _generateNodesFromNoteWithPositions(prevNodes);
    connections = _generateConnections(nodes);

    // Guardar el estado inicial (asegura persistencia al abrir)
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveMindMap());
  }

  List<MindMapNode> _generateNodesFromNoteWithPositions(
      Map<String, MindMapNode> prevNodes) {
    final result = <MindMapNode>[];

    // Nodo raíz
    const rootId = 'root';
    final String rootText =
        widget.note.title.isEmpty ? 'Nota' : widget.note.title;
    final MindMapNode rootNode = (prevNodes[rootId]?.copyWith(
          text: rootText,
          children: const <String>[],
        )) ??
        MindMapNode(
          id: rootId,
          text: rootText,
          position: const Offset(180, 200),
          children: <String>[],
        );
    result.add(rootNode);

    // Filtrar solo partes de texto para nodos secundarios
    final textParts = widget.note.contentParts.where((p) {
      final isImage = (p['isImage'] ?? false) == true;
      final text = (p['text'] ?? '').toString().trim();
      return !isImage && text.isNotEmpty;
    }).toList();

    final double radius = 160;
    final total = textParts.isEmpty ? 1 : textParts.length;

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

      // Si no tenía color previo, asigna blanco
      nodeColors.putIfAbsent(id, () => Colors.white);
    }

    // Hijos del root = todos los nodos no raíz
    final childrenIds = result.skip(1).map((n) => n.id).toList();
    final rootIndex = result.indexWhere((n) => n.id == rootId);
    if (rootIndex != -1) {
      result[rootIndex] = result[rootIndex].copyWith(children: childrenIds);
    }

    // Color por defecto del root si no existe
    nodeColors.putIfAbsent(rootId, () => Colors.white);

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

  void _saveMindMap() {
    // Persistir nodos y conexiones en la nota (incluye color por nodo)
    widget.note.mindMapNodes = nodes
        .map((n) => {
              'id': n.id,
              'text': n.text,
              'x': n.position.dx,
              'y': n.position.dy,
              'children': n.children,
              'color': nodeColors[n.id]?.value, // puede ser null si no existe
            })
        .toList();

    widget.note.mindMapConnections = connections
        .map((c) => {
              'fromId': c.fromId,
              'toId': c.toId,
            })
        .toList();

    Provider.of<NoteProvider>(context, listen: false).updateNote(widget.note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Mental de la Nota'),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saveMindMap,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF8F8F8),
        child: MindMapBoard(
          key: ValueKey('board_${widget.note.id}'),
          nodes: nodes,
          connections: connections,
          nodeColors: nodeColors,
          onNodeMoved: (updatedNode) {
            setState(() {
              // Reemplazar el nodo por id con la instancia actualizada
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
        ),
      ),
    );
  }
}
