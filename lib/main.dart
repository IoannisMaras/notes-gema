import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  runApp(const MyApp());
}

class PendingChange {
  final String oldText;
  final String newText;
  final bool isAppend;
  bool isResolved;
  bool isAccepted;

  PendingChange({
    required this.oldText,
    required this.newText,
    required this.isAppend,
    this.isResolved = false,
    this.isAccepted = false,
  });
}

class TerminalNotesController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    List<TextSpan> children = [];
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      TextStyle lineStyle = style ?? const TextStyle();
      if (line.startsWith('- ')) {
        lineStyle = lineStyle.copyWith(
          color: Colors.redAccent,
          decoration: TextDecoration.lineThrough,
          backgroundColor: Colors.redAccent.withOpacity(0.1),
        );
      } else if (line.startsWith('+ ')) {
        lineStyle = lineStyle.copyWith(
          color: Colors.greenAccent,
          backgroundColor: Colors.greenAccent.withOpacity(0.1),
        );
      } else if (line.startsWith('@@')) {
        lineStyle = lineStyle.copyWith(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        );
      } else if (line.startsWith('//')) {
        lineStyle = lineStyle.copyWith(color: Colors.white38);
      }
      children.add(
        TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
          style: lineStyle,
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

class Note {
  final String id;
  String title;
  String content;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 14,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const BootScreen(),
    );
  }
}

enum BotState { exhausted, awake, thinking }

class AsciiBot extends StatefulWidget {
  final BotState state;
  final double targetX;
  final double targetY;
  final double botX;
  final double botY;

  const AsciiBot({
    super.key,
    required this.state,
    this.targetX = 0,
    this.targetY = 0,
    this.botX = 0,
    this.botY = 0,
  });

  @override
  State<AsciiBot> createState() => _AsciiBotState();
}

