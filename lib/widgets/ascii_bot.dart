import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BotState { exhausted, awake, thinking }

class AsciiBot extends StatefulWidget {
  final BotState state;
  final double targetX;
  final double targetY;
  final double botX;
  final double botY;

  const AsciiBot({
    super.key,
    required this.state,
    this.targetX = 0,
    this.targetY = 0,
    this.botX = 0,
    this.botY = 0,
  });

  @override
  State<AsciiBot> createState() => _AsciiBotState();
}

class _AsciiBotState extends State<AsciiBot> {
  late Timer _timer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted) {
        setState(() {
          _frameIndex++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double botCenterX = widget.botX + 30; // approx center
    double botCenterY = widget.botY + 30;

    double dx = widget.targetX - botCenterX;
    double dy = widget.targetY - botCenterY;

    if (widget.targetX == 0 && widget.targetY == 0) {
      dx = 0;
      dy = 0;
    }

    double distance = math.sqrt(dx * dx + dy * dy);
    double angle = math.atan2(dy, dx);
    double intensity = (distance / 400.0).clamp(0.0, 1.0);

    double maxEyeShift = 10.0;
    double maxMouthShift = 4.0;

    double eyeOffsetX = math.cos(angle) * maxEyeShift * intensity;
    double eyeOffsetY = math.sin(angle) * maxEyeShift * intensity;

    // Parallax sub-pixel shifting for the mouth
    double mouthOffsetX = math.cos(angle) * maxMouthShift * intensity;
    double mouthOffsetY = math.sin(angle) * maxMouthShift * intensity;

    String eyeL = "o";
    String eyeR = "o";
    String mouth = "-";

    switch (widget.state) {
      case BotState.exhausted:
        eyeL = "-";
        eyeR = "-";
        final zCycle = (_frameIndex ~/ 3) % 4;
        mouth = zCycle == 0 ? "z" : (zCycle == 1 ? "Z" : "z");
        eyeOffsetX += math.cos(_frameIndex.toDouble() * 0.5) * 2;
        eyeOffsetY += math.sin(_frameIndex.toDouble() * 0.25) * 2;
        break;
      case BotState.awake:
        if ((_frameIndex ~/ 10) % 2 == 0 && _frameIndex % 10 < 2) {
          eyeL = ">";
          eyeR = "<";
        } else if (_frameIndex % 30 == 0) {
          eyeL = "u";
          eyeR = "u";
        }
        break;
      case BotState.thinking:
        int glitch = _frameIndex % 4;
        if (glitch == 0) {
          eyeL = "O";
          eyeR = "o";
        } else if (glitch == 1) {
          eyeL = "o";
          eyeR = "O";
        } else if (glitch == 2) {
          eyeL = "-";
          eyeR = "-";
        }
        mouth = (glitch % 2 == 0) ? "o" : "-";
        eyeOffsetX += (glitch % 2 == 0 ? 3 : -3);
        eyeOffsetY += (glitch % 3 == 0 ? 2 : -2);
        break;
    }

    return SizedBox(
      width: 50,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            left: 6 + eyeOffsetX,
            top: 2 + eyeOffsetY,
            child: Text(
              eyeL,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            right: 6 - eyeOffsetX,
            top: 2 + eyeOffsetY,
            child: Text(
              eyeR,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: 19 + mouthOffsetX,
            top: 22 + mouthOffsetY,
            child: Text(
              mouth,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
