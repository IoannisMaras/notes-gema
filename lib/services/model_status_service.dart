import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Global singleton tracking the AI model's lifecycle.
/// Widgets can listen to [notifier] for reactive updates.
enum ModelStatus { downloading, initializing, ready, error }

class ModelStatusService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ModelStatusService _instance = ModelStatusService._();
  static ModelStatusService get instance => _instance;
  ModelStatusService._();

  // ── State ──────────────────────────────────────────────────────────────────
  ModelStatus _status = ModelStatus.downloading;
  double _downloadProgress = 0.0;
  String _statusMessage = '> init system...';
  String? _errorMessage;

  ModelStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isReady => _status == ModelStatus.ready;

  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  // ── Progress bar ASCII art ─────────────────────────────────────────────────
  String get progressBar {
    const total = 20;
    final filled = (total * _downloadProgress).round();
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

  // ── Initialization (call once from main or boot screen) ────────────────────
  Future<void> prepareModel() async {
    if (_status == ModelStatus.ready) return;

    try {
      _update(ModelStatus.downloading, '> downloading AI model...');

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        _statusMessage =
            '> DOWNLOADING: $progressBar ${(_downloadProgress * 100).toStringAsFixed(1)}%';
        notifyListeners();
      }).install();

      _update(ModelStatus.initializing, '> pre-warming model context...');

      await FlutterGemma.getActiveModel(
        maxTokens: 8192,
        preferredBackend: PreferredBackend.gpu,
        supportAudio: true,
      );

      _update(ModelStatus.ready, '> system online.');
    } catch (e) {
      _errorMessage = e.toString();
      _update(ModelStatus.error, '> FATAL ENGINE ERROR: $e');
    }
  }

  void _update(ModelStatus status, String message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }
}
