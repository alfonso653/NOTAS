import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Nodo de mapa mental (inmutable)
@immutable
class MindMapNode {
  final String id;
  final String text;
  final Offset position;

  /// Lista inmutable (no se comparte referencia mutable entre instancias)
  final List<String> children;

  MindMapNode({
    required this.id,
    required this.text,
    required this.position,
    List<String>? children,
  }) : children = List.unmodifiable(children ?? const <String>[]);

  /// Copia defensiva: siempre devuelve una nueva instancia con lista inmutable
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
      children: children != null
          ? List.unmodifiable(List<String>.from(children))
          : List.unmodifiable(List<String>.from(this.children)),
    );
  }

  /// Helpers inmutables para operar sobre hijos sin mutar la instancia original
  MindMapNode addChild(String childId) =>
      copyWith(children: [...children, childId]);

  MindMapNode removeChild(String childId) =>
      copyWith(children: children.where((c) => c != childId).toList());

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'position': {'dx': position.dx, 'dy': position.dy},
        'children': children,
      };

  factory MindMapNode.fromJson(Map<String, dynamic> json) => MindMapNode(
        id: json['id'] as String,
        text: json['text'] as String,
        position: Offset(
          (json['position']?['dx'] as num).toDouble(),
          (json['position']?['dy'] as num).toDouble(),
        ),
        children: (json['children'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const <String>[],
      );

  /// Igualdad basada en id (recomendado si usas id único para claves/keys)
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MindMapNode && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MindMapNode(id: $id, text: $text, pos: $position, children: $children)';
}

/// Conexión entre nodos (opcional, para personalizar color de línea)
@immutable
class MindMapConnection {
  final String fromId;
  final String toId;
  final Color color;

  const MindMapConnection({
    required this.fromId,
    required this.toId,
    this.color = Colors.grey,
  });

  MindMapConnection copyWith({
    String? fromId,
    String? toId,
    Color? color,
  }) {
    return MindMapConnection(
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      color: color ?? this.color,
    );
  }
}
