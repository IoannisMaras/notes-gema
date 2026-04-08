import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/note.dart';
import '../models/pending_change.dart';
import '../models/voice_message.dart';
import 'package:file_picker/file_picker.dart';
import '../services/gemma_service.dart';
import '../services/model_status_service.dart';
import '../services/notes_service.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/ascii_bot.dart';
import '../widgets/terminal_notes_controller.dart';

class NotesScreen extends StatefulWidget {
  final Note note;
  const NotesScreen({super.key, required this.note});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // ── Controllers & services ─────────────────────────────────────────────────
  final TerminalNotesController _noteController = TerminalNotesController();
  final TextEditingController _cmdController = TextEditingController();
  final FocusNode _cmdFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  final _notesService = NotesService();
  final _gemmaService = GemmaService();

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  List<double> _liveAmplitudes = [];
  StreamSubscription? _ampSubscription;
  Timer? _countdownTimer;
  int _recordCountdown = 10;

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _isProcessing = false;
  bool _showAiChat = false;
  final List<dynamic> _chatLog = [];

  // ── Bot bubble position ────────────────────────────────────────────────────
  double _botLeft = 0.0;
  double _botTop = 0.0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.note.content;
    _noteController.addListener(_onNoteChanged);
    ModelStatusService.instance.addListener(_onModelStatusChanged);
    // Position the bot bubble at the right-center after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        const bubbleWidth = 90.0;
        const margin = 12.0;
        setState(() {
          _botLeft = size.width - bubbleWidth - margin;
          _botTop = (size.height / 2) - 30;
        });
      }
    });
  }

  @override
  void dispose() {
    _cmdFocusNode.dispose();
    _noteController.dispose();
    _cmdController.dispose();
    ModelStatusService.instance.removeListener(_onModelStatusChanged);
    _ampSubscription?.cancel();
    _countdownTimer?.cancel();
    _recorder.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ── Note persistence ───────────────────────────────────────────────────────

  void _onNoteChanged() {
    final note = widget.note;
    note.content = _noteController.text;
    final lines = note.content.split('\n');
    if (lines.isNotEmpty && lines.first.trim().isNotEmpty) {
      String firstLine = lines.first.trim();
      if (firstLine.length > 20) firstLine = firstLine.substring(0, 20);
      firstLine = firstLine.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
      note.title = '$firstLine.txt';
    } else {
      note.title = 'untitled.txt';
    }
    note.updatedAt = DateTime.now();
    _notesService.saveNote(note);
  }

  void _onModelStatusChanged() {
    if (mounted) setState(() {});
  }

  // ── Audio recording ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/command.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _liveAmplitudes = [];
      _recordCountdown = 10;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordCountdown > 0) {
        setState(() => _recordCountdown--);
      } else {
        _stopRecording();
      }
    });
    _ampSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
          setState(() {
            double norm = (amp.current + 60) / 60;
            if (norm < 0) norm = 0;
            _liveAmplitudes.add(norm);
            if (_liveAmplitudes.length > 50) _liveAmplitudes.removeAt(0);
          });
        });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _countdownTimer?.cancel();
    _ampSubscription?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordCountdown = 10;
    });
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      final ampsCopy = List<double>.from(_liveAmplitudes);
      _runCommand(audioBytes: bytes, recordedAmplitudes: ampsCopy);
    }
    setState(() => _liveAmplitudes = []);
  }

  void _onMicPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  // ── AI command runner ──────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _runCommand({Uint8List? audioBytes, List<double>? recordedAmplitudes}) {
    // Guard: don't attempt AI commands if model isn't ready
    if (!ModelStatusService.instance.isReady) return;

    final cmd = _cmdController.text.trim();
    if (cmd.isEmpty && audioBytes == null) return;
    _cmdController.clear();

    setState(() {
      _isProcessing = true;
      if (audioBytes != null) {
        _chatLog.add(VoiceMessage(recordedAmplitudes ?? []));
      } else {
        _chatLog.add('> USER: $cmd');
      }
      _scrollToBottom();
    });

    _gemmaService.runCommand(
      textCommand: cmd,
      audioBytes: audioBytes,
      recordedAmplitudes: recordedAmplitudes,
      getNoteText: () => _noteController.text,
      onLog: (item) => setState(() => _chatLog.add(item)),
      onLogUpdate: (index, item) => setState(() => _chatLog[index] = item),
      onScrollToBottom: _scrollToBottom,
      onPendingChange: (_) {},
      onDone: () {
        if (mounted) {
          setState(() => _isProcessing = false);
          // Final scroll after UI settles
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      },
      onError: (err) => setState(() => _chatLog.add(err)),
      getLogLength: () => _chatLog.length,
      getLogItem: (i) => _chatLog[i],
      removeLastLog: () => setState(() {
        if (_chatLog.isNotEmpty) _chatLog.removeLast();
      }),
    );
  }

  Future<Directory> _getImageDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/note_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  Future<void> _insertImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = result.files.first;
    if (picked.path == null) {
      return;
    }

    final source = File(picked.path!);
    final imagesDir = await _getImageDirectory();
    final destinationPath =
        '${imagesDir.path}/${widget.note.id}_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    final destination = await source.copy(destinationPath);

    setState(() {
      widget.note.imagePaths = List<String>.from(widget.note.imagePaths)
        ..add(destination.path);
      _noteController.text +=
          '${_noteController.text.isEmpty ? '' : '\n'}![${picked.name}](${destination.path})';
    });
    _notesService.saveNote(widget.note);
  }

  void _removeImage(int index) {
    final removedPath = widget.note.imagePaths[index];
    setState(() {
      widget.note.imagePaths = List<String>.from(widget.note.imagePaths)
        ..removeAt(index);
      _noteController.text = _noteController.text
          .replaceAll(
            RegExp(r'!\[.*?\]\(' + RegExp.escape(removedPath) + r'\)'),
            '',
          )
          .trim();
    });
    _notesService.saveNote(widget.note);
  }

  void _onAcceptChange(PendingChange change) {
    setState(() {
      if (change.isAppend) {
        _noteController.text +=
            (_noteController.text.isEmpty ? '' : '\n') + change.newText;
      } else {
        final current = _noteController.text;
        final target = current.contains(change.oldText)
            ? change.oldText
            : change.oldText.trim();
        if (current.contains(target)) {
          _noteController.text = current.replaceFirst(target, change.newText);
        }
      }
    });
  }

  // ── Bot helpers ────────────────────────────────────────────────────────────

  double _getCursorX() => _noteController.text.isEmpty ? 20 : 100.0;

  double _getCursorY() {
    if (_noteController.text.isEmpty) return 100;
    final lines = _noteController.text.split('\n').length;
    return (lines * 22.0).clamp(50.0, MediaQuery.of(context).size.height - 100);
  }

  void _stopGeneration() {
    _gemmaService.stopGeneration();
    if (mounted) setState(() => _isProcessing = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('root@gemma:~# nano ${widget.note.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Insert image',
            onPressed: _insertImage,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white38, height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildNoteEditor()),
              _statusBar(context),
              // Sliding AI panel
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showAiChat
                    ? SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: AiChatPanel(
                          isProcessing: _isProcessing,
                          chatLog: _chatLog,
                          scrollController: _chatScrollController,
                          cmdController: _cmdController,
                          cmdFocusNode: _cmdFocusNode,
                          isRecording: _isRecording,
                          recordCountdown: _recordCountdown,
                          liveAmplitudes: _liveAmplitudes,
                          onMicPressed: _onMicPressed,
                          onSendPressed: () => _runCommand(),
                          onNoteAccept: _onAcceptChange,
                          onNoteReject: () {},
                          onStopPressed: _stopGeneration,
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
          // Draggable bot bubble
          _buildBotBubble(),
        ],
      ),
    );
  }

  Widget _buildNoteEditor() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (widget.note.imagePaths.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.note.imagePaths.length,
                itemBuilder: (context, index) {
                  final path = widget.note.imagePaths[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(path),
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 110,
                                  height: 110,
                                  color: Colors.white12,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                                ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: TextField(
              onTap: () => setState(() => _showAiChat = false),
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
                    '// type your notes here...\n// use the floating robot to interact with AI.',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotBubble() {
    return Positioned(
      left: _botLeft,
      top: _botTop,
      child: GestureDetector(
        onTap: () {
          final size = MediaQuery.of(context).size;
          const bubbleWidth = 90.0;
          const margin = 12.0;
          setState(() {
            _showAiChat = !_showAiChat;
            if (_showAiChat) {
              // Snap to top-right so the bot sits above the panel
              _botLeft = size.width - bubbleWidth - margin;
              _botTop = margin;
              _cmdFocusNode.requestFocus();
            }
          });
        },
        onPanUpdate: (details) {
          final size = MediaQuery.of(context).size;
          const bubbleSize = 90.0;
          setState(() {
            _botLeft = (_botLeft + details.delta.dx).clamp(
              0.0,
              size.width - bubbleSize,
            );
            _botTop = (_botTop + details.delta.dy).clamp(
              0.0,
              size.height - bubbleSize - 56.0,
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AsciiBot(
            state: _isProcessing
                ? BotState.thinking
                : (ModelStatusService.instance.isReady
                      ? BotState.awake
                      : BotState.exhausted),
            botX: _botLeft,
            botY: _botTop,
            targetX: _getCursorX(),
            targetY: _getCursorY(),
          ),
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
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
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
}
