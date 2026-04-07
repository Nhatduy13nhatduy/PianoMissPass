import 'package:flutter/material.dart';

class GameTextPainter {
  void paintText(
    Canvas canvas,
    Offset offset,
    String text, {
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double maxWidth = 140,
    String? fontFamily,
    double height = 1.0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          height: height,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  void paintClef(Canvas canvas, Offset offset, String text, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF111111),
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }
}
