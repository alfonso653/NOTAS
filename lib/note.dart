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
    this.mindMapNodes,
    this.mindMapConnections,
  })  : floatingImages = floatingImages ?? [],
        floatingTexts = floatingTexts ?? [];

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
    );
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
      if (mindMapNodes != null) 'mindMapNodes': mindMapNodes,
      if (mindMapConnections != null) 'mindMapConnections': mindMapConnections,
    };
  }
}
