import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'note.dart';
import 'mindmap_model.dart';
import 'mindmap_board.dart';

class MindMapFromNoteScreen extends StatelessWidget {
  final Note note;
  const MindMapFromNoteScreen({Key? key, required this.note}) : super(key: key);

  List<MindMapNode> _generateNodes() {
    // Nodo central: título
    final nodes = <MindMapNode>[];
    final rootId = 'root';
    nodes.add(MindMapNode(
      id: rootId,
      text: note.title.isEmpty ? 'Nota' : note.title,
      position: const Offset(180, 200),
      children: [],
    ));
    // Nodos hijos: cada parte de texto (sin imágenes)
    final double radius = 140;
    int idx = 0;
    for (final part in note.contentParts) {
      if ((part['isImage'] ?? false) == true) continue;
      final text = (part['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final id = 'n$idx';
      final angle = 2 * math.pi * idx / (note.contentParts.length == 0 ? 1 : note.contentParts.length);
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

  @override
  Widget build(BuildContext context) {
    final nodes = _generateNodes();
    final connections = _generateConnections(nodes);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Mental de la Nota'),
      ),
      body: Container(
        color: const Color(0xFFF8F8F8),
        child: MindMapBoard(nodes: nodes, connections: connections),
      ),
    );
  }
}
