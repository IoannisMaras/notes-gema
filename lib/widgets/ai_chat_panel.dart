import 'package:flutter/material.dart';
import '../models/pending_change.dart';
import '../models/tool_execution_spinner.dart';
import '../models/voice_message.dart';
import 'ascii_loader.dart';
import 'audio_waveform.dart';
import 'pending_change_card.dart';

/// The sliding AI communication panel rendered inside NotesScreen.
class AiChatPanel extends StatelessWidget {
  final bool isProcessing;
  final List<dynamic> chatLog;
  final ScrollController scrollController;
  final TextEditingController cmdController;
  final FocusNode cmdFocusNode;
  final bool isRecording;
  final int recordCountdown;
  final List<double> liveAmplitudes;
  final VoidCallback onMicPressed;
  final VoidCallback onSendPressed;
  final TerminalNotesControllerCallback onNoteAccept;
  final VoidCallback onNoteReject;

  const AiChatPanel({
    super.key,
    required this.isProcessing,
    required this.chatLog,
    required this.scrollController,
    required this.cmdController,
    required this.cmdFocusNode,
    required this.isRecording,
    required this.recordCountdown,
    required this.liveAmplitudes,
    required this.onMicPressed,
    required this.onSendPressed,
    required this.onNoteAccept,
    required this.onNoteReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header bar ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          width: double.infinity,
          color: Colors.black87,
          child: const Text(
            'AI LINK ESTABLISHED',
            style: TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // ── Chat log ─────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: chatLog.length,
            itemBuilder: (context, index) {
              final item = chatLog[index];
              final isLast = index == chatLog.length - 1;
              final showCursor = isProcessing && isLast;
              return _buildChatItem(item, showCursor);
            },
          ),
        ),

        // ── Command bar ──────────────────────────────────────────────────
        _CommandBar(
          isProcessing: isProcessing,
          isRecording: isRecording,
          recordCountdown: recordCountdown,
          liveAmplitudes: liveAmplitudes,
          cmdController: cmdController,
          cmdFocusNode: cmdFocusNode,
          onMicPressed: onMicPressed,
          onSendPressed: onSendPressed,
        ),
      ],
    );
  }

  Widget _buildChatItem(dynamic item, bool showCursor) {
    if (item is VoiceMessage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            const Text(
              '> USER [AUDIO]: ',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Courier',
                fontSize: 14,
              ),
            ),
            AudioMessengerWaveform(
              amplitudes: item.amplitudes,
              isStatic: true,
            ),
          ],
        ),
      );
    }

    if (item is String) {
      final text = showCursor ? '$item █' : item;
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
    }

    if (item is ToolExecutionSpinner) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: AsciiLoader(message: item.message),
      );
    }

    if (item is PendingChange) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: PendingChangeCard(
          change: item,
          onAccept: onNoteAccept,
          onReject: onNoteReject,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

typedef TerminalNotesControllerCallback = void Function(PendingChange change);

// ── Private command bar ────────────────────────────────────────────────────────

class _CommandBar extends StatelessWidget {
  final bool isProcessing;
  final bool isRecording;
  final int recordCountdown;
  final List<double> liveAmplitudes;
  final TextEditingController cmdController;
  final FocusNode cmdFocusNode;
  final VoidCallback onMicPressed;
  final VoidCallback onSendPressed;

  const _CommandBar({
    required this.isProcessing,
    required this.isRecording,
    required this.recordCountdown,
    required this.liveAmplitudes,
    required this.cmdController,
    required this.cmdFocusNode,
    required this.onMicPressed,
    required this.onSendPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black,
      child: Row(
        children: [
          if (isProcessing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else ...[
            Text(
              isRecording ? '${recordCountdown}s' : '> ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Expanded(
              child: isRecording
                  ? Center(
                      child: AudioMessengerWaveform(amplitudes: liveAmplitudes),
                    )
                  : TextField(
                      controller: cmdController,
                      focusNode: cmdFocusNode,
                      enabled: !isProcessing,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'ask AI a question...',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                      onSubmitted: (_) => onSendPressed(),
                    ),
            ),
            IconButton(
              icon: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: isRecording ? Colors.redAccent : Colors.white54,
              ),
              onPressed: onMicPressed,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white54),
              onPressed: onSendPressed,
            ),
          ],
        ],
      ),
    );
  }
}
