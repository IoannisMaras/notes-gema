import 'package:flutter/material.dart';
import '../models/pending_change.dart';
import '../models/tool_execution_spinner.dart';
import '../models/voice_message.dart';
import '../services/model_status_service.dart';
import 'ascii_loader.dart';
import 'audio_waveform.dart';
import 'pending_change_card.dart';

/// The sliding AI communication panel rendered inside NotesScreen.
class AiChatPanel extends StatefulWidget {
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
  final VoidCallback onStopPressed;

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
    required this.onStopPressed,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> with SingleTickerProviderStateMixin {
  final _modelService = ModelStatusService.instance;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _modelService.addListener(_onModelUpdate);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _modelService.removeListener(_onModelUpdate);
    _pulseController.dispose();
    super.dispose();
  }

  void _onModelUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // If model isn't ready, show loading overlay instead of chat
    if (!_modelService.isReady) {
      return _buildLoadingState();
    }

    return Column(
      children: [
        // ── Header bar ──────────────────────────────────────────────────
        _buildHeader('AI LINK ESTABLISHED', Colors.greenAccent),

        // ── Chat log ─────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: widget.chatLog.length,
            itemBuilder: (context, index) {
              final item = widget.chatLog[index];
              final isLast = index == widget.chatLog.length - 1;
              final showCursor = widget.isProcessing && isLast;
              return _buildChatItem(item, showCursor);
            },
          ),
        ),

        // ── Command bar ──────────────────────────────────────────────────
        _CommandBar(
          isProcessing: widget.isProcessing,
          isRecording: widget.isRecording,
          recordCountdown: widget.recordCountdown,
          liveAmplitudes: widget.liveAmplitudes,
          cmdController: widget.cmdController,
          cmdFocusNode: widget.cmdFocusNode,
          onMicPressed: widget.onMicPressed,
          onSendPressed: widget.onSendPressed,
          onStopPressed: widget.onStopPressed,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    final status = _modelService.status;
    final progress = _modelService.downloadProgress;

    return Column(
      children: [
        // ── Header bar — different color to signal not-ready ─────────────
        _buildHeader(
          status == ModelStatus.error
              ? 'AI LINK ERROR'
              : 'AI LINK CONNECTING...',
          status == ModelStatus.error
              ? Colors.redAccent
              : Colors.amber,
        ),

        // ── Loading content ──────────────────────────────────────────────
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == ModelStatus.downloading) ...[
                    const AsciiLoader(message: 'DOWNLOADING MODEL'),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% — ${(4.5 * progress).toStringAsFixed(2)} GB / 4.50 GB',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '// notes are fully usable while AI loads.\n'
                      '// AI features will activate automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                  ] else if (status == ModelStatus.initializing) ...[
                    const AsciiLoader(message: 'WARMING UP'),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent,
                      ),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '// pre-warming model context...\n'
                      '// almost ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                  ] else if (status == ModelStatus.error) ...[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '> ERROR: ${_modelService.errorMessage ?? 'Unknown'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _modelService.prepareModel(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.greenAccent,
                        side: const BorderSide(color: Colors.greenAccent),
                      ),
                      child: const Text('RETRY'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String text, Color color) {
    final bool isReady = _modelService.isReady;
    final bool isError = _modelService.status == ModelStatus.error;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        // Only pulse if not ready and not in error state
        final opacity = (isReady || isError)
            ? 1.0
            : 0.4 + (_pulseController.value * 0.6);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          width: double.infinity,
          color: Colors.black87,
          child: Text(
            text,
            style: TextStyle(
              color: color.withValues(alpha: opacity),
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
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
          onAccept: widget.onNoteAccept,
          onReject: widget.onNoteReject,
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
  final VoidCallback onStopPressed;

  const _CommandBar({
    required this.isProcessing,
    required this.isRecording,
    required this.recordCountdown,
    required this.liveAmplitudes,
    required this.cmdController,
    required this.cmdFocusNode,
    required this.onMicPressed,
    required this.onSendPressed,
    required this.onStopPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black,
      child: Row(
        children: [
          if (isProcessing) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'AWAKENING AI...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontFamily: 'Courier',
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.white54, size: 20),
              onPressed: onStopPressed,
              tooltip: 'HALT GENERATION',
            ),
          ] else ...[
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
