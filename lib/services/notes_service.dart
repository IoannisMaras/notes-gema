import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NotesService {
  static const _key = 'notes';

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => Note.fromJson(jsonDecode(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      notes.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> saveNote(Note note) async {
    final notes = await loadNotes();
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      notes[idx] = note;
    } else {
      notes.insert(0, note);
    }
    await saveNotes(notes);
  }

  Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == id);
    await saveNotes(notes);
  }

  Note createNewNote() {
    return Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'untitled.txt',
      content: '',
      updatedAt: DateTime.now(),
    );
  }
}
