import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'note.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart' show File;

class NoteProvider extends ChangeNotifier {
  List<Note> notes = [];

  // Path to the local JSON file
  String? _notesFilePath;

  NoteProvider() {
    loadNotes();
  }

  Future<String> _getNotesFilePath() async {
    if (_notesFilePath != null) return _notesFilePath!;
    if (kIsWeb) {
      _notesFilePath = 'notes_web'; // Clave para web storage
      return _notesFilePath!;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/notes.json';
    _notesFilePath = path;
    return path;
  }

  Future<void> loadNotes() async {
    try {
      final filePath = await _getNotesFilePath();

      if (kIsWeb) {
        // En web, usar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString(filePath);
        if (jsonStr != null) {
          final jsonData = jsonDecode(jsonStr) as List;
          notes = jsonData.map((n) => Note.fromJson(n)).toList();
          notifyListeners();
        }
        return;
      }

      // En móvil, usar archivos
      final file = File(filePath);
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        notes = jsonList.map((e) => Note.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      // If error, keep notes empty
      notes = [];
    }
  }

  Future<void> saveNotes() async {
    try {
      final filePath = await _getNotesFilePath();
      final jsonStr = json.encode(notes.map((n) => n.toJson()).toList());

      if (kIsWeb) {
        // En web, usar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(filePath, jsonStr);
        return;
      }

      // En móvil, usar archivos
      final file = File(filePath);
      await file.writeAsString(jsonStr);
    } catch (e) {
      // Ignore write errors
    }
  }

  void updateNote(Note note) {
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      notes[idx] = note;
      saveNotes();
      notifyListeners();
    }
  }

  void addNote(Note note) {
    notes.add(note);
    saveNotes();
    notifyListeners();
  }

  void deleteNote(Note note) {
    notes.removeWhere((n) => n.id == note.id);
    saveNotes();
    notifyListeners();
  }
}