class _AsciiBotState extends State<AsciiBot> {
  late Timer _timer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted) {
        setState(() {
          _frameIndex++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double botCenterX = widget.botX + 30; // approx center
    double botCenterY = widget.botY + 30;

    double dx = widget.targetX - botCenterX;
    double dy = widget.targetY - botCenterY;

    if (widget.targetX == 0 && widget.targetY == 0) {
      dx = 0;
      dy = 0;
    }

    double distance = math.sqrt(dx * dx + dy * dy);
    double angle = math.atan2(dy, dx);
    double intensity = (distance / 400.0).clamp(0.0, 1.0);

    double maxEyeShift = 10.0;
    double maxMouthShift = 4.0;

    double eyeOffsetX = math.cos(angle) * maxEyeShift * intensity;
    double eyeOffsetY = math.sin(angle) * maxEyeShift * intensity;

    // Parallax sub-pixel shifting for the mouth
    double mouthOffsetX = math.cos(angle) * maxMouthShift * intensity;
    double mouthOffsetY = math.sin(angle) * maxMouthShift * intensity;

    String eyeL = "o";
    String eyeR = "o";
    String mouth = "-";

    switch (widget.state) {
      case BotState.exhausted:
        eyeL = "-";
        eyeR = "-";
        final zCycle = (_frameIndex ~/ 3) % 4;
        mouth = zCycle == 0 ? "z" : (zCycle == 1 ? "Z" : "z");
        eyeOffsetX += math.cos(_frameIndex.toDouble() * 0.5) * 2;
        eyeOffsetY += math.sin(_frameIndex.toDouble() * 0.25) * 2;
        break;
      case BotState.awake:
        if ((_frameIndex ~/ 10) % 2 == 0 && _frameIndex % 10 < 2) {
          eyeL = ">";
          eyeR = "<";
        } else if (_frameIndex % 30 == 0) {
          eyeL = "u";
          eyeR = "u";
        }
        break;
      case BotState.thinking:
        int glitch = _frameIndex % 4;
        if (glitch == 0) {
          eyeL = "O";
          eyeR = "o";
        } else if (glitch == 1) {
          eyeL = "o";
          eyeR = "O";
        } else if (glitch == 2) {
          eyeL = "-";
          eyeR = "-";
        }
        mouth = (glitch % 2 == 0) ? "o" : "-";
        eyeOffsetX += (glitch % 2 == 0 ? 3 : -3);
        eyeOffsetY += (glitch % 3 == 0 ? 2 : -2);
        break;
    }

    return SizedBox(
      width: 50,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            left: 6 + eyeOffsetX,
            top: 2 + eyeOffsetY,
            child: Text(
              eyeL,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            right: 6 - eyeOffsetX,
            top: 2 + eyeOffsetY,
            child: Text(
              eyeR,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: 19 + mouthOffsetX,
            top: 22 + mouthOffsetY,
            child: Text(
              mouth,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  final List<String> _logs = ["> init system..."];
  bool _isDownloading = false;
  bool _isExhausted = true;
  double _progress = 0.0;

  // High-parametric NPU target
  final String modelUrl =
      "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm";

  @override
  void initState() {
    super.initState();
    _checkAndPrepareModel();
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  String _getProgressBar(double progress) {
    int totalBars = 20;
    int filled = (totalBars * progress).round();
    String bar = '[';
    for (int i = 0; i < totalBars; i++) {
      if (i < filled)
        bar += '#';
      else if (i == filled)
        bar += '>';
      else
        bar += '-';
    }
    bar += ']';
    return bar;
  }

  Future<void> _checkAndPrepareModel() async {
    try {
      _log("> checking and syncing AI model registry...");
      setState(() {
        _isDownloading = true;
        _isExhausted = true;
      });

      _log("> downloading valid Gemma artifact...");

      await FlutterGemma.installModel(modelType: ModelType.general)
          .fromNetwork(
            modelUrl,
            // token: "YOUR_HUGGING_FACE_TOKEN", // ⚠️ UNCOMMENT REQUIRED FOR OFFICIAL GATED MODELS
          )
          .withProgress((progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          })
          .install();

      setState(() {
        _isDownloading = false;
        _isExhausted = false; // Bot wakes up
      });
      _log("> installation complete. awakening...");

      _log("> pre-warming model context...");
      await FlutterGemma.getActiveModel(
        maxTokens: 2056,
        preferredBackend: PreferredBackend.gpu,
      );

      _log("> system online.");
      await Future.delayed(const Duration(milliseconds: 1400));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      _log("> FATAL ENGINE ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AsciiBot(
                  state: _isExhausted ? BotState.exhausted : BotState.awake,
                ),
              ),
            ),
            const SizedBox(height: 64),
            ..._logs.map(
              (L) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  L,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Text(
                "> DOWNLOADING: ${_getProgressBar(_progress)} ${(_progress * 100).toStringAsFixed(1)}%",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "> SIZE: ${(4.5 * _progress).toStringAsFixed(2)} GB / 4.50 GB",
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesList = prefs.getStringList('notes') ?? [];
    setState(() {
      _notes = notesList.map((e) => Note.fromJson(jsonDecode(e))).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesList = _notes.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('notes', notesList);
  }

  void _createNewNote() async {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "untitled.txt",
      content: "",
      updatedAt: DateTime.now(),
    );
    _notes.insert(0, newNote);
    await _saveNotes();
    _openNote(newNote);
  }

  void _openNote(Note note) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NotesScreen(note: note)));
    _loadNotes();
  }

  void _deleteNote(String id) async {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
    });
    await _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("root@gemma:~# ls -l ./notes"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white38, height: 1.0),
        ),
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text(
                "// directory empty.\n// tap [+] to create a note.",
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Courier',
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
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
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deleteNote(note.id),
                  ),
                  onTap: () => _openNote(note),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  final Note note;
  const NotesScreen({super.key, required this.note});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TerminalNotesController _noteController = TerminalNotesController();
  final TextEditingController _cmdController = TextEditingController();
  bool _isProcessing = false;
  bool _showAiChat = false;
  final List<dynamic> _chatLog = [];

  // Base bot screen offsets
  double _botLeft = 20.0;
  double _botTop = 20.0;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.note.content;
    _noteController.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    widget.note.content = _noteController.text;

    final lines = widget.note.content.split('\n');
    if (lines.isNotEmpty && lines.first.trim().isNotEmpty) {
      String firstLine = lines.first.trim();
      firstLine = firstLine.substring(
        0,
        firstLine.length > 20 ? 20 : firstLine.length,
      );
      firstLine = firstLine.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
      widget.note.title = "$firstLine.txt";
    } else {
      widget.note.title = "untitled.txt";
    }

    widget.note.updatedAt = DateTime.now();
    _saveNoteDirectly();
  }

  Future<void> _saveNoteDirectly() async {
    final prefs = await SharedPreferences.getInstance();
    final notesListRaw = prefs.getStringList('notes') ?? [];
    List<Note> notesList = notesListRaw
        .map((e) => Note.fromJson(jsonDecode(e)))
        .toList();

    final index = notesList.indexWhere((n) => n.id == widget.note.id);
    if (index != -1) {
      notesList[index] = widget.note;
    } else {
      notesList.insert(0, widget.note);
    }
    await prefs.setStringList(
      'notes',
      notesList.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  double _getCursorX() {
    if (_noteController.text.isEmpty) return 20;
    return 100.0;
  }

  double _getCursorY() {
    if (_noteController.text.isEmpty) return 100;
    int lines = _noteController.text.split('\n').length;
    return (lines * 22.0).clamp(50.0, MediaQuery.of(context).size.height - 100);
  }

  void _runCommand() async {
    final cmd = _cmdController.text.trim();
    if (cmd.isEmpty) return;

    _cmdController.clear();
    setState(() {
      _isProcessing = true;
      _chatLog.add("> USER: $cmd");
    });

    try {
      final model = await FlutterGemma.getActiveModel(maxTokens: 2500);
      final fullText = _noteController.text;
      final contextText = fullText.length > 200
          ? "...\\n" + fullText.substring(fullText.length - 200)
          : fullText;
      final prompt =
          "Role: AI Notes Agent. Tools: [read_lines, edit_content]. Rule: Always use tools for edits. Snapshot: $contextText. Command: $cmd";

      final tools = [
        Tool(
          name: 'read_lines',
          description: 'Read 50 lines.',
          parameters: {
            'type': 'object',
            'properties': {
              'start_line': {'type': 'integer'},
            },
            'required': ['start_line'],
          },
        ),
        Tool(
          name: 'edit_content',
          description: 'Edit text. Empty old_text appends.',
          parameters: {
            'type': 'object',
            'properties': {
              'old_text': {'type': 'string'},
              'new_text': {'type': 'string'},
            },
            'required': ['old_text', 'new_text'],
          },
        ),
      ];

      final session = await model.createChat(
        tools: tools,
        supportsFunctionCalls: true,
        modelType: ModelType.general,
      );
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));

      bool isRunning = true;
      int iterations = 0;

      while (isRunning && iterations < 5) {
        iterations++;
        final responseStream = session.generateChatResponseAsync();
        bool extractedTool = false;
        bool isFirstToken = true;
        String textBuffer = "";

        await for (final chunk in responseStream) {
          if (chunk is TextResponse) {
            textBuffer += chunk.token;
            if (!textBuffer.contains('call:') &&
                !textBuffer.contains('<tool_call')) {
              setState(() {
                if (isFirstToken) {
                  _chatLog.add("> AI:\\n" + textBuffer);
                  isFirstToken = false;
                } else if (_chatLog.isNotEmpty && _chatLog.last is String) {
                  _chatLog[_chatLog.length - 1] = "> AI:\\n" + textBuffer;
                }
              });
            }
          } else if (chunk is FunctionCallResponse) {
            extractedTool = true;
            if (!isFirstToken &&
                _chatLog.isNotEmpty &&
                _chatLog.last is String &&
                (_chatLog.last as String).startsWith("> AI:\\n")) {
              _chatLog.removeLast();
            }

            String toolResult = "";
            bool ok = true;

            if (chunk.name == 'read_lines') {
              int start = 1;
              final arg = chunk.args['start_line'];
              if (arg != null)
                start = arg is int ? arg : int.tryParse(arg.toString()) ?? 1;
              final lines = _noteController.text.split('\\n');
              final startIndex = (start - 1).clamp(0, lines.length);
              final endIndex = (startIndex + 50).clamp(0, lines.length);
              toolResult = lines.sublist(startIndex, endIndex).join('\\n');
              setState(() {
                _chatLog.add("> READ [PAGE $start]");
              });
            } else if (chunk.name == 'edit_content') {
              final old = chunk.args['old_text']?.toString() ?? "";
              final newT = chunk.args['new_text']?.toString() ?? "";
              setState(() {
                _chatLog.add(
                  PendingChange(
                    oldText: old,
                    newText: newT,
                    isAppend: old.isEmpty,
                  ),
                );
              });
              isRunning = false;
            }

            if (isRunning) {
              await session.addQueryChunk(
                Message.toolResponse(
                  toolName: chunk.name,
                  response: {
                    "result": toolResult,
                    "status": ok ? "ok" : "error",
                  },
                ),
              );
            }
          }
        }
        if (!extractedTool) isRunning = false;
      }
    } catch (e) {
      setState(() {
        _chatLog.add("> FATAL ENGINE ERROR: $e");
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("root@gemma:~# nano ${widget.note.title}"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white38, height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onTap: () {
                      setState(() {
                        _showAiChat = false;
                      });
                    },
                    controller: _noteController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Courier',
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          "// type your notes here...\n// use the floating robot to interact with AI.",
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showAiChat
                    ? Container(
                        height: MediaQuery.of(context).size.height * 0.45,
                        color: Colors.white10,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              width: double.infinity,
                              color: Colors.black87,
                              child: const Text(
                                "AI LINK ESTABLISHED",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: _chatLog.length,
                                itemBuilder: (context, index) {
                                  final item = _chatLog[index];

                                  if (_isProcessing &&
                                      index == _chatLog.length - 1 &&
                                      item is String) {
                                    if (item.startsWith("> USER:")) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontFamily: 'Courier',
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Text(
                                              "> AI:\n █",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontFamily: 'Courier',
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else if (item.startsWith("> AI:")) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8.0,
                                        ),
                                        child: Text(
                                          "$item █",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontFamily: 'Courier',
                                            fontSize: 14,
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  if (item is PendingChange) {
                                    String formattedOld = item.isAppend
                                        ? ""
                                        : item.oldText
                                              .split('\n')
                                              .map((e) => "- $e")
                                              .join('\n');
                                    String formattedNew = item.newText
                                        .split('\n')
                                        .map((e) => "+ $e")
                                        .join('\n');
                                    String diffRaw = item.isAppend
                                        ? "@@ APPEND @@\n$formattedNew"
                                        : "@@ REPLACE @@\n$formattedOld\n$formattedNew";

                                    return Container(
                                      color: Colors.black45,
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "> AI PROPOSED CHANGES:",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...diffRaw.split('\n').map((line) {
                                            Color c = Colors.white70;
                                            if (line.startsWith('+'))
                                              c = Colors.greenAccent;
                                            if (line.startsWith('-'))
                                              c = Colors.redAccent;
                                            if (line.startsWith('@@'))
                                              c = Colors.blueAccent;
                                            return Text(
                                              line,
                                              style: TextStyle(
                                                color: c,
                                                fontFamily: 'Courier',
                                                fontSize: 13,
                                              ),
                                            );
                                          }).toList(),
                                          const SizedBox(height: 12),
                                          if (!item.isResolved)
                                            Row(
                                              children: [
                                                ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .green
                                                            .withOpacity(0.2),
                                                        foregroundColor:
                                                            Colors.greenAccent,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.check,
                                                    size: 16,
                                                  ),
                                                  label: const Text("ACCEPT"),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (item.isAppend) {
                                                        _noteController.text +=
                                                            (_noteController
                                                                    .text
                                                                    .isEmpty
                                                                ? ""
                                                                : "\n") +
                                                            item.newText;
                                                      } else {
                                                        if (_noteController.text
                                                            .contains(
                                                              item.oldText,
                                                            )) {
                                                          _noteController.text =
                                                              _noteController
                                                                  .text
                                                                  .replaceFirst(
                                                                    item.oldText,
                                                                    item.newText,
                                                                  );
                                                        } else if (_noteController
                                                            .text
                                                            .contains(
                                                              item.oldText
                                                                  .trim(),
                                                            )) {
                                                          _noteController.text =
                                                              _noteController
                                                                  .text
                                                                  .replaceFirst(
                                                                    item.oldText
                                                                        .trim(),
                                                                    item.newText,
                                                                  );
                                                        }
                                                      }
                                                      item.isResolved = true;
                                                      item.isAccepted = true;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.redAccent,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                  ),
                                                  label: const Text("REJECT"),
                                                  onPressed: () {
                                                    setState(() {
                                                      item.isResolved = true;
                                                      item.isAccepted = false;
                                                    });
                                                  },
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              item.isAccepted
                                                  ? "[MERGED]"
                                                  : "[REJECTED]",
                                              style: TextStyle(
                                                color: item.isAccepted
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }

                                  final text = item as String;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'Courier',
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              color: Colors.black,
                              child: Row(
                                children: [
                                  const Text(
                                    "> ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _cmdController,
                                      enabled: !_isProcessing,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Courier',
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: _isProcessing
                                            ? "PROCESSING..."
                                            : "ask AI a question...",
                                        hintStyle: const TextStyle(
                                          color: Colors.white38,
                                        ),
                                      ),
                                      onSubmitted: (_) => _runCommand(),
                                    ),
                                  ),
                                  if (_isProcessing)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        color: Colors.white54,
                                      ),
                                      onPressed: _runCommand,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),

          // Floating ASCII Bot Bubble hovering over the UI
          Positioned(
            left: _botLeft,
            top: _botTop,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // Toggle AI Chat
                  _showAiChat = !_showAiChat;

                  // Instantly focus and snap robot tracking target
                  if (_showAiChat) {
                    _botTop = MediaQuery.of(context).size.height / 2;
                  }
                });
              },
              onPanUpdate: (details) {
                final Size screenSize = MediaQuery.of(context).size;
                const double bubbleSize = 90.0;

                setState(() {
                  _botLeft += details.delta.dx;
                  _botTop += details.delta.dy;

                  double topOffset = 56.0;
                  _botLeft = _botLeft.clamp(0.0, screenSize.width - bubbleSize);
                  _botTop = _botTop.clamp(
                    0.0,
                    screenSize.height - bubbleSize - topOffset,
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AsciiBot(
                  state: _isProcessing ? BotState.thinking : BotState.awake,
                  botX: _botLeft,
                  botY: _botTop,
                  targetX: _getCursorX(),
                  targetY: _getCursorY(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
