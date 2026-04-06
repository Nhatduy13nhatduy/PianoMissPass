part of 'game_note_painter.dart';

Path _notePainterQuarterHeadTemplate() {
  return Path()
    ..moveTo(27.32, 97.39)
    ..cubicTo(23.8, 92.15, 27.58, 84.61, 35.64, 80.57)
    ..cubicTo(43.7, 76.53, 53.15, 77.3, 56.68, 82.54)
    ..cubicTo(60.2, 87.78, 56.42, 95.32, 48.36, 99.47)
    ..cubicTo(40.3, 103.51, 30.85, 102.64, 27.32, 97.39)
    ..close();
}

Path _notePainterHalfInnerTemplate() {
  return Path()
    ..moveTo(55.42, 83.19)
    ..cubicTo(54.03, 81.01, 46.98, 82.21, 39.67, 85.93)
    ..lineTo(39.42, 86.03)
    ..lineTo(39.17, 86.14)
    ..cubicTo(31.98, 89.86, 27.32, 94.55, 28.83, 96.63)
    ..cubicTo(30.22, 98.81, 37.28, 97.61, 44.58, 93.9)
    ..lineTo(44.83, 93.79)
    ..lineTo(44.96, 93.68)
    ..cubicTo(52.14, 90.08, 56.8, 85.38, 55.42, 83.19)
    ..close();
}

Path _notePainterWholeOuterTemplate() {
  return Path()
    ..moveTo(32.1, 100.51)
    ..cubicTo(26.45, 98.81, 22, 94.16, 22, 89.98)
    ..cubicTo(22, 78.16, 47.81, 73.48, 58.47, 83.37)
    ..cubicTo(70, 94.07, 51.19, 106.29, 32.1, 100.51)
    ..close();
}

Path _notePainterWholeInnerTemplate() {
  return Path()
    ..moveTo(49.31, 97.54)
    ..cubicTo(52.46, 92.83, 49.45, 83.49, 44.01, 81.05)
    ..cubicTo(36.03, 77.47, 31.13, 83.57, 34.46, 92.96)
    ..cubicTo(36.76, 99.45, 46.12, 102.34, 49.31, 97.54)
    ..close();
}

Path _notePainterBuildLegacyFlagTemplate({required _StemDirection direction}) {
  if (direction == _StemDirection.up) {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(1.64, 0.96, 3.22, 1.87, 4.73, 2.74)
      ..cubicTo(21.7, 12.5, 30.12, 17.34, 20.83, 36.79)
      ..cubicTo(34.09, 17.29, 26.89, 9.42, 15.88, -2.62)
      ..cubicTo(10.85, 8.12, 5.03, 14.48, 0, -23.21)
      ..close();
  }

  return Path()
    ..moveTo(0, 0)
    ..cubicTo(-1.64, -0.96, -3.22, -1.87, -4.73, -2.74)
    ..cubicTo(-21.7, -12.5, -30.12, -17.34, -20.83, -36.79)
    ..cubicTo(-34.09, -17.29, -26.89, -9.42, -15.88, 2.62)
    ..cubicTo(-10.85, 8.12, -5.03, 14.48, 0, 23.21)
    ..close();
}

Path _notePainterBuildPathFromTemplate(
  Path template, {
  required Offset center,
  required double targetHeight,
}) {
  final bounds = template.getBounds();
  if (bounds.height == 0) {
    return template;
  }

  final scale = targetHeight / bounds.height;
  final centerTemplate = bounds.center;
  final matrix = Matrix4.identity()
    ..translate(center.dx, center.dy)
    ..scale(scale, scale)
    ..translate(-centerTemplate.dx, -centerTemplate.dy);
  return template.transform(matrix.storage);
}

