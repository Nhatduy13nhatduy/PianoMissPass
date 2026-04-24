import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';
import '../cubit/game_prototype_state.dart';
import '../notation/notation_metrics.dart';

class GameKeyboardPainter {
  static const int _startMidi = 36; // C2
  static const int _endMidi = 88; // E6
  static const int _middleCMidi = 60; // C4
  static const double _blackKeyStrokeWidth = 0.8;

  void paintKeyboard(
    Canvas canvas,
    Size size, {
    required ScoreData score,
    required int currentMs,
    required GameInputMode inputMode,
    required Set<int> activeInputMidis,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
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
    final passed = <int>{};
    final startTime = currentMs - _keyboardLookbackMs;
    final endTime = currentMs + _keyboardLookaheadMs;
    final startIndex = _lowerBoundHitTime(score.notes, startTime);
    final endIndex = _upperBoundHitTime(score.notes, endTime);
    for (var i = startIndex; i < endIndex; i++) {
      final note = score.notes[i];
      final adjustedHitMs = NoteTiming.adjustedHitTimeMs(note);
      final noteEndMs = adjustedHitMs + math.max(note.holdMs, _minimumHoldMs);
      if (adjustedHitMs <= currentMs && currentMs <= noteEndMs) {
        if (passedNoteIndexes.contains(i)) {
          passed.add(note.midi);
        } else {
          active.add(note.midi);
        }
      }
    }
    final userPressed = Set<int>.from(activeInputMidis);
    final userPassed = userPressed.intersection({...active, ...passed});
    final userMissed = inputMode == GameInputMode.microphone
        ? <int>{}
        : userPressed.difference({...active, ...passed});

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
      final keyState = _resolveKeyState(
        midi,
        active: active,
        passed: passed,
        userPassed: userPassed,
        userMissed: userMissed,
        userPressed: userPressed,
      );
      final isPressed = keyState.isPressed;
      final pressDepth = isPressed ? metrics.keyboardWhitePressDepth : 0.0;
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
      final baseColor = _whiteKeyBaseColor(keyState, score.colors);
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lighten(baseColor, isPressed ? 0.1 : 0.16),
            baseColor,
            _darken(baseColor, isPressed ? 0.1 : 0.06),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(keyRect);
      final shadow = Paint()
        ..color = score.colors.keyboard.whiteBorder.withAlpha(isPressed ? 8 : 14)
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
            baseColor,
            isPressed ? 0.06 : 0.14,
          ).withAlpha(isPressed ? 72 : 128),
      );
      if (midi == _middleCMidi) {
        _paintMiddleCLabel(
          canvas,
          keyRect: keyRect,
          color: isPressed
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
        final keyState = _resolveKeyState(
          midi,
          active: active,
          passed: passed,
          userPassed: userPassed,
          userMissed: userMissed,
          userPressed: userPressed,
        );
        final isPressed = keyState.isPressed;
        final pressDepth = isPressed ? metrics.keyboardBlackPressDepth : 0.0;
        final blackKeyBaseInset = _blackKeyStrokeWidth / 2;
        final blackKeyBaseRect = Rect.fromLTWH(
          x - blackKeyBaseInset,
          keyboardTop - 1.0 - blackKeyBaseInset,
          blackWidth + (_blackKeyStrokeWidth),
          blackHeight + (_blackKeyStrokeWidth),
        );
        final keyRect = Rect.fromLTWH(
          x,
          keyboardTop - 1.0 + pressDepth,
          blackWidth,
          blackHeight - pressDepth,
        );
        final blackRadius = _radiusFromRatio(keyRect.width, blackCornerRatio);
        final blackKeyBaseRRect = RRect.fromRectAndCorners(
          blackKeyBaseRect,
          bottomLeft: blackRadius,
          bottomRight: blackRadius,
        );
        final keyRRect = RRect.fromRectAndCorners(
          keyRect,
          bottomLeft: blackRadius,
          bottomRight: blackRadius,
        );
        final baseColor = _blackKeyBaseColor(keyState, score.colors);
        final fill = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(baseColor, isPressed ? 0.18 : 0.1),
              baseColor,
              _darken(baseColor, isPressed ? 0.24 : 0.18),
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
              isPressed ? 18 : 34,
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              metrics.keyboardBlackShadowBlur,
            ),
        );
        canvas.drawRRect(
          blackKeyBaseRRect,
          Paint()..color = score.colors.keyboard.black,
        );
        canvas.drawRRect(keyRRect, fill);
        canvas.drawRRect(
          highlight,
          Paint()
            ..color = _lighten(
              isPressed
                  ? baseColor
                  : score.colors.keyboard.white,
              isPressed ? 0.1 : 0.04,
            ).withAlpha(isPressed ? 52 : 32),
        );
        canvas.drawRRect(
          keyRRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _blackKeyStrokeWidth
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
      _radiusFromRatio(20, radiusRatio * 2.4),
    );

    canvas.drawRRect(markerRect, Paint()..color = markerColor);
  }

  _KeyboardKeyState _resolveKeyState(
    int midi, {
    required Set<int> active,
    required Set<int> passed,
    required Set<int> userPassed,
    required Set<int> userMissed,
    required Set<int> userPressed,
  }) {
    if (userPassed.contains(midi) || passed.contains(midi)) {
      return _KeyboardKeyState.pass;
    }
    if (userMissed.contains(midi)) {
      return _KeyboardKeyState.miss;
    }
    if (active.contains(midi) || userPressed.contains(midi)) {
      return _KeyboardKeyState.active;
    }
    return _KeyboardKeyState.idle;
  }

  Color _whiteKeyBaseColor(_KeyboardKeyState state, GameColorScheme colors) {
    return switch (state) {
      _KeyboardKeyState.pass => Color.lerp(
        colors.keyboard.white,
        colors.note.pass,
        0.78,
      )!,
      _KeyboardKeyState.miss => Color.lerp(
        colors.keyboard.white,
        colors.note.miss,
        0.78,
      )!,
      _KeyboardKeyState.active => Color.lerp(
        colors.keyboard.white,
        colors.keyboard.active,
        0.82,
      )!,
      _KeyboardKeyState.idle => colors.keyboard.white,
    };
  }

  Color _blackKeyBaseColor(_KeyboardKeyState state, GameColorScheme colors) {
    return switch (state) {
      _KeyboardKeyState.pass => colors.note.pass,
      _KeyboardKeyState.miss => colors.note.miss,
      _KeyboardKeyState.active => colors.keyboard.active,
      _KeyboardKeyState.idle => colors.keyboard.black,
    };
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

  static const int _keyboardLookbackMs = 1200;
  static const int _keyboardLookaheadMs = 100;
  static const int _minimumHoldMs = 90;
}

enum _KeyboardKeyState { idle, active, pass, miss }

extension on _KeyboardKeyState {
  bool get isPressed => this != _KeyboardKeyState.idle;
}
