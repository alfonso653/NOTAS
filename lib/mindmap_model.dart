import 'package:flutter/material.dart';

/// Nodo de mapa mental
class MindMapNode {
  MindMapNode copyWith({
    String? id,
    String? text,
    Offset? position,
    List<String>? children,
  }) {
    return MindMapNode(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      children: children ?? List<String>.from(this.children),
    );
  }
  String id;
  String text;
  Offset position;
  List<String> children; // IDs de nodos hijos

  MindMapNode({
    required this.id,
    required this.text,
    required this.position,
    this.children = const [],
  });
}

/// Conexión entre nodos (opcional, para personalizar color de línea)
class MindMapConnection {
  final String fromId;
  final String toId;
  final Color color;

  MindMapConnection({
    required this.fromId,
    required this.toId,
    this.color = Colors.grey,
  });
}
