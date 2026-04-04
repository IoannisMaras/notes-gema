import 'package:flutter/material.dart';

class TerminalNotesController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    List<TextSpan> children = [];
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      TextStyle lineStyle = style ?? const TextStyle();
      if (line.startsWith('- ')) {
        lineStyle = lineStyle.copyWith(
          color: Colors.redAccent,
          decoration: TextDecoration.lineThrough,
          backgroundColor: Colors.redAccent.withOpacity(0.1),
        );
      } else if (line.startsWith('+ ')) {
        lineStyle = lineStyle.copyWith(
          color: Colors.greenAccent,
          backgroundColor: Colors.greenAccent.withOpacity(0.1),
        );
      } else if (line.startsWith('@@')) {
        lineStyle = lineStyle.copyWith(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        );
      } else if (line.startsWith('//')) {
        lineStyle = lineStyle.copyWith(color: Colors.white38);
      }
      children.add(
        TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
          style: lineStyle,
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}
