import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../models/pending_change.dart';
import '../models/tool_execution_spinner.dart';

typedef ChatLogCallback = void Function(dynamic item);
typedef NoteTextCallback = String Function();
typedef ApplyToNoteCallback = void Function(PendingChange change);

class GemmaService {
  dynamic _chatSession;

  static const _roleInstructions =
      'Role: AI Note Editor. Your goal is to proactively maintain and improve '
      "the user's note. Tools: [read_note_lines, apply_patch_to_note, "
      'edit_note_text, add_to_note_end]. Rule: ALWAYS reply with text OR use a '
      'tool. Use read_note_lines to observe the content, then other tools to '
      'modify it. Never output an empty string.';

  static const List<Tool> _tools = [
    Tool(
      name: 'read_note_lines',
      description:
          'Read a specific range of lines from the current note to understand context before editing.',
      parameters: {
        'type': 'object',
        'properties': {
          'start_line': {
            'type': 'integer',
            'description': 'The line number to start observing from.',
          },
        },
        'required': ['start_line'],
      },
    ),
    Tool(
      name: 'apply_patch_to_note',
      description:
          'Apply a change to a specific range of lines in the note. Direct note modification.',
      parameters: {
        'type': 'object',
        'properties': {
          'start_line': {
            'type': 'integer',
            'description': 'Starting line for the patch.',
          },
          'end_line': {
            'type': 'integer',
            'description': 'Ending line for the patch.',
          },
          'new_text': {
            'type': 'string',
            'description': 'The corrected text to be written into the note.',
          },
        },
        'required': ['start_line', 'end_line', 'new_text'],
      },
    ),
    Tool(
      name: 'edit_note_text',
      description:
          'Perform a precise word or phrase replacement within the entire note content.',
      parameters: {
        'type': 'object',
        'properties': {
          'old_text': {
            'type': 'string',
            'description': 'The exact text sequence currently in the note.',
          },
          'new_text': {
            'type': 'string',
            'description': 'The new text to replace it with.',
          },
        },
        'required': ['old_text', 'new_text'],
      },
    ),
    Tool(
      name: 'add_to_note_end',
      description:
          'Append new content or sections to the very end of the current note.',
      parameters: {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': 'The text to add to the note.',
          },
        },
        'required': ['content'],
      },
    ),
  ];

  void resetSession() {
    _chatSession = null;
  }

  /// Runs the full agentic tool loop.
  /// [onLog] is called each time a new item should be added to the chat log.
  /// [onLogUpdate] is called to replace the last log item in place (streaming).
  /// [onScrollToBottom] is called whenever new content appears.
  /// [getNoteText] returns the current note content.
  /// [onPendingChange] is called when the model proposes a change.
  Future<void> runCommand({
    required String textCommand,
    Uint8List? audioBytes,
    List<double>? recordedAmplitudes,
    required NoteTextCallback getNoteText,
    required ChatLogCallback onLog,
    required void Function(int index, dynamic item) onLogUpdate,
    required VoidCallback onScrollToBottom,
    required ApplyToNoteCallback onPendingChange,
    required void Function() onDone,
    required void Function(String error) onError,
    required int Function() getLogLength,
    required dynamic Function(int index) getLogItem,
    required VoidCallback removeLastLog,
  }) async {
    try {
      final model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        supportAudio: true,
      );

      final fullText = getNoteText();
      final contextText = fullText.length > 2000
          ? '...\\n${fullText.substring(fullText.length - 2000)}'
          : fullText;

      final prompt = 'Snapshot: $contextText. Command: $textCommand';

      if (_chatSession == null) {
        _chatSession = await model.createChat(
          supportsFunctionCalls: true,
          supportAudio: true,
          tools: _tools,
          systemInstruction: _roleInstructions,
        );
      }

      final session = _chatSession!;
      if (audioBytes != null) {
        await session.addQueryChunk(
          Message.withAudio(text: prompt, audioBytes: audioBytes, isUser: true),
        );
      } else {
        await session.addQueryChunk(
          Message.text(text: prompt, isUser: true),
        );
      }

      bool isRunning = true;
      int iterations = 0;

      while (isRunning && iterations < 5) {
        iterations++;
        onLog(
          ToolExecutionSpinner(
            iterations == 1 ? 'PROCESSING' : 'ANALYZING OUTCOME',
          ),
        );
        onScrollToBottom();

        final responseStream = session.generateChatResponseAsync();
        bool extractedTool = false;
        bool isFirstToken = true;
        String textBuffer = '';
        String? callName;
        Map<String, dynamic>? callArgs;

        await for (final chunk in responseStream) {
          if (isFirstToken) {
            final last = getLogLength() > 0 ? getLogItem(getLogLength() - 1) : null;
            if (last is ToolExecutionSpinner) {
              removeLastLog();
            }
          }

          if (chunk is TextResponse) {
            textBuffer += chunk.token;
            if (textBuffer.trim().isNotEmpty) {
              final cleaned = textBuffer.replaceAll('\\n', '\n').trim();
              final msg = '> AI: $cleaned';
              if (isFirstToken) {
                onLog(msg);
                isFirstToken = false;
              } else {
                final lastIdx = getLogLength() - 1;
                final last = getLogItem(lastIdx);
                if (last is String) {
                  onLogUpdate(lastIdx, msg);
                }
              }
              onScrollToBottom();
            }
          } else if (chunk is FunctionCallResponse) {
            callName = chunk.name;
            callArgs = chunk.args;
            extractedTool = true;
            break;
          }
        }

        if (extractedTool && callName != null) {
          // Strip trailing AI stub text
          if (!isFirstToken) {
            final lastIdx = getLogLength() - 1;
            final last = getLogItem(lastIdx);
            if (last is String && last.startsWith('> AI:')) {
              removeLastLog();
            }
          }

          String toolResult = '';
          final args = callArgs ?? {};

          if (callName == 'read_note_lines') {
            int start = 1;
            final arg = args['start_line'];
            if (arg != null) {
              start = arg is int ? arg : int.tryParse(arg.toString()) ?? 1;
            }
            final lines = getNoteText().split('\n');
            final startIndex = (start - 1).clamp(0, lines.length);
            final endIndex = (startIndex + 50).clamp(0, lines.length);
            final buffer = StringBuffer();
            for (int i = startIndex; i < endIndex; i++) {
              buffer.write('${i + 1}: ${lines[i]}\\n');
            }
            toolResult = buffer.toString();
            onLog('> READ [LINES $start-${startIndex + 50}]');
            onScrollToBottom();
          } else if (callName == 'apply_patch_to_note') {
            final start =
                int.tryParse(args['start_line']?.toString() ?? '1') ?? 1;
            final end =
                int.tryParse(args['end_line']?.toString() ?? '1') ?? 1;
            final newT =
                (args['new_text']?.toString() ?? '').replaceAll('\\n', '\n');
            final lines = getNoteText().split('\n');
            final oldLines = lines.sublist(
              (start - 1).clamp(0, lines.length),
              end.clamp(0, lines.length),
            );
            final change = PendingChange(
              oldText: oldLines.join('\n'),
              newText: newT,
              isAppend: false,
            );
            onLog(change);
            onPendingChange(change);
            onScrollToBottom();
            isRunning = false;
          } else if (callName == 'edit_note_text') {
            final old =
                (args['old_text']?.toString() ?? '').replaceAll('\\n', '\n');
            final newT =
                (args['new_text']?.toString() ?? '').replaceAll('\\n', '\n');
            final change = PendingChange(
              oldText: old,
              newText: newT,
              isAppend: old.isEmpty,
            );
            onLog(change);
            onPendingChange(change);
            onScrollToBottom();
            isRunning = false;
          } else if (callName == 'add_to_note_end') {
            final newT =
                (args['content']?.toString() ?? '').replaceAll('\\n', '\n');
            final change = PendingChange(
              oldText: '',
              newText: newT,
              isAppend: true,
            );
            onLog(change);
            onPendingChange(change);
            onScrollToBottom();
            isRunning = false;
          }

          await session.addQueryChunk(
            Message.toolResponse(
              toolName: callName,
              response: {
                'result': toolResult,
                'status': 'ok',
              },
            ),
          );
        } else {
          isRunning = false;
          if (textBuffer.trim().isEmpty && iterations == 1) {
            onLog('> AI:\n[No output. Try rephrasing.]');
            onScrollToBottom();
          }
        }
      }
    } catch (e) {
      onError('> FATAL ERROR: $e');
      onScrollToBottom();
    } finally {
      onDone();
    }
  }
}
