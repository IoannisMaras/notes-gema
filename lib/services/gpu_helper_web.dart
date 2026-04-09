// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js_util' as js_util;

class GpuSupportInfo {
  final bool supported;
  final String? reason;
  final String? description;
  final String? vendor;
  final bool isStub;

  GpuSupportInfo({
    required this.supported,
    this.reason,
    this.description,
    this.vendor,
    this.isStub = false,
  });
}

Future<GpuSupportInfo> checkWebGPUSupport() async {
  try {
    final result = await js_util.promiseToFuture(
      js_util.callMethod(js_util.globalThis, 'isWebGPUSupported', []),
    );
    
    final supported = js_util.getProperty(result, 'supported') == true;
    final reason = js_util.getProperty(result, 'reason') as String?;
    final info = js_util.getProperty(result, 'info');
    
    String? description;
    String? vendor;
    bool isStub = false;

    if (info != null) {
      description = js_util.getProperty(info, 'description') as String?;
      vendor = js_util.getProperty(info, 'vendor') as String?;
      
      // If info itself has isStub, or if the parent result has it via info
      final sj = js_util.getProperty(info, 'isStub');
      if (sj != null) isStub = sj == true;
    }

    return GpuSupportInfo(
      supported: supported,
      reason: reason,
      description: description,
      vendor: vendor,
      isStub: isStub,
    );
  } catch (e) {
    return GpuSupportInfo(supported: false, reason: e.toString(), isStub: true);
  }
}
Future<bool> checkFileExists(String url) async {
  try {
    final exists = await js_util.promiseToFuture(
      js_util.callMethod(js_util.globalThis, 'checkFileExists', [url]),
    );
    return exists == true;
  } catch (e) {
    return false;
  }
}

void saveGpuPreference(bool enabled) {
  final storage = js_util.getProperty(js_util.globalThis, 'localStorage');
  js_util.callMethod(storage, 'setItem', ['NOTES_GEMA_GPU_ENABLED', enabled.toString()]);
}

bool getGpuPreference() {
  final storage = js_util.getProperty(js_util.globalThis, 'localStorage');
  final val = js_util.callMethod(storage, 'getItem', ['NOTES_GEMA_GPU_ENABLED']);
  if (val == null) return true; // Default to true
  return val == 'true';
}
void setForceCpu(bool force) {
  js_util.setProperty(js_util.globalThis, '_FORCE_CPU', force);
}
