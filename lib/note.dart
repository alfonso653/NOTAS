import 'package:flutter/material.dart';

class Note {
  final String id;
  String title;
  String date;
  String categoria;
  String skin;
  Color color;
  double titleFontSize;
  List<Map<String, dynamic>> contentParts; // [{text:..., bold:...}, ...]


  Note({
    required this.id,
    required this.title,
    required this.date,
    required this.categoria,
    required this.skin,
    required this.color,
    required this.titleFontSize,
    required this.contentParts,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      categoria: json['categoria'] ?? '',
      skin: json['skin'] ?? '',
      color: Color(json['color'] ?? 0xFFFFFFFF),
      titleFontSize: (json['titleFontSize'] ?? 18).toDouble(),
      contentParts: (json['contentParts'] is List)
          ? (json['contentParts'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
          : [],
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
      'contentParts': contentParts,
    };
  }
}
