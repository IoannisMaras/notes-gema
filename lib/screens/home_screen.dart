import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import '../services/model_status_service.dart';
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
      drawer: Drawer(
        backgroundColor: const Color(0xFF0A0A0B),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology, color: Colors.cyanAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'NEURO_LINK v1.0',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            _drawerItem(Icons.terminal, 'TERMINAL_SESSION', () => Navigator.pop(context)),
            _drawerItem(Icons.memory, 'RESOURCE_MONITOR', () {}),
            _drawerItem(Icons.settings, 'SYS_CONFIG', () {}),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'BUILD_REV: 040826\nSTATUS: ENCRYPTED',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white24, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('root@gemma:~# ls -l ./notes'),
        actions: [
          _statusPill(context),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _notes.isEmpty ? _emptyState() : _noteList()),
          _statusBar(context),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.cyanAccent, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
      onTap: onTap,
    );
  }

  Widget _statusPill(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 3, backgroundColor: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('SYNCED', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(BuildContext context) {
    final svc = ModelStatusService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF121214),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.cyanAccent, size: 14),
              const SizedBox(width: 8),
              Text(
                svc.activeBackend.toUpperCase(),
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Icon(Icons.memory, color: Colors.white38, size: 14),
              const SizedBox(width: 8),
              Text(
                svc.memoryUsage,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        );
      },
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
