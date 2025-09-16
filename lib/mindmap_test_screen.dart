import 'package:flutter/material.dart';
import 'mindmap_model.dart';
import 'mindmap_board.dart';

class MindMapTestScreen extends StatelessWidget {
  const MindMapTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Nodos de ejemplo
    final nodes = [
      MindMapNode(
        id: 'root',
        text: 'Idea Central',
        position: const Offset(140, 200),
        children: ['a', 'b'],
      ),
      MindMapNode(
        id: 'a',
        text: 'Concepto 1',
        position: const Offset(40, 80),
        children: [],
      ),
      MindMapNode(
        id: 'b',
        text: 'Concepto 2',
        position: const Offset(300, 80),
        children: ['c'],
      ),
      MindMapNode(
        id: 'c',
        text: 'Detalle',
        position: const Offset(320, 20),
        children: [],
      ),
    ];
    // Conexiones de ejemplo
    final connections = [
      MindMapConnection(fromId: 'root', toId: 'a', color: Colors.blue),
      MindMapConnection(fromId: 'root', toId: 'b', color: Colors.green),
      MindMapConnection(fromId: 'b', toId: 'c', color: Colors.orange),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Mental (Prueba)'),
      ),
      body: Container(
        color: const Color(0xFFF8F8F8),
        child: MindMapBoard(nodes: nodes, connections: connections),
      ),
    );
  }
}
