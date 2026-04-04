import 'package:flutter/material.dart';

class AudioMessengerWaveform extends StatelessWidget {
  final List<double> amplitudes;

  /// When [isStatic] is true the widget renders a normalized snapshot of the
  /// entire recording using peak-preserving bucket aggregation.
  /// When false it renders a live trailing waveform.
  final bool isStatic;

  const AudioMessengerWaveform({
    super.key,
    required this.amplitudes,
    this.isStatic = false,
  });

  @override
  Widget build(BuildContext context) {
    const int targetBars = 30;
    const int liveBars = 40;
    final int barCount = isStatic ? targetBars : liveBars;

    return Row(
      mainAxisAlignment:
          isStatic ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: List.generate(barCount, (index) {
        double amp = 0.0;

        if (isStatic) {
          if (amplitudes.isNotEmpty) {
            // Peak-preserving normalization: find the max in each time bucket
            final double samplesPerBar = amplitudes.length / targetBars;
            final int start = (index * samplesPerBar).floor();
            int end = ((index + 1) * samplesPerBar).floor();
            if (end <= start) end = start + 1;
            double maxInBucket = 0.0;
            for (int i = start; i < end && i < amplitudes.length; i++) {
              if (amplitudes[i] > maxInBucket) maxInBucket = amplitudes[i];
            }
            amp = maxInBucket;
          }
        } else {
          // Live recording: show the trailing history reversed
          if (index < amplitudes.length) {
            amp = amplitudes[amplitudes.length - 1 - index];
          }
        }

        final int blocks = (amp * 12).round().clamp(1, 15);
        final double height = blocks * 3.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Container(
            width: 4,
            height: height,
            color: Colors.greenAccent,
          ),
        );
      }).reversed.toList(),
    );
  }
}
