import 'package:flutter/material.dart';

import '../../domain/game_score.dart';

class GameStaffPainter {
  void paint(
    Canvas canvas,
    Rect rect,
    double spacing, {
    required GameColorScheme colors,
  }) {
    final boxPaint = Paint()..color = colors.staff.background;
    final border = Paint()
      ..color = colors.staff.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final linePaint = Paint()
      ..color = colors.staff.line
      ..strokeWidth = 1.1;

    canvas.drawRect(rect, boxPaint);
    canvas.drawRect(rect, border);

    for (var i = 0; i < 5; i++) {
      final y = rect.top + i * spacing;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);
    }
  }
}
