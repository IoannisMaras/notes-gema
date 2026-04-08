import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'gpu_helper.dart';

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
  bool _useGpu = true;

  ModelStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isReady => _status == ModelStatus.ready;
  bool get useGpu => _useGpu;

  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  // ── Stats ──────────────────────────────────────────────────────────────────
  String get memoryUsage => _useGpu ? '2.5 GB / 4.0 GB (vRAM)' : '2.5 GB / 8.0 GB (RAM)';
  String get activeBackend => _useGpu ? 'WebGPU (Metal/Vulkan/D3D12)' : 'CPU (XNNPACK / Fallback)';

  // ── Progress bar ASCII art ─────────────────────────────────────────────────
  String get progressBar {
    const total = 20;
    final filled = (total * _downloadProgress).round();
    final bar = StringBuffer('[');
    for (int i = 0; i < total; i++) {
      if (i < filled) {
        bar.write('■');
      } else if (i == filled) {
        bar.write('▶');
      } else {
        bar.write('░');
      }
    }
    bar.write(']');
    return bar.toString();
  }

  // ── Initialization (call once from main or boot screen) ────────────────────
  Future<void> prepareModel() async {
    if (_status == ModelStatus.ready) return;

    try {
      _update(ModelStatus.downloading, '> initialising neuro-engine...');

      // 1. Check WebGPU support before proceeding (only on Web)
      if (kIsWeb) {
        try {
          _useGpu = await checkWebGPUSupport();
        } catch (e) {
          _useGpu = false;
        }
      }

      // 2. Install Model
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        _statusMessage =
            '> CORE_DL: $progressBar ${(_downloadProgress * 100).toStringAsFixed(1)}%';
        notifyListeners();
      }).install();

      final backendLabel = _useGpu ? '[WebGPU]' : '[CPU_FALLBACK]';
      _update(ModelStatus.initializing, '> mapping neural weights $backendLabel...');

      // 3. Initialize Engine
      try {
        await FlutterGemma.getActiveModel(
          maxTokens: 8192,
          preferredBackend: _useGpu ? PreferredBackend.gpu : PreferredBackend.cpu,
          supportAudio: true,
        );
      } catch (e) {
        if (_useGpu) {
          _useGpu = false;
          _update(ModelStatus.initializing, '> engine fallback: switching to CPU...');
          await FlutterGemma.getActiveModel(
            maxTokens: 8192,
            preferredBackend: PreferredBackend.cpu,
            supportAudio: true,
          );
        } else {
          rethrow;
        }
      }

      _update(ModelStatus.ready, '> neural interface: ONLINE');
    } catch (e) {
      _errorMessage = e.toString();
      _update(ModelStatus.error, '> ENGINE_FAULT: $e');
    }
  }

  void _update(ModelStatus status, String message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }
}
