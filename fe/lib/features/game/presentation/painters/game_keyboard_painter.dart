import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';
import '../notation/notation_metrics.dart';

class GameKeyboardPainter {
  static const int _activeWindowMs = 100;
  static const int _startMidi = 36; // C2
  static const int _endMidi = 88; // E6
  static const int _middleCMidi = 60; // C4

  void paintKeyboard(
    Canvas canvas,
    Size size, {
    required ScoreData score,
    required int currentMs,
    required double keyboardTop,
    required NotationMetrics metrics,
  }) {
    final midiRange = <int>[
      for (var midi = _startMidi; midi <= _endMidi; midi++) midi,
    ];
    final whiteMidis = midiRange.where((m) => !_isBlack(m)).toList();

    final whiteWidth = size.width / math.max(whiteMidis.length, 1);
    final whiteHeight = metrics.keyboardWhiteHeight;
    final whiteVisualHeight = whiteHeight + metrics.keyboardBedBottomInset;
    final blackHeight = whiteHeight * metrics.keyboardBlackHeightRatio;
    final blackWidth = whiteWidth * metrics.keyboardBlackWidthRatio;
    final whiteGap = metrics.keyboardWhiteGap;
    final whiteCornerRatio = whiteWidth <= 0
        ? 0.0
        : metrics.keyboardWhiteCornerRadius / whiteWidth;
    final blackCornerRatio = blackWidth <= 0
        ? 0.0
        : metrics.keyboardBlackCornerRadius / blackWidth;

    final active = <int>{};
    final startTime = currentMs - _activeWindowMs;
    final endTime = currentMs + _activeWindowMs;
    final startIndex = _lowerBoundHitTime(score.notes, startTime);
    final endIndex = _upperBoundHitTime(score.notes, endTime);
    for (var i = startIndex; i < endIndex; i++) {
      final note = score.notes[i];
      if ((NoteTiming.adjustedHitTimeMs(note) - currentMs).abs() <=
          _activeWindowMs) {
        active.add(note.midi);
      }
    }

    final bedRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        keyboardTop - metrics.keyboardBedTopInset,
        size.width,
        whiteHeight * 1.5 + metrics.keyboardBedBottomInset,
      ),
      const Radius.circular(0),
    );
    canvas.drawRRect(bedRect, Paint()..color = score.colors.keyboard.black);

    var whiteIndex = 0;
    for (final midi in midiRange) {
      if (_isBlack(midi)) {
        continue;
      }

      final x = whiteIndex * whiteWidth;
      final isActive = active.contains(midi);
      final pressDepth = isActive ? metrics.keyboardWhitePressDepth : 0.0;
      final keyRect = Rect.fromLTWH(
        x + whiteGap,
        keyboardTop + pressDepth,
        whiteWidth - (whiteGap * 2),
        whiteVisualHeight - pressDepth,
      );
      final whiteRadius = _radiusFromRatio(keyRect.width, whiteCornerRatio);
      final keyRRect = RRect.fromRectAndCorners(
        keyRect,
        bottomLeft: whiteRadius,
        bottomRight: whiteRadius,
      );
      final baseColor = isActive
          ? Color.lerp(
              score.colors.keyboard.white,
              score.colors.keyboard.active,
              0.82,
            )!
          : score.colors.keyboard.white;
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lighten(baseColor, isActive ? 0.1 : 0.16),
            baseColor,
            _darken(baseColor, isActive ? 0.1 : 0.06),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(keyRect);
      final shadow = Paint()
        ..color = score.colors.keyboard.whiteBorder.withAlpha(isActive ? 8 : 14)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          metrics.keyboardWhiteShadowBlur,
        );

      canvas.drawRRect(
        keyRRect.shift(Offset(0, metrics.keyboardWhiteShadowOffsetY)),
        shadow,
      );
      canvas.drawRRect(keyRRect, fill);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            keyRect.left + keyRect.width * 0.055,
            keyRect.top + keyRect.height * 0.024,
            keyRect.width * 0.89,
            keyRect.height * metrics.keyboardWhiteHighlightHeightRatio,
          ),
          bottomLeft: whiteRadius,
          bottomRight: whiteRadius,
        ),
        Paint()
          ..color = _lighten(
            score.colors.keyboard.white,
            isActive ? 0.06 : 0.14,
          ).withAlpha(isActive ? 72 : 128),
      );
      if (midi == _middleCMidi) {
        _paintMiddleCLabel(
          canvas,
          keyRect: keyRect,
          color: isActive
              ? score.colors.keyboard.white
              : score.colors.keyboard.active,
          radiusRatio: whiteCornerRatio,
        );
      }
      whiteIndex++;
    }

    whiteIndex = 0;
    for (final midi in midiRange) {
      if (_isBlack(midi)) {
        final x = whiteIndex * whiteWidth - blackWidth / 2;
        final isActive = active.contains(midi);
        final pressDepth = isActive ? metrics.keyboardBlackPressDepth : 0.0;
        final keyRect = Rect.fromLTWH(
          x,
          keyboardTop - 1.0 + pressDepth,
          blackWidth,
          blackHeight - pressDepth,
        );
        final blackRadius = _radiusFromRatio(keyRect.width, blackCornerRatio);
        final keyRRect = RRect.fromRectAndCorners(
          keyRect,
          bottomLeft: blackRadius,
          bottomRight: blackRadius,
        );
        final baseColor = isActive
            ? score.colors.keyboard.active
            : score.colors.keyboard.black;
        final fill = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(baseColor, isActive ? 0.18 : 0.1),
              baseColor,
              _darken(baseColor, isActive ? 0.24 : 0.18),
            ],
            stops: const [0.0, 0.3, 1.0],
          ).createShader(keyRect);
        final highlight = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            keyRect.left + blackWidth * 0.12,
            keyRect.top + 1.4,
            blackWidth * 0.76,
            keyRect.height * metrics.keyboardBlackHighlightHeightRatio,
          ),
          bottomLeft: blackRadius,
          bottomRight: blackRadius,
        );
        canvas.drawRRect(
          keyRRect.shift(Offset(0, metrics.keyboardBlackShadowOffsetY)),
          Paint()
            ..color = score.colors.keyboard.whiteBorder.withAlpha(
              isActive ? 18 : 34,
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              metrics.keyboardBlackShadowBlur,
            ),
        );
        canvas.drawRRect(keyRRect, fill);
        canvas.drawRRect(
          highlight,
          Paint()
            ..color = _lighten(
              isActive
                  ? score.colors.keyboard.active
                  : score.colors.keyboard.white,
              isActive ? 0.1 : 0.04,
            ).withAlpha(isActive ? 52 : 32),
        );
        canvas.drawRRect(
          keyRRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = score.colors.keyboard.whiteBorder.withAlpha(78),
        );
      } else {
        whiteIndex++;
      }
    }
  }

  bool _isBlack(int midi) {
    final pc = midi % 12;
    return pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10;
  }

  void _paintMiddleCLabel(
    Canvas canvas, {
    required Rect keyRect,
    required Color color,
    required double radiusRatio,
  }) {
    final markerColor = color;
    final markerWidth = (keyRect.width * 0.12).clamp(4.0, 6.0);
    final markerHeight = (keyRect.height * 0.16).clamp(8.0, 11.0);
    final markerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(keyRect.center.dx, keyRect.bottom - 12),
        width: markerWidth,
        height: markerHeight,
      ),
      _radiusFromRatio(markerWidth, radiusRatio * 2.4),
    );

    canvas.drawRRect(markerRect, Paint()..color = markerColor);
  }

  Radius _radiusFromRatio(double base, double ratio) {
    return Radius.circular((base * ratio).clamp(0.0, base / 2));
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  int _lowerBoundHitTime(List<MusicNote> notes, int targetMs) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].hitTimeMs < targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBoundHitTime(List<MusicNote> notes, int targetMs) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].hitTimeMs <= targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
