import 'package:flutter/material.dart';
import 'note.dart';

class NoteProvider extends ChangeNotifier {
  List<Note> notes = [];

  void updateNote(Note note) {
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      notes[idx] = note;
      notifyListeners();
    }
  }

  void addNote(Note note) {
    notes.add(note);
    notifyListeners();
  }

  void deleteNote(Note note) {
    notes.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }
}
