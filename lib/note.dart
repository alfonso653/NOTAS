import 'package:flutter/material.dart';

class Note {
  // Nuevo: estado del mapa mental (lista de nodos y conexiones)
  List<Map<String, dynamic>>? mindMapNodes;
  List<Map<String, dynamic>>? mindMapConnections;
  final String id;
  String title;
  String date;
  String categoria;
  String skin;
  Color color;
  double titleFontSize;
  double contentFontSize;
  List<Map<String, dynamic>> contentParts; // [{text:..., bold:...}, ...]
  List<Map<String, dynamic>> floatingImages;
  List<Map<String, dynamic>> floatingTexts;
  List<Map<String, dynamic>> drawingStrokes; // Trazos de dibujo libre
  bool? isHeaderCollapsed; // Estado de cabecera colapsada
  bool? isFloatingButtonsCollapsed; // Estado de botones flotantes colapsados

  Note({
    required this.id,
    required this.title,
    required this.date,
    required this.categoria,
    required this.skin,
    required this.color,
    required this.titleFontSize,
    required this.contentFontSize,
    required this.contentParts,
    List<Map<String, dynamic>>? floatingImages,
    List<Map<String, dynamic>>? floatingTexts,
    List<Map<String, dynamic>>? drawingStrokes,
    this.mindMapNodes,
    this.mindMapConnections,
    this.isHeaderCollapsed,
    this.isFloatingButtonsCollapsed,
  })  : floatingImages = floatingImages ?? [],
        floatingTexts = floatingTexts ?? [],
        drawingStrokes = drawingStrokes ?? [];

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      categoria: json['categoria'] ?? '',
      skin: json['skin'] ?? '',
      color: Color(json['color'] ?? 0xFFFFFFFF),
      titleFontSize: (json['titleFontSize'] ?? 18).toDouble(),
      contentFontSize: (json['contentFontSize'] ?? 18).toDouble(),
      contentParts: (json['contentParts'] is List)
          ? (json['contentParts'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      floatingImages: (json['floatingImages'] is List)
          ? (json['floatingImages'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      floatingTexts: (json['floatingTexts'] is List)
          ? (json['floatingTexts'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      drawingStrokes: (json['drawingStrokes'] is List)
          ? (json['drawingStrokes'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      mindMapNodes: (json['mindMapNodes'] is List)
          ? (json['mindMapNodes'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : null,
      mindMapConnections: (json['mindMapConnections'] is List)
          ? (json['mindMapConnections'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : null,
    )..isHeaderCollapsed = json['isHeaderCollapsed']
     ..isFloatingButtonsCollapsed = json['isFloatingButtonsCollapsed'];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'categoria': categoria,
      'skin': skin,
      'color': color.value,
      'titleFontSize': titleFontSize,
      'contentFontSize': contentFontSize,
      'contentParts': contentParts,
      'floatingImages': floatingImages,
      'floatingTexts': floatingTexts,
      'drawingStrokes': drawingStrokes,
      if (mindMapNodes != null) 'mindMapNodes': mindMapNodes,
      if (mindMapConnections != null) 'mindMapConnections': mindMapConnections,
      if (isHeaderCollapsed != null) 'isHeaderCollapsed': isHeaderCollapsed,
      if (isFloatingButtonsCollapsed != null) 'isFloatingButtonsCollapsed': isFloatingButtonsCollapsed,
    };
  }
}
