import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_editor/super_editor.dart'; // NEW IMPORT

import '../models/note.dart';
import '../models/pending_change.dart';
import '../models/voice_message.dart';
import '../services/gemma_service.dart';
import '../services/model_status_service.dart';
import '../services/notes_service.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/ascii_bot.dart';

class NotesScreen extends StatefulWidget {
  final Note note;
  const NotesScreen({super.key, required this.note});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // ── Super Editor Controllers ───────────────────────────────────────────────
  late MutableDocument _doc;
  late Editor _editor;
  late MutableDocumentComposer _composer;

  // ── Controllers & services ─────────────────────────────────────────────────
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

    // Initialize Super Editor Document
    _doc = _createInitialDocument();
    _composer = MutableDocumentComposer(); // <-- CHANGED

    // Use the standard factory instead of the raw Editor constructor
    _editor = createDefaultDocumentEditor(
      // <-- CHANGED
      document: _doc,
      composer: _composer,
    );

    // Listen for changes to save the note
    _doc.addListener(_onNoteChanged);

    ModelStatusService.instance.addListener(_onModelStatusChanged);

    // Position the bot bubble
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
    _doc.removeListener(_onNoteChanged);
    _composer.dispose();
    _cmdFocusNode.dispose();
    _cmdController.dispose();
    ModelStatusService.instance.removeListener(_onModelStatusChanged);
    _ampSubscription?.cancel();
    _countdownTimer?.cancel();
    _recorder.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ── Document Setup & Persistence ───────────────────────────────────────────

  MutableDocument _createInitialDocument() {
    final nodes = <DocumentNode>[];

    // Load existing images if any
    for (String path in widget.note.imagePaths) {
      nodes.add(ImageNode(id: Editor.createNodeId(), imageUrl: path));
    }

    // Load text
    if (widget.note.content.trim().isNotEmpty) {
      final lines = widget.note.content.split('\n');
      for (String line in lines) {
        nodes.add(
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(line), // <-- Removed "text:"
          ),
        );
      }
    } else {
      nodes.add(
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(""), // <-- Removed "text:"
        ),
      );
    }

    return MutableDocument(nodes: nodes);
  }

  String _extractTextFromDocument() {
    final buffer = StringBuffer();
    for (final node in _doc) {
      // <-- Removed .nodes
      if (node is ParagraphNode) {
        buffer.writeln(node.text.text);
      }
    }
    return buffer.toString().trim();
  }

  void _onNoteChanged(dynamic event) {
    final note = widget.note;

    note.content = _extractTextFromDocument();

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

    // Save image paths based on current Document state
    note.imagePaths = _doc
        .whereType<ImageNode>()
        .map((n) => n.imageUrl)
        .toList();

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
      getNoteText: () => _extractTextFromDocument(),
      onLog: (item) => setState(() => _chatLog.add(item)),
      onLogUpdate: (index, item) => setState(() => _chatLog[index] = item),
      onScrollToBottom: _scrollToBottom,
      onPendingChange: (_) {},
      onDone: () {
        if (mounted) {
          setState(() => _isProcessing = false);
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

  // ── Image Handling ─────────────────────────────────────────────────────────

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
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.path == null) return;

    final source = File(picked.path!);
    final imagesDir = await _getImageDirectory();
    final destinationPath =
        '${imagesDir.path}/${widget.note.id}_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    await source.copy(destinationPath);

    // Find the current cursor selection index or default to the end of the document
    int insertIndex = _doc.length;
    if (_composer.selection != null) {
      final selectedNode = _doc.getNodeById(_composer.selection!.extent.nodeId);
      if (selectedNode != null) {
        insertIndex = _doc.getNodeIndexById(selectedNode.id) + 1;
      }
    }

    _editor.execute([
      InsertNodeAtIndexRequest(
        nodeIndex: insertIndex,
        newNode: ImageNode(
          id: Editor.createNodeId(),
          imageUrl: destinationPath,
        ),
      ),
    ]);
  }

  void _onAcceptChange(PendingChange change) {
    if (change.isAppend) {
      _editor.execute([
        InsertNodeAtIndexRequest(
          nodeIndex: _doc.toList().length, // <-- Fixed nodes.length
          newNode: ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(change.newText), // <-- Removed "text:"
          ),
        ),
      ]);
    } else {
      _editor.execute([
        InsertNodeAtIndexRequest(
          nodeIndex: _doc.toList().length, // <-- Fixed nodes.length
          newNode: ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(
              "\n[AI Change]: ${change.newText}",
            ), // <-- Removed "text:"
          ),
        ),
      ]);
    }
  }

  // ── Bot helpers ────────────────────────────────────────────────────────────

  double _getCursorX() => 100.0;
  double _getCursorY() => (MediaQuery.of(context).size.height / 2).clamp(
    50.0,
    MediaQuery.of(context).size.height - 100,
  );

  void _stopGeneration() {
    _gemmaService.stopGeneration();
    if (mounted) setState(() => _isProcessing = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF1E1E1E,
      ), // Dark theme to match your original styling
      appBar: AppBar(
        title: Text('root@gemma:~# nano ${widget.note.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Insert image block',
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
              // Super Editor
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_showAiChat) setState(() => _showAiChat = false);
                  },
                  child: SuperEditor(
                    editor: _editor,
                    componentBuilders: [
                      _FileImageComponentBuilder(_editor),
                      ...defaultComponentBuilders,
                    ],
                    stylesheet: defaultStylesheet.copyWith(
                      addRulesAfter: [
                        StyleRule(BlockSelector.all, (doc, node) {
                          return {
                            "textStyle": const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Courier',
                              fontSize: 16,
                            ),
                          };
                        }),
                      ],
                    ),
                  ),
                ),
              ),
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
}

