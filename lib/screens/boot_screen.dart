import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../widgets/ascii_bot.dart';
import 'home_screen.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  final List<String> _logs = ['> init system...'];
  bool _isDownloading = false;
  bool _isExhausted = true;
  double _progress = 0.0;

  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  @override
  void initState() {
    super.initState();
    _checkAndPrepareModel();
  }

  void _log(String message) => setState(() => _logs.add(message));

  String _progressBar(double p) {
    const total = 20;
    final filled = (total * p).round();
    final bar = StringBuffer('[');
    for (int i = 0; i < total; i++) {
      if (i < filled) {
        bar.write('#');
      } else if (i == filled) {
        bar.write('>');
      } else {
        bar.write('-');
      }
    }
    bar.write(']');
    return bar.toString();
  }

  Future<void> _checkAndPrepareModel() async {
    try {
      _log('> checking and syncing AI model registry...');
      setState(() {
        _isDownloading = true;
        _isExhausted = true;
      });

      _log('> downloading valid Gemma artifact...');

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        if (mounted) setState(() => _progress = progress / 100.0);
      }).install();

      setState(() {
        _isDownloading = false;
        _isExhausted = false;
      });
      _log('> installation complete. awakening...');

      _log('> pre-warming model context...');
      await FlutterGemma.getActiveModel(
        maxTokens: 10000,
        preferredBackend: PreferredBackend.gpu,
        supportAudio: true,
      );

      _log('> system online.');
      await Future.delayed(const Duration(milliseconds: 1400));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isDownloading = false);
      _log('> FATAL ENGINE ERROR: $e');
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
              child: _BotBubble(
                child: AsciiBot(
                  state: _isExhausted ? BotState.exhausted : BotState.awake,
                ),
              ),
            ),
            const SizedBox(height: 64),
            ..._logs.map(
              (l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Text(
                '> DOWNLOADING: ${_progressBar(_progress)} ${(_progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '> SIZE: ${(4.5 * _progress).toStringAsFixed(2)} GB / 4.50 GB',
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

class _BotBubble extends StatelessWidget {
  final Widget child;
  const _BotBubble({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}