Path _notePainterBuildSharpPath(Offset c, double s) {
  final x = c.dx - 10 * s;
  final y = c.dy - 34 * s;
  return Path()
    ..moveTo(x + 6.523 * s, y + 43.5 * s)
    ..lineTo(x + 6.523 * s, y + 26.659 * s)
    ..lineTo(x + 13.368 * s, y + 24.682 * s)
    ..lineTo(x + 13.368 * s, y + 41.438 * s)
    ..lineTo(x + 6.523 * s, y + 43.5 * s)
    ..moveTo(x + 20 * s, y + 39.426 * s)
    ..lineTo(x + 15.294 * s, y + 40.837 * s)
    ..lineTo(x + 15.294 * s, y + 24.081 * s)
    ..lineTo(x + 20 * s, y + 22.706 * s)
    ..lineTo(x + 20 * s, y + 15.746 * s)
    ..lineTo(x + 15.294 * s, y + 17.12 * s)
    ..lineTo(x + 15.294 * s, y)
    ..lineTo(x + 13.368 * s, y)
    ..lineTo(x + 13.368 * s, y + 17.64 * s)
    ..lineTo(x + 6.523 * s, y + 19.698 * s)
    ..lineTo(x + 6.523 * s, y + 3.05 * s)
    ..lineTo(x + 4.706 * s, y + 3.05 * s)
    ..lineTo(x + 4.706 * s, y + 20.332 * s)
    ..lineTo(x, y + 21.71 * s)
    ..lineTo(x, y + 28.685 * s)
    ..lineTo(x + 4.706 * s, y + 27.31 * s)
    ..lineTo(x + 4.706 * s, y + 44.034 * s)
    ..lineTo(x, y + 45.405 * s)
    ..lineTo(x, y + 52.351 * s)
    ..lineTo(x + 4.706 * s, y + 50.976 * s)
    ..lineTo(x + 4.706 * s, y + 68 * s)
    ..lineTo(x + 6.523 * s, y + 68 * s)
    ..lineTo(x + 6.523 * s, y + 50.368 * s)
    ..lineTo(x + 13.368 * s, y + 48.398 * s)
    ..lineTo(x + 13.368 * s, y + 64.96 * s)
    ..lineTo(x + 15.294 * s, y + 64.96 * s)
    ..lineTo(x + 15.294 * s, y + 47.775 * s)
    ..lineTo(x + 20 * s, y + 46.397 * s)
    ..lineTo(x + 20 * s, y + 39.426 * s)
    ..close();
}

Path _notePainterBuildFlatPath(Offset c, double s) {
  final x = c.dx - 10 * s;
  final y = c.dy - 26 * s;
  return Path()
    ..moveTo(x + 2.475 * s, y)
    ..lineTo(x + 2.475 * s, y + 31.091 * s)
    ..lineTo(x + 2.475 * s, y + 33.186 * s)
    ..lineTo(x + 2.475 * s, y + 37.378 * s)
    ..cubicTo(
      x + 5.332 * s,
      y + 34.693 * s,
      x + 8.537 * s,
      y + 33.317 * s,
      x + 12.091 * s,
      y + 33.252 * s,
    )
    ..cubicTo(
      x + 14.313 * s,
      y + 33.252 * s,
      x + 16.217 * s,
      y + 34.201 * s,
      x + 17.804 * s,
      y + 36.101 * s,
    )
    ..cubicTo(
      x + 19.2 * s,
      y + 37.869 * s,
      x + 19.93 * s,
      y + 39.834 * s,
      x + 19.994 * s,
      y + 41.995 * s,
    )
    ..cubicTo(
      x + 20.057 * s,
      y + 43.698 * s,
      x + 19.645 * s,
      y + 45.662 * s,
      x + 18.756 * s,
      y + 47.889 * s,
    )
    ..cubicTo(
      x + 18.439 * s,
      y + 48.806 * s,
      x + 17.74 * s,
      y + 49.788 * s,
      x + 16.661 * s,
      y + 50.836 * s,
    )
    ..cubicTo(
      x + 15.836 * s,
      y + 51.622 * s,
      x + 14.979 * s,
      y + 52.441 * s,
      x + 14.091 * s,
      y + 53.292 * s,
    )
    ..cubicTo(
      x + 9.394 * s,
      y + 56.829 * s,
      x + 4.697 * s,
      y + 60.398 * s,
      x,
      y + 64 * s,
    )
    ..lineTo(x, y)
    ..lineTo(x + 2.475 * s, y)
    ..close();
}

Path _notePainterBuildNaturalPath(Offset c, double s) {
  final x = c.dx - 8.5 * s;
  final y = c.dy - 34 * s;
  return Path()
    ..moveTo(x + 17.0 * s, y + 16.64 * s)
    ..lineTo(x + 17.0 * s, y + 68.0 * s)
    ..lineTo(x + 14.794 * s, y + 68.0 * s)
    ..lineTo(x + 14.794 * s, y + 48.751 * s)
    ..lineTo(x + 3.0 * s, y + 51.989 * s)
    ..lineTo(x + 3.0 * s, y + 0.0 * s)
    ..lineTo(x + 5.121 * s, y + 0.0 * s)
    ..lineTo(x + 5.121 * s, y + 20.058 * s)
    ..lineTo(x + 17.0 * s, y + 16.64 * s)
    ..moveTo(x + 5.121 * s, y + 28.693 * s)
    ..lineTo(x + 5.121 * s, y + 42.815 * s)
    ..lineTo(x + 14.794 * s, y + 40.116 * s)
    ..lineTo(x + 14.794 * s, y + 25.995 * s)
    ..lineTo(x + 5.121 * s, y + 28.693 * s)
    ..close();
}
