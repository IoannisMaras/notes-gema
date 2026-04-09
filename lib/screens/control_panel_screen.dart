import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/model_status_service.dart';
import '../services/gpu_helper.dart';

class ControlPanelScreen extends StatefulWidget {
  const ControlPanelScreen({super.key});

  @override
  State<ControlPanelScreen> createState() => _ControlPanelScreenState();
}

class _ControlPanelScreenState extends State<ControlPanelScreen>
    with TickerProviderStateMixin {
  bool? _isWebGpuSupported;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    ModelStatusService.instance.addListener(_onUpdate);
    _checkStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ModelStatusService.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Widget _buildNeuralInterface(ModelStatusService svc) {
    final color = svc.useGpu ? Colors.cyanAccent : Colors.orangeAccent;
    final statusTitle = svc.useGpu
        ? 'NEURAL_LINK: OPTIMIZED'
        : 'NEURAL_LINK: CONSTRAINED';
    final statusDesc = svc.useGpu
        ? 'High-speed WebGPU acceleration is active. The engine is utilizing your hardware shaders for real-time neural processing.'
        : 'Running on CPU fallback. Neural processing is stable but performance is limited due to hardware constraints.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 400;
          return Flex(
            direction: isSmall ? Axis.vertical : Axis.horizontal,
            children: [
              SizedBox(
                width: isSmall ? double.infinity : 100,
                height: 100,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 0.8 + (_pulseController.value * 0.3);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(
                                  alpha: 0.4 * _pulseController.value,
                                ),
                                blurRadius: 25 * scale,
                                spreadRadius: 5,
                              ),
                            ],
                            gradient: RadialGradient(
                              colors: [
                                color.withValues(alpha: 0.9),
                                color.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                          child: Icon(
                            svc.useGpu ? Icons.bolt : Icons.memory,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (!isSmall) const SizedBox(width: 24),
              Expanded(
                flex: isSmall ? 0 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusDesc,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkStatus() async {
    if (kIsWeb) {
      final info = await checkWebGPUSupport();
      setState(() {
        _isWebGpuSupported = info.supported;
      });
    }
  }

  Widget _buildGpuToggle(ModelStatusService svc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enable WebGPU acceleration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Uses your GPU for faster AI responses.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          Switch(
            value: svc.isGpuEnabledByUser,
            onChanged: (val) async {
              svc.toggleGpu(val);
              if (val) {
                // If turning ON, check if it's actually supported
                final info = await checkWebGPUSupport();
                if (!info.supported && mounted) {
                  // Revert the toggle
                  svc.toggleGpu(false);

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E22),
                      title: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'HARDWARE_LIMIT',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      content: Text(
                        'WebGPU is detected but restricted or unsupported on your hardware (${info.reason}). '
                        'The system will remain on CPU fallback for stability.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'UNDERSTOOD',
                            style: TextStyle(color: Colors.cyanAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            activeThumbColor: Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusSvc = ModelStatusService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('SYS_CONFIG / CONTROL_PANEL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('NEURO_ENGINE STATUS'),
            const SizedBox(height: 16),
            _buildNeuralInterface(statusSvc),
            const SizedBox(height: 24),
            _buildGpuToggle(statusSvc),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Active Backend',
              value: statusSvc.activeBackend,
              icon: Icons.bolt,
              isAlert: !statusSvc.useGpu,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: 'Memory Usage / Limit',
              value: statusSvc.memoryUsage,
              icon: Icons.memory,
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('HARDWARE DIAGNOSTICS'),
            const SizedBox(height: 16),
            if (kIsWeb) ...[
              _buildDiagnosticItem(
                label: 'WebGPU API Support',
                value: _isWebGpuSupported == null
                    ? 'CHECKING...'
                    : (_isWebGpuSupported! ? 'PASSED' : 'FAILED / LIMITED'),
                isOk: _isWebGpuSupported ?? false,
              ),
              if (statusSvc.gpuInfo?.description != null) ...[
                const SizedBox(height: 12),
                _buildDiagnosticItem(
                  label: 'Hardware ID',
                  value: statusSvc.gpuInfo!.description!,
                  isOk: true,
                ),
              ],
              if (statusSvc.gpuInfo?.vendor != null) ...[
                const SizedBox(height: 8),
                _buildDiagnosticItem(
                  label: 'Vendor',
                  value: statusSvc.gpuInfo!.vendor!,
                  isOk: true,
                ),
              ],
              const SizedBox(height: 24),
              if (_isWebGpuSupported == false) _buildWebGpuAdvice(),
            ] else
              const Text(
                'Hardware diagnostics available on Web platform only.',
              ),
            const SizedBox(height: 48),
            _buildSectionHeader('SYSTEM ACTIONS'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Logic to toggle or retry initialization can go here
                  statusSvc.prepareModel();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Re-initializing neural engine...'),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('RE-PROBE HARDWARE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
        const Divider(color: Colors.white10, thickness: 1),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert
              ? Colors.orangeAccent.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isAlert ? Colors.orangeAccent : Colors.white54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isAlert ? Colors.orangeAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem({
    required String label,
    required String value,
    required bool isOk,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isOk
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isOk
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.red.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebGpuAdvice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ACTION REQUIRED',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'High-speed WebGPU is disabled or not available on this device. For better AI performance, please try:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          SizedBox(height: 12),
          Text(
            '1. Go to: chrome://flags',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            '2. Search & Enable: "Override software rendering list"',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            '3. Search & Enable: "Unsafe WebGPU Support"',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            '4. Relaunch Browser / Refresh Page',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          SizedBox(height: 8),
          Text(
            'Note: After changing flags, you MUST refresh the browser window.',
            style: TextStyle(
              color: Colors.orangeAccent,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
