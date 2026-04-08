import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../models/pending_change.dart';
import '../models/tool_execution_spinner.dart';
import 'model_status_service.dart';

typedef ChatLogCallback = void Function(dynamic item);
typedef NoteTextCallback = String Function();
typedef ApplyToNoteCallback = void Function(PendingChange change);

class GemmaService {
  dynamic _chatSession;
  bool _contextSent = false;

  static const _roleInstructions =
      'Role: AI Note Editor with full conversation memory. '
      'You remember everything the user has said in this session. '
      'Your goal is to proactively maintain and improve the user\'s note. '
      'Tools: [read_note_lines, apply_patch_to_note, edit_note_text, add_to_note_end]. '
      'Rules: '
      '1. ALWAYS reply with text OR use a tool. Never output an empty string. '
      '2. You will receive the note snapshot ONCE at the start. After that, '
      'rely on your memory and use read_note_lines to check current state. '
      '3. When the user refers to something from earlier in the conversation, '
      'use your memory to understand the context. '
      '4. Think step-by-step before making edits.';

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
    _contextSent = false;
  }

  void stopGeneration() {
    _chatSession?.stopGeneration();
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
        maxTokens: 8192,
        preferredBackend: ModelStatusService.instance.useGpu 
            ? PreferredBackend.gpu 
            : PreferredBackend.cpu,
        supportAudio: true,
      );

      if (_chatSession == null) {
        _chatSession = await model.createChat(
          supportsFunctionCalls: true,
          supportAudio: true,
          tools: _tools,
          systemInstruction: _roleInstructions,
          isThinking: true,
        );
        _contextSent = false;
      }

      final session = _chatSession!;

      // Send the note snapshot only on first interaction or after reset
      if (!_contextSent) {
        final fullText = getNoteText();
        final contextText = fullText.length > 3000
            ? '...\n${fullText.substring(fullText.length - 3000)}'
            : fullText;
        final contextMsg = fullText.trim().isEmpty
            ? '[NOTE IS EMPTY] The user has not written anything yet.'
            : 'CURRENT NOTE SNAPSHOT (you will not receive this again — use read_note_lines for updates):\n$contextText';
        await session.addQueryChunk(
          Message.text(text: contextMsg, isUser: true),
        );
        // Get a brief ack from the model so the context is committed to history
        await for (final _ in session.generateChatResponseAsync()) {}
        _contextSent = true;
      }

      // Send the actual user command — lightweight, no snapshot attached
      final prompt = textCommand.trim().isEmpty
          ? '[Voice command — see audio]'
          : textCommand;

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

            // ── Manual Tool Call Parser Fallback ────────────────────────────
            // Look for: <|tool_call>call:NAME{ARGS}<tool_call|>
            final toolCaptureRegex = RegExp(
              r'<\|tool_call>call:(\w+)(\{.*?\})<tool_call\|>',
              dotAll: true,
            );
            final match = toolCaptureRegex.firstMatch(textBuffer);

            if (match != null) {
              callName = match.group(1);
              final rawArgs = match.group(2) ?? '{}';
              try {
                // Pre-process JSON-like strings that might have unquoted keys
                String sanitizedJson = rawArgs
                    .replaceAllMapped(RegExp(r'(\w+):'), (m) => '"${m.group(1)}":')
                    .replaceAll('\\n', '\n');
                callArgs = jsonDecode(sanitizedJson) as Map<String, dynamic>;
              } catch (e) {
                // If deep parsing fails, fall back to simple regex for known keys
                callArgs = {
                  'content': RegExp(r'content:\s*"(.*?)"').firstMatch(rawArgs)?.group(1),
                  'new_text': RegExp(r'new_text:\s*"(.*?)"').firstMatch(rawArgs)?.group(1),
                  'old_text': RegExp(r'old_text:\s*"(.*?)"').firstMatch(rawArgs)?.group(1),
                  'start_line': int.tryParse(RegExp(r'start_line:\s*(\d+)').firstMatch(rawArgs)?.group(1) ?? ''),
                  'end_line': int.tryParse(RegExp(r'end_line:\s*(\d+)').firstMatch(rawArgs)?.group(1) ?? ''),
                };
              }
              extractedTool = true;
              // Clean textBuffer of the tool call string so it doesn't leak into UI
              textBuffer = textBuffer.replaceFirst(match.group(0)!, '').trim();
              break;
            }

            if (textBuffer.trim().isNotEmpty) {
              // Strip <thought> tags if model is in thinking mode
              String cleaned = textBuffer
                  .replaceAll(RegExp(r'<thought>.*?</thought>', dotAll: true), '')
                  .replaceAll('\\n', '\n')
                  .trim();

              if (cleaned.isNotEmpty) {
                final msg = '> AI: $cleaned';
                if (isFirstToken) {
                  onLog(msg);
                  isFirstToken = false;
                } else {
                  final lastIdx = getLogLength() - 1;
                  final last = getLogItem(lastIdx);
                  if (last is String && last.startsWith('> AI:')) {
                    onLogUpdate(lastIdx, msg);
                  } else {
                    onLog(msg);
                  }
                }
                onScrollToBottom();
              }
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
