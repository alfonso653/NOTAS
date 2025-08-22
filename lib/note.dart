import 'package:flutter/material.dart';

class Note {
  final String id;
  String title;
  String content;
  String date;
  String categoria;
  String skin;
  Color color;
  double titleFontSize;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.categoria,
    required this.skin,
    required this.color,
    required this.titleFontSize,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: json['date'] ?? '',
      categoria: json['categoria'] ?? '',
      skin: json['skin'] ?? '',
      color: Color(json['color'] ?? 0xFFFFFFFF),
      titleFontSize: (json['titleFontSize'] ?? 18).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
      'categoria': categoria,
      'skin': skin,
      'color': color.value,
      'titleFontSize': titleFontSize,
    };
  }
}
