import 'package:flutter/material.dart';
import '../services/model_status_service.dart';
import '../widgets/ascii_bot.dart';
import 'home_screen.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  final _modelService = ModelStatusService.instance;

  @override
  void initState() {
    super.initState();
    _modelService.addListener(_onModelUpdate);
    // Start model preparation in the background
    _modelService.prepareModel();
    // Navigate to the app after a brief splash
    _navigateAfterSplash();
  }

  @override
  void dispose() {
    _modelService.removeListener(_onModelUpdate);
    super.dispose();
  }

  void _onModelUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _navigateAfterSplash() async {
    // Show splash for 2 seconds regardless of model status
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExhausted = _modelService.status != ModelStatus.ready;
    final isDownloading = _modelService.status == ModelStatus.downloading;
    final progress = _modelService.downloadProgress;

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
                  state: isExhausted ? BotState.exhausted : BotState.awake,
                ),
              ),
            ),
            const SizedBox(height: 64),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                _modelService.statusMessage,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 16),
              Text(
                '> DOWNLOADING: ${_modelService.progressBar} ${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '> SIZE: ${(4.5 * progress).toStringAsFixed(2)} GB / 4.50 GB',
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
