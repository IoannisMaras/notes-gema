import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import 'notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _notesService = NotesService();
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _notesService.loadNotes();
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _createNewNote() async {
    final note = _notesService.createNewNote();
    _notes.insert(0, note);
    await _notesService.saveNotes(_notes);
    _openNote(note);
  }

  Future<void> _openNote(Note note) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotesScreen(note: note)),
    );
    _loadNotes();
  }

  Future<void> _deleteNote(String id) async {
    setState(() => _notes.removeWhere((n) => n.id == id));
    await _notesService.deleteNote(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('root@gemma:~# ls -l ./notes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white38, height: 1.0),
        ),
      ),
      body: _notes.isEmpty ? _emptyState() : _noteList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text(
        '// directory empty.\n// tap [+] to create a note.',
        style: TextStyle(
          color: Colors.white38,
          fontFamily: 'Courier',
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _noteList() {
    return ListView.builder(
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return ListTile(
          leading: const Icon(Icons.description, color: Colors.white54),
          title: Text(
            note.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            note.updatedAt.toString().substring(0, 16),
            style: const TextStyle(color: Colors.white38),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deleteNote(note.id),
          ),
          onTap: () => _openNote(note),
        );
      },
    );
  }
}
