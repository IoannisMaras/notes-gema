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
    this.isStub = true,
  });
}

Future<GpuSupportInfo> checkWebGPUSupport() async =>
    GpuSupportInfo(supported: false, reason: 'Not supported on this platform');
Future<bool> checkFileExists(String url) async => false;
void saveGpuPreference(bool enabled) {}
bool getGpuPreference() => false;
void setForceCpu(bool force) {}
