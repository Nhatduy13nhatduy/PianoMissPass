import 'package:flutter/material.dart';

class GameStaffPainter {
  void paint(Canvas canvas, Rect rect, double spacing) {
    final boxPaint = Paint()..color = const Color(0xE6F4F4F4);
    final border = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final linePaint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 1.1;

    canvas.drawRect(rect, boxPaint);
    canvas.drawRect(rect, border);

    for (var i = 0; i < 5; i++) {
      final y = rect.top + i * spacing;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);
    }
  }
}