class CustomImageComponentViewModel extends ImageComponentViewModel {
  CustomImageComponentViewModel({
    required super.nodeId,
    required super.imageUrl,
    super.expectedSize,
    super.selection,
    super.selectionColor = Colors.transparent,
    this.width,
    this.height,
    this.alignment,
  });

  double? width;
  double? height;
  String? alignment;

  @override
  CustomImageComponentViewModel copy() {
    return CustomImageComponentViewModel(
      nodeId: nodeId,
      imageUrl: imageUrl,
      expectedSize: expectedSize,
      selection: selection,
      selectionColor: selectionColor,
      width: width,
      height: height,
      alignment: alignment,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is CustomImageComponentViewModel &&
          width == other.width &&
          height == other.height &&
          alignment == other.alignment;

  @override
  int get hashCode => Object.hash(super.hashCode, width, height, alignment);
}

class _FileImageComponentBuilder implements ComponentBuilder {
  const _FileImageComponentBuilder(this.editor);
  final Editor editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ImageNode) return null;

    final w = node.metadata['width'] as double?;
    final h = node.metadata['height'] as double?;
    final align = node.metadata['alignment'] as String? ?? 'center';

    return CustomImageComponentViewModel(
      nodeId: node.id,
      imageUrl: node.imageUrl,
      expectedSize: node.expectedBitmapSize,
      width: w,
      height: h,
      alignment: align,
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! CustomImageComponentViewModel) return null;

    final imageWidget = (BuildContext context, String imageUrl) {
      if (imageUrl.startsWith('/data/') || imageUrl.startsWith('file://') || imageUrl.startsWith('/storage/')) {
        final path = imageUrl.replaceFirst('file://', '');
        return Image.file(File(path), fit: BoxFit.fill);
      }
      return Image.network(imageUrl, fit: BoxFit.fill);
    };

    return _ResizableImageWidget(
      componentKey: componentContext.componentKey,
      editor: editor,
      nodeId: componentViewModel.nodeId,
      imageUrl: componentViewModel.imageUrl,
      initialWidth: componentViewModel.width ?? 300.0,
      initialHeight: componentViewModel.height ?? 200.0,
      alignment: componentViewModel.alignment ?? 'left',
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      imageBuilder: imageWidget,
    );
  }
}

class _ResizableImageWidget extends StatefulWidget {
  final GlobalKey componentKey;
  final Editor editor;
  final String nodeId;
  final String imageUrl;
  final double initialWidth;
  final double initialHeight;
  final String? alignment;
  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final Widget Function(BuildContext, String) imageBuilder;

  const _ResizableImageWidget({
    Key? key,
    required this.componentKey,
    required this.editor,
    required this.nodeId,
    required this.imageUrl,
    required this.initialWidth,
    required this.initialHeight,
    required this.alignment,
    required this.selection,
    required this.selectionColor,
    required this.imageBuilder,
  }) : super(key: key);

  @override
  State<_ResizableImageWidget> createState() => _ResizableImageWidgetState();
}

