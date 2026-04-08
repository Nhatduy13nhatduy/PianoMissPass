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

Path _notePainterHalfHeadTemplate() {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(27.32, 97.39)
    ..cubicTo(23.8, 92.15, 27.58, 84.61, 35.64, 80.57)
    ..cubicTo(43.7, 76.53, 53.15, 77.3, 56.68, 82.54)
    ..cubicTo(60.2, 87.78, 56.42, 95.32, 48.36, 99.47)
    ..cubicTo(40.3, 103.51, 30.85, 102.64, 27.32, 97.39)
    ..close()
    ..moveTo(55.42, 83.19)
    ..cubicTo(54.03, 81.01, 46.98, 82.21, 39.67, 85.93)
    ..cubicTo(39.54, 85.93, 39.54, 86.03, 39.42, 86.03)
    ..cubicTo(39.29, 86.03, 39.17, 86.14, 39.17, 86.14)
    ..cubicTo(31.98, 89.86, 27.32, 94.55, 28.83, 96.63)
    ..cubicTo(30.22, 98.81, 37.28, 97.61, 44.58, 93.9)
    ..cubicTo(44.71, 93.9, 44.71, 93.79, 44.83, 93.79)
    ..lineTo(44.96, 93.68)
    ..cubicTo(52.14, 90.08, 56.8, 85.38, 55.42, 83.19)
    ..close();
}

Path _notePainterWholeHeadTemplate() {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(32.1, 100.51)
    ..cubicTo(26.45, 98.81, 22, 94.16, 22, 89.98)
    ..cubicTo(22, 78.16, 47.81, 73.48, 58.47, 83.37)
    ..cubicTo(70, 94.07, 51.19, 106.29, 32.1, 100.51)
    ..lineTo(32.1, 100.51)
    ..close()
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
