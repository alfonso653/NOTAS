
import 'package:flutter/material.dart';
import 'note.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';


class NoteProvider extends ChangeNotifier {
  List<Note> notes = [];

  // Path to the local JSON file
  String? _notesFilePath;

  NoteProvider() {
    loadNotes();
  }

  Future<String> _getNotesFilePath() async {
    if (_notesFilePath != null) return _notesFilePath!;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/notes.json';
    _notesFilePath = path;
    return path;
  }

  Future<void> loadNotes() async {
    try {
      final filePath = await _getNotesFilePath();
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
      final file = File(filePath);
      final jsonStr = json.encode(notes.map((n) => n.toJson()).toList());
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