class _ResizableImageWidgetState extends State<_ResizableImageWidget> {
  late double _width;
  late double _height;
  double _dragDeltaY = 0;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
    _height = widget.initialHeight;
  }

  void _updateAlignment(String alignment) {
    final node = widget.editor.document.getNodeById(widget.nodeId);
    if (node is ImageNode) {
      final newMetadata = Map<String, dynamic>.from(node.metadata);
      newMetadata['alignment'] = alignment;
      widget.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: widget.nodeId,
          newNode: ImageNode(
            id: widget.nodeId,
            imageUrl: node.imageUrl,
            expectedBitmapSize: node.expectedBitmapSize,
            altText: node.altText,
            metadata: newMetadata,
          ),
        )
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    AlignmentGeometry alignGeometry;
    switch (widget.alignment) {
      case 'left':
        alignGeometry = Alignment.centerLeft;
        break;
      case 'right':
        alignGeometry = Alignment.centerRight;
        break;
      case 'center':
      default:
        alignGeometry = Alignment.center;
    }
    
    final bool isSelected = widget.selection != null;

    return BoxComponent(
      key: widget.componentKey,
      child: Container(
        width: double.infinity,
        alignment: alignGeometry,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                // Explicitly select the image node native to SuperEditor on tap
                widget.editor.execute([
                  ChangeSelectionRequest(
                    DocumentSelection(
                      base: DocumentPosition(
                        nodeId: widget.nodeId,
                        nodePosition: const UpstreamDownstreamNodePosition.upstream(),
                      ),
                      extent: DocumentPosition(
                        nodeId: widget.nodeId,
                        nodePosition: const UpstreamDownstreamNodePosition.downstream(),
                      ),
                    ),
                    SelectionChangeType.placeCaret,
                    SelectionReason.userInteraction,
                  )
                ]);
              },
              child: Container(
                width: _width,
                height: _height,
                decoration: BoxDecoration(
                  border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.imageBuilder(context, widget.imageUrl),
                    if (isSelected)
                      Container(color: widget.selectionColor.withOpacity(0.3)), // Native-like selection tint
                  ],
                ),
              ),
            ),
            if (isSelected) ...[
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _width = (_width + details.delta.dx).clamp(50.0, 800.0);
                        _height = (_height + details.delta.dy).clamp(50.0, 800.0);
                      });
                    },
                    onPanEnd: (_) {
                      final node = widget.editor.document.getNodeById(widget.nodeId);
                      if (node is ImageNode) {
                        final newMetadata = Map<String, dynamic>.from(node.metadata);
                        newMetadata['width'] = _width;
                        newMetadata['height'] = _height;
                        widget.editor.execute([
                          ReplaceNodeRequest(
                            existingNodeId: widget.nodeId,
                            newNode: ImageNode(
                              id: widget.nodeId,
                              imageUrl: node.imageUrl,
                              expectedBitmapSize: node.expectedBitmapSize,
                              altText: node.altText,
                              metadata: newMetadata,
                            ),
                          )
                        ]);
                      }
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: -30,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onPanUpdate: (details) {
                            _dragDeltaY += details.delta.dy;
                            if (_dragDeltaY.abs() > 40) {
                              final nodeIndex = widget.editor.document.getNodeIndexById(widget.nodeId);
                              if (_dragDeltaY > 0 && nodeIndex < widget.editor.document.nodeCount - 1) {
                                widget.editor.execute([
                                  MoveNodeRequest(nodeId: widget.nodeId, newIndex: nodeIndex + 1)
                                ]);
                                _dragDeltaY -= 40;
                              } else if (_dragDeltaY < 0 && nodeIndex > 0) {
                                widget.editor.execute([
                                  MoveNodeRequest(nodeId: widget.nodeId, newIndex: nodeIndex - 1)
                                ]);
                                _dragDeltaY += 40;
                              } else {
                                _dragDeltaY = 0;
                              }
                            }
                          },
                          onPanEnd: (_) => _dragDeltaY = 0,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.drag_indicator, size: 20, color: Colors.blueAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.align_horizontal_left, size: 20, color: Colors.white),
                          onPressed: () {
                             _updateAlignment('left');
                             setState(() {});
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.align_horizontal_center, size: 20, color: Colors.white),
                          onPressed: () {
                             _updateAlignment('center');
                             setState(() {});
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.align_horizontal_right, size: 20, color: Colors.white),
                          onPressed: () {
                             _updateAlignment('right');
                             setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
