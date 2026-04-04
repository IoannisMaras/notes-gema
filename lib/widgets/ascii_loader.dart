import 'dart:async';
import 'package:flutter/material.dart';

class AsciiLoader extends StatefulWidget {
  final String message;
  const AsciiLoader({super.key, required this.message});

  @override
  State<AsciiLoader> createState() => _AsciiLoaderState();
}

class _AsciiLoaderState extends State<AsciiLoader> {
  late Timer _timer;
  int _ticks = 0;
  static const _frames = [
    '[=   ]',
    '[==  ]',
    '[=== ]',
    '[ ===]',
    '[  ==]',
    '[   =]',
    '[  ==]',
    '[ ===]',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted) setState(() => _ticks++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '> ${widget.message} ${_frames[_ticks % _frames.length]}',
      style: const TextStyle(
        color: Colors.greenAccent,
        fontFamily: 'Courier',
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
