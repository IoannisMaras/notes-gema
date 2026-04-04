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
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted) setState(() => _frameIndex++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double botCenterX = widget.botX + 30;
    final double botCenterY = widget.botY + 30;

    double dx = widget.targetX - botCenterX;
    double dy = widget.targetY - botCenterY;

    if (widget.targetX == 0 && widget.targetY == 0) {
      dx = 0;
      dy = 0;
    }

    final double distance = math.sqrt(dx * dx + dy * dy);
    final double angle = math.atan2(dy, dx);
    final double intensity = (distance / 400.0).clamp(0.0, 1.0);

    double eyeOffsetX = math.cos(angle) * 10.0 * intensity;
    double eyeOffsetY = math.sin(angle) * 10.0 * intensity;
    final double mouthOffsetX = math.cos(angle) * 4.0 * intensity;
    final double mouthOffsetY = math.sin(angle) * 4.0 * intensity;

    String eyeL = 'o';
    String eyeR = 'o';
    String mouth = '-';

    switch (widget.state) {
      case BotState.exhausted:
        eyeL = '-';
        eyeR = '-';
        final zCycle = (_frameIndex ~/ 3) % 4;
        mouth = zCycle == 0 ? 'z' : (zCycle == 1 ? 'Z' : 'z');
        eyeOffsetX += math.cos(_frameIndex.toDouble() * 0.5) * 2;
        eyeOffsetY += math.sin(_frameIndex.toDouble() * 0.25) * 2;
        break;
      case BotState.awake:
        if ((_frameIndex ~/ 10) % 2 == 0 && _frameIndex % 10 < 2) {
          eyeL = '>';
          eyeR = '<';
        } else if (_frameIndex % 30 == 0) {
          eyeL = 'u';
          eyeR = 'u';
        }
        break;
      case BotState.thinking:
        final int glitch = _frameIndex % 4;
        if (glitch == 0) {
          eyeL = 'O';
          eyeR = 'o';
        } else if (glitch == 1) {
          eyeL = 'o';
          eyeR = 'O';
        } else if (glitch == 2) {
          eyeL = '-';
          eyeR = '-';
        }
        mouth = (glitch % 2 == 0) ? 'o' : '-';
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
            child: _char(eyeL),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            right: 6 - eyeOffsetX,
            top: 2 + eyeOffsetY,
            child: _char(eyeR),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: 19 + mouthOffsetX,
            top: 22 + mouthOffsetY,
            child: _char(mouth, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _char(String c, {double size = 24}) => Text(
        c,
        style: TextStyle(
          color: Colors.greenAccent,
          fontFamily: 'Courier',
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      );
}
