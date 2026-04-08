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

  static const _remoteModelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  // static const _localModelUrl = './models/gemma-4-E2B-it.litertlm';

  // ── Stats ──────────────────────────────────────────────────────────────────
  String get memoryUsage => _useGpu ? '2.5 GB / 4.0 GB (vRAM)' : '2.5 GB / 8.0 GB (RAM)';
  String get activeBackend => _useGpu ? 'WebGPU (Metal/Vulkan/D3D12)' : 'CPU (XNNPACK / Fallback)';

  void forceCpu() {
    if (_useGpu) {
      _useGpu = false;
      _statusMessage = '> emergency fallback: CPU engagement active.';
      notifyListeners();
    }
  }

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
      String targetUrl = _remoteModelUrl;
      
      if (kIsWeb) {
        // We look for the file in the root web folder
        final modelFileName = 'gemma-4-E2B-it.litertlm';
        final isLocal = await checkFileExists(modelFileName);
        
        if (isLocal) {
          // IMPORTANT: Use absolute path to bypass plugin normalization issues
          // We must provide a full HTTP/HTTPS URL for the web backend
          targetUrl = Uri.base.resolve(modelFileName).toString();
          debugPrint('[SYSTEM] Root-level local model detected at: $targetUrl');
        } else {
          debugPrint('[SYSTEM] Local model not found at root, falling back to remote URL.');
        }
      }

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(targetUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        final source = targetUrl == _remoteModelUrl ? 'CLOUD' : 'LOCAL';
        _statusMessage =
            '> ($source) LOADING: $progressBar ${(_downloadProgress * 100).toStringAsFixed(1)}%';
        notifyListeners();
      }).install();

      final backendLabel = _useGpu ? '[WebGPU]' : '[CPU_FALLBACK]';
      _update(ModelStatus.initializing, '> mapping neural weights $backendLabel...');

      // 3. Initialize Engine
      try {
        // If our JS check failed, we MUST use CPU
        final preferred = _useGpu ? PreferredBackend.gpu : PreferredBackend.cpu;
        
        await FlutterGemma.getActiveModel(
          maxTokens: 8192,
          preferredBackend: preferred,
          supportAudio: true,
        );
      } catch (e) {
        // Final ultimate fallback
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
