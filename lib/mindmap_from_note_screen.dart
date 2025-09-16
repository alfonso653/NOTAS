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

  @override
  void initState() {
    super.initState();
    // Restaurar nodos y conexiones si existen en la nota
    if (widget.note.mindMapNodes != null && widget.note.mindMapNodes!.isNotEmpty) {
      // Restaurar nodos existentes
      nodes = widget.note.mindMapNodes!.map((e) => MindMapNode(
        id: e['id'],
        text: e['text'],
        position: Offset((e['x'] as num).toDouble(), (e['y'] as num).toDouble()),
        children: (e['children'] as List?)?.map((c) => c.toString()).toList() ?? [],
      )).toList();

      // Sincronizar el nodo principal (root) con el título de la nota
      final root = nodes.first;
      final newRootText = widget.note.title.isEmpty ? 'Nota' : widget.note.title;
      if (root.text != newRootText) {
        nodes[0] = root.copyWith(text: newRootText);
      }

      // Buscar nodos hijos (no root) y mapear por índice
      int idx = 0;
      for (final part in widget.note.contentParts) {
        if ((part['isImage'] ?? false) == true) continue;
        final text = (part['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final nodeId = 'n$idx';
        final nodeIdx = nodes.indexWhere((n) => n.id == nodeId);
        if (nodeIdx != -1) {
          // Si existe, actualizar el texto
          nodes[nodeIdx] = nodes[nodeIdx].copyWith(
            text: text.length > 40 ? text.substring(0, 40) + '...' : text,
          );
        } else {
          // Si no existe, crear el nodo
          nodes.add(MindMapNode(
            id: nodeId,
            text: text.length > 40 ? text.substring(0, 40) + '...' : text,
            position: root.position + Offset(60.0 * (idx + 1), 120.0),
            children: [],
          ));
          nodes[0].children.add(nodeId);
        }
        idx++;
      }
      // Opcional: eliminar nodos huérfanos si algún segmento fue borrado
      nodes.removeWhere((n) => n.id.startsWith('n') && int.tryParse(n.id.substring(1)) != null && int.parse(n.id.substring(1)) >= idx);
      nodes[0].children.removeWhere((id) => id.startsWith('n') && int.tryParse(id.substring(1)) != null && int.parse(id.substring(1)) >= idx);
    } else {
      nodes = _generateNodesFromNote();
    }
    if (widget.note.mindMapConnections != null && widget.note.mindMapConnections!.isNotEmpty) {
      connections = widget.note.mindMapConnections!.map((e) => MindMapConnection(
        fromId: e['fromId'],
        toId: e['toId'],
        color: Colors.indigo,
      )).toList();
      // --- Agregar conexiones para nuevos nodos hijos si faltan ---
      final root = nodes.first;
      for (final id in root.children) {
        if (!connections.any((c) => c.fromId == root.id && c.toId == id)) {
          connections.add(MindMapConnection(fromId: root.id, toId: id, color: Colors.indigo));
        }
      }
    } else {
      connections = _generateConnections(nodes);
    }
  }

  List<MindMapNode> _generateNodesFromNote() {
    final nodes = <MindMapNode>[];
    final rootId = 'root';
    nodes.add(MindMapNode(
      id: rootId,
      text: widget.note.title.isEmpty ? 'Nota' : widget.note.title,
      position: const Offset(180, 200),
      children: [],
    ));
    final double radius = 140;
    int idx = 0;
    for (final part in widget.note.contentParts) {
      if ((part['isImage'] ?? false) == true) continue;
      final text = (part['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final id = 'n$idx';
      final angle = 2 * math.pi * idx / (widget.note.contentParts.length == 0 ? 1 : widget.note.contentParts.length);
      nodes.add(MindMapNode(
        id: id,
        text: text.length > 40 ? text.substring(0, 40) + '...' : text,
        position: Offset(
          180 + radius * math.cos(angle),
          200 + radius * math.sin(angle),
        ),
        children: [],
      ));
      nodes.first.children.add(id);
      idx++;
    }
    return nodes;
  }

  List<MindMapConnection> _generateConnections(List<MindMapNode> nodes) {
    final root = nodes.first;
    return root.children
        .map((id) => MindMapConnection(fromId: root.id, toId: id, color: Colors.indigo))
        .toList();
  }

  void _saveMindMap() {
    // Guardar nodos y conexiones en la nota y persistir
    widget.note.mindMapNodes = nodes.map((n) => {
      'id': n.id,
      'text': n.text,
      'x': n.position.dx,
      'y': n.position.dy,
      'children': n.children,
    }).toList();
    widget.note.mindMapConnections = connections.map((c) => {
      'fromId': c.fromId,
      'toId': c.toId,
    }).toList();
    final provider = Provider.of<NoteProvider>(context, listen: false);
    provider.updateNote(widget.note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Mental de la Nota'),
      ),
      body: Container(
        color: const Color(0xFFF8F8F8),
        child: MindMapBoard(
          nodes: nodes,
          connections: connections,
          onNodeMoved: (_) => _saveMindMap(),
        ),
      ),
    );
  }
}
